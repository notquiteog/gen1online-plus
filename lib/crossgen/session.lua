-- Persistent world connection. Native battle/trade transports can be carried
-- on separate channels without closing presence or chat when a match ends.
return function(mod, loadLocal, adapter)
  local Native = require('src.link.Net')
  local Net = loadLocal('lib/crossgen/room_transport.lua')
  local SharedWorld = loadLocal('lib/crossgen/shared_world.lua')
  local hostAddress=loadLocal('lib/crossgen/host_address.lua').new()
  local S = { connected = false, peers = {}, chat = {}, channels = {} }
  local discovery=loadLocal('lib/crossgen/discovery.lua').new(adapter.game,adapter.generation)
  local net, authority, client, provider, config, activities, lanPort
  local tick, sequence = 0, 0
  local members, sequences = {}, {}
  local waitingHello={};local helloBudget=0;local pendingPositions={}
  local delegation
  local function resetPeers()
    S.peers=setmetatable({}, {__index=function(t,k)if k=='remote'then return rawget(t,S.selectedPeer or '') or select(2,next(t))end end})
  end
  resetPeers()
  function S.roster()local out={};for id,m in pairs(members)do if id~=S.localId and not m.server then local row={id=id,name=m.name,capabilities=m.capabilities};for k,v in pairs(S.peers[id]or{})do row[k]=v end;out[#out+1]=row end end;table.sort(out,function(a,b)return a.id<b.id end);return out end
  function S.selectPeer(id)if not members[id]or id==S.localId then return false end;S.selectedPeer=id;S.peerCapabilities=members[id].capabilities;return true end
  function S.peerInfo(id)return members[id]end
  local function validToken(s) return type(s)=='string' and #s>0 and #s<=128 end
  local function finite(n) return type(n)=='number' and n==n and math.abs(n)<1e7 end
  local function position(p)
    if type(p)~='table' or not validToken(p.map) or not finite(p.x) or not finite(p.y)
      or not finite(p.px) or not finite(p.py) then return end
    if p.facing~='up' and p.facing~='down' and p.facing~='left' and p.facing~='right' then return end
    local ride
    if type(p.ride)=='table' and (p.ride.mode=='ground' or p.ride.mode=='surf' or p.ride.mode=='fly')
     and type(p.ride.species)=='string' and #p.ride.species<=32 and p.ride.species:match('^[A-Z0-9_]+$')then
     ride={showRider=p.ride.showRider~=false,mountScale=finite(p.ride.mountScale)and math.max(.25,math.min(8,p.ride.mountScale))or 1,riderLift=finite(p.ride.riderLift)and math.max(-32,math.min(64,p.ride.riderLift))or 8,mode=p.ride.mode,species=p.ride.species,height=finite(p.ride.height)and math.max(0,math.min(96,p.ride.height))or 0}
    end
    return {ride=ride,map=p.map,x=p.x,y=p.y,px=p.px,py=p.py,facing=p.facing,
      moving=p.moving==true,busy=p.busy==true,skyBusy=p.skyBusy==true or(p.skyBusy==nil and p.busy==true),graphics=finite(p.graphics)and math.floor(p.graphics)or nil,height=finite(p.height)and math.max(0,math.min(96,p.height))or 0,name=tostring(p.name or 'TRAINER'):sub(1,16)}
  end
  local function send(msg,target) if net and not net.closed then msg.from=S.localId;msg.to=target;if S.host and not target then for id in pairs(members)do if id~='host'then net:send(msg,id)end end;return true end;return net:send(msg,S.host and target or nil) end end
  local skies=loadLocal('lib/crossgen/sky_session.lua')(mod,loadLocal,adapter,S,send)
  activities=loadLocal('lib/crossgen/activities.lua')(S,adapter,send)
  local function findProvider()
    local other=mod.find and mod.find('overworld_wild_spawns')
    local p=other and other.exports and other.exports.sharedSpawns
    return p and p.version==1 and p or nil
  end
  local function delegated()return S.ecologyOwners and S.ecologyOwners.wilds==S.localId end
  local function configureProvider()
    local p=findProvider()
    if not S.host and not(S.hostCapabilities or{}).sharedWilds then p=nil end
    local role=(S.host or delegated())and 'host'or 'guest'
    if provider~=p or (config and config.role~=role)then
      if provider then provider.configure(nil) end
      provider=p
      if config then config.role=role end
      if provider and config then provider.configure(config);for map,state in pairs(client and client.maps or{})do local rows={};for _,r in pairs(state.rows or{})do rows[#rows+1]=r end;provider.apply(map,rows)end end
    end
  end
  local function installWorld(session)
    S.session=session
    config={session=session,catching=S.host or (S.hostCapabilities or {}).sharedCatching==true,role=(S.host or delegated())and 'host'or 'guest',request=function(map,id,action)
      if not S.connected or not client then return false,'not connected' end
      if S.activity then return false,'player busy with link activity' end
      if action and action.action=='catch' and not config.catching then return false,'host does not support shared catching' end
      local n,why=client:request(map,id,action);return n~=nil,why
    end}
    client=SharedWorld.new{session=session,
      send=function(_,msg)
        if S.host then return authority:handle('local',msg,adapter.position()) end
        return send(msg)
      end,
      onSnapshot=function(map,rows) if provider then provider.apply(map,rows) end end,
      onEncounter=function(row,map)
        if not provider then return false,'visible spawn mod unavailable' end
        local p=adapter.position();if not p or p.busy or S.activity then return false,'player busy' end
        return provider.beginEncounter(row,map)
      end,
      onCatch=function(row,map,request)
        if not provider or not provider.beginCatch then return false,{message='visible catching unavailable'} end
        local p=adapter.position();if not p or p.busy or S.activity then return false,{message='player busy'} end
        return provider.beginCatch(row,map,request)
      end,
      onDenied=function(reason,map,id) S.notice=reason;if provider and provider.catchDenied then provider.catchDenied(map,id,reason)end end}
    if S.host then
      authority=SharedWorld.new{host=true,session=session,canCatch=function(position,row,action,map)
        if delegation then return delegation.canCatch(position,row,action,map)end
        return provider and provider.canCatch and provider.canCatch(position,row,action,map)==true
      end,send=function(peer,msg)
        if peer=='local' or not peer then client:handle('host',msg,nil,true) end
        if peer~='local' then send(msg,peer) end
      end}
    end
    configureProvider()
    if provider then provider.configure(config) end
  end
  function S.disconnect(reason)
    lanPort=nil;hostAddress.clear();S.publicIP=nil;S.publicIPStatus=nil
    discovery.stop();S.status=nil;S.address=nil;S.code=nil;S.sentHello=nil
    skies.clear()
    if delegation then delegation.clear();delegation=nil end;S.ecologyOwners=nil;S.ecologyEpoch=nil;S.dedicated=nil
    S.connected=false;S.notice=reason;members={};sequences={};waitingHello={};pendingPositions={};S.selectedPeer=nil;S.localId=nil;S.hostCapabilities={};S.peerCapabilities={};resetPeers()
    activities.disconnect()
    if net then net:close();net=nil end
    if provider then provider.configure(nil);provider=nil end
    if client then client:disconnect('host') end
    for _,channel in pairs(S.channels)do channel.closed=true;channel.paired=false end
    S.channels={};client=nil;authority=nil;config=nil;S.session=nil
    if adapter.clearPeers then adapter.clearPeers() end
  end
  local function start(host,method,...)
    S.disconnect();S.host=host;net=Net.new();tick=0;sequence=0
    local ok=net[method](net,...)
    if not ok then S.notice=net.error;return false,net.error end
    S.status='connecting';return true
  end
  local capabilities,ready
  function S.hostLan(port,capacity,publicIP)
    port=tonumber(port)or Native.defaultPort()
    if port%1~=0 or port<1 or port>65535 then return false,'Invalid port'end
    capacity=math.max(4,math.min(128,math.floor(tonumber(capacity)or 128)))
    local ok,why=start(true,'host',port,capacity+(adapter.dedicated and 1 or 0))
    if ok then
      lanPort=port
      S.localId='host';S.dedicated=adapter.dedicated==true;members.host={id='host',server=S.dedicated,name=tostring((adapter.position()or{}).name or 'TRAINER'):sub(1,16),capabilities=capabilities()};S.hostCapabilities=members.host.capabilities
      ready(tostring(os.time())..'-'..tostring(love.math.random(1,2147483646)))
      if S.dedicated then delegation=loadLocal('lib/crossgen/delegation.lua')(S,send,authority,loadLocal('lib/crossgen/sky_world.lua'),function()return members end)end
      S.status='Hosting room';S.address=net.address
      hostAddress.start(publicIP or adapter.publicIP);S.publicIP=hostAddress.ip;S.publicIPStatus=hostAddress.status
      local found,err=discovery.host(port,adapter.serverName or(adapter.position()or{}).name)
      if not found then S.notice=err end
    end
    return ok,why
  end
  function S.kick(id)
    id=id or S.selectedPeer or (S.roster()[1]or{}).id
    if not S.host or not id or id=='host' or not members[id]then return false,'Select a connected guest'end
    return net:kick(id)
  end
  function S.joinLan(address)
    address=type(address)=='string'and address:match('^%s*(.-)%s*$')or''
    local host,port=address:match('^([%w%.%-]+):(%d+)$')
    if not host and address:match('^[%w%.%-]+$')then host=address end
    if not host or host==''or(port and(tonumber(port)<1 or tonumber(port)>65535))then return false,'Enter host name or IP:port' end
    return start(false,'join',address)
  end
  function S.scanLan()return discovery.scan()end
  function S.stopScan()if not net then discovery.stop()end end
  function S.localGames()return discovery.list()end
  function S.hostOnline(relay)return start(true,'hostOnline',relay or '')end
  function S.joinOnline(relay,code)return start(false,'joinOnline',relay or '',code)end
  capabilities=function()
    local out={};for k,v in pairs(adapter.capabilities and adapter.capabilities()or{})do out[k]=v end
    local p=findProvider();out.sharedWilds=p~=nil;out.sharedCatching=p and type(p.beginCatch)=='function' and type(p.canCatch)=='function' or false
    out.sharedSkies=adapter.dedicated==true or skies.available()
    if adapter.dedicated then out.sharedWilds=true;out.sharedCatching=true end
    return out
  end
  local function hello()
    send{type='world_hello',protocol=2,generation=adapter.generation,game=adapter.game,
      host=S.host,name=(adapter.position() or {}).name,capabilities=capabilities()}
  end
  ready=function(session)
    installWorld(session);S.connected=true;S.status='connected'
  end
  local function chat(msg,localSender,peer)
    if type(msg.text)~='string' then return end
    local text=msg.text:gsub('[%z\1-\31\127]',''):sub(1,240)
    if text=='' then return end
    local p=localSender and adapter.position() or S.peers[peer]
    local item={text=text,name=p and p.name or 'TRAINER',localSender=localSender,peerId=peer,age=0}
    S.chat[#S.chat+1]=item;if #S.chat>50 then table.remove(S.chat,1)end
    if adapter.chat then adapter.chat(item,p)end
  end
  function S.say(text)
    if not S.connected then return false,'not connected' end
    if type(text)~='string' or #text>240 then return false,'message too long' end
    local msg={type='world_chat',session=S.session,text=text};send(msg);chat(msg,true);return true
  end
  function S.channel(name,peer,initiator)
    assert(validToken(name));if S.channels[name]then return S.channels[name] end
    local a=S.activity or{};peer=peer or a.peer;initiator=initiator==nil and a.initiator or initiator
    local C={peer=peer,paired=S.connected,closed=not S.connected,inbox={},mode=initiator and 'hosting' or 'joining'}
    function C:send(msg)if not self.closed then return send({type='world_channel',session=S.session,channel=name,payload=msg},self.peer)end end
    function C:update()end -- The world owns the one physical socket pump.
    function C:poll()local q=self.inbox;self.inbox={};return q end
    function C:close()self.closed=true;self.paired=false;S.channels[name]=nil end
    S.channels[name]=C;return C
  end
  local function caps(value)
    local out={};for _,k in ipairs({'single','double','trade','sharedWilds','sharedCatching','sharedSkies'})do out[k]=type(value)=='table'and value[k]==true end;return out
  end
  local function member(id,value)
    if type(id)~='string'or #id>16 or not(id=='host'or id:match('^p%d+$'))or type(value)~='table'then return end
    members[id]={id=id,server=id=='host'and value.server==true,name=tostring(value.name or 'TRAINER'):sub(1,16),capabilities=caps(value.capabilities)}
    if id~=S.localId and not members[id].server and not S.selectedPeer then S.selectPeer(id)end
  end
  local function departed(id)
    members[id]=nil;waitingHello[id]=nil;pendingPositions[id]=nil;S.peers[id]=nil;sequences[id]=nil
    if authority then authority:disconnect(id)end
    if skies.peerDisconnected then skies.peerDisconnected(id)end
    activities.peerDisconnected(id)
    if adapter.removePeer then adapter.removePeer(id)end
    if delegation then delegation.departed(id)end
    if S.selectedPeer==id then S.selectedPeer=nil;S.peerCapabilities={};local row=S.roster()[1];if row then S.selectPeer(row.id)end end
  end
  local function handle(msg,origin)
    if type(msg)~='table'then return end
    if msg.type=='world_hello'and S.host then
      if helloBudget<=0 then waitingHello[origin]=msg;return end;helloBudget=helloBudget-1
      if msg.protocol~=2 or msg.generation~=adapter.generation or msg.game~=adapter.game or msg.host~=false then net:kick(origin);return end
      if members[origin]then return end
      member(origin,msg)
      send({type='world_welcome',protocol=2,session=S.session,id=origin,generation=adapter.generation,game=adapter.game,members=members,dedicated=S.dedicated},origin)
      send({type='world_member',session=S.session,id=origin,member=members[origin]})
      if delegation then delegation.refresh(true)end
      return
    end
    if msg.type=='world_welcome'and not S.host and not S.connected then
      if origin~='host'or msg.protocol~=2 or not validToken(msg.session)or msg.generation~=adapter.generation or msg.game~=adapter.game or type(msg.members)~='table'then return end
      if type(msg.id)~='string'or not msg.id:match('^p%d+$')then return end
      S.localId=msg.id;S.dedicated=msg.dedicated==true;local n=0;for id,m in pairs(msg.members)do n=n+1;if n<=129 then member(id,m)end end
      S.hostCapabilities=(members.host or{}).capabilities or{};ready(msg.session);return
    end
    if not S.connected or msg.session~=S.session then return end
    -- Only the authenticated host may batch positions. Bound traversal and
    -- pass each row through the same member/sequence/position validation.
    if msg.type=='world_positions'then
      if not S.host and origin=='host'and type(msg.rows)=='table'then
        for i=1,math.min(#msg.rows,32)do local row=msg.rows[i]
          if type(row)=='table'then handle({type='world_position',session=S.session,from=row.id,sequence=row.sequence,position=row.position},origin)end
        end
      end;return
    end
    local peer=S.host and origin or msg.from
    if S.host then
      if not members[peer]then return end
      msg.from=peer
      if msg.type=='world_activity'or msg.type=='world_channel'then
        if type(msg.to)~='string'or not members[msg.to]or msg.to==peer then return end
        if msg.to~='host'then net:send(msg,msg.to);return end
      elseif msg.type=='world_position'then
        local p=position(msg.position);if not p or not finite(msg.sequence)then return end;msg.position=p
        if msg.sequence>(sequences[peer]or -1)then pendingPositions[peer]={id=peer,sequence=msg.sequence,position=p}end
      elseif msg.type=='world_chat'then
        if type(msg.text)~='string'or #msg.text>240 then return end;for id in pairs(members)do if id~='host'and id~=peer then net:send(msg,id)end end
      end
    elseif origin~='host'then return end
    if not S.host and msg.type=='world_member'and peer=='host'then member(msg.id,msg.member);return end
    if not S.host and msg.type=='world_departed'and peer=='host'then departed(msg.id);return end
    if peer==S.localId or not members[peer]then return end
    if (msg.type=='shared_wilds'or msg.type=='shared_skies')and not S.host and peer~='host'then return end
    if delegation and delegation.handle(msg,peer)then return end
    if not S.host and peer=='host'and S.dedicated then
      if msg.type=='world_delegate'and type(msg.epoch)=='number'and msg.epoch>(S.ecologyEpoch or 0)and type(msg.owners)=='table'then
        S.ecologyEpoch=msg.epoch;S.ecologyOwners={wilds=members[msg.owners.wilds]and msg.owners.wilds or nil,skies=members[msg.owners.skies]and msg.owners.skies or nil};configureProvider();skies.update(0);return
      elseif msg.type=='world_validate'then
        local domain=msg.domain;local owner=S.ecologyOwners and S.ecologyOwners[domain]
        if owner==S.localId and msg.epoch==S.ecologyEpoch and type(msg.request)=='string'then
          local ok,allowed=false,false
          if domain=='wilds'and provider and provider.canCatch then ok,allowed=pcall(provider.canCatch,msg.position,msg.row,msg.action,msg.map)
          elseif domain=='skies'then ok,allowed=pcall(skies.validate,msg.position,msg.row,msg.action,msg.map)end
          send{type='world_validated',session=S.session,epoch=S.ecologyEpoch,request=msg.request,allowed=ok and allowed==true}
        end;return
      end
    end
    if activities.handle(msg,peer)then return end
    if skies.handle(msg,peer)then return end
    if msg.type=='world_position'then
      local p=position(msg.position)
      if p and finite(msg.sequence)and msg.sequence>(sequences[peer]or 0)then
        local previous=S.peers[peer];sequences[peer]=msg.sequence;S.peers[peer]=p
        if adapter.peer then adapter.peer(p,peer)end
        if S.host and authority.maps[p.map]and(not previous or previous.map~=p.map)then authority:broadcast(p.map,peer)end
      end
    elseif msg.type=='shared_wilds'then
      if S.host then authority:handle(peer,msg,S.peers[peer])else client:handle('host',msg,nil,true)end
    elseif msg.type=='world_chat'then chat(msg,false,peer)
    elseif msg.type=='world_channel'and validToken(msg.channel)and type(msg.payload)=='table'then
      local c=S.channels[msg.channel];if c and c.peer==peer and not c.closed and #c.inbox<256 then c.inbox[#c.inbox+1]=msg.payload end
    end
  end
  function S.update(dt)
    dt=math.max(0,math.min(.25,tonumber(dt)or 0))
    hostAddress.update(dt);S.publicIP=hostAddress.ip;S.publicIPStatus=hostAddress.status
    for _,msg in ipairs(S.chat)do msg.age=msg.age+dt end
    if adapter.update then adapter.update(dt)end
    discovery.update(dt,net and S.host and S.connected and #S.roster()<(net.capacity or 64)-1)
    if not net then return end
    net:update(dt)
    S.address,S.code=net.address,net.code
    if net.closed or net.error then S.disconnect(net.error or 'Disconnected');return end
    helloBudget=4
    for id,msg in pairs(waitingHello)do if helloBudget<=0 then break end;waitingHello[id]=nil;handle(msg,id)end
    for _,event in ipairs(net:poll())do
      if event.event=='connect'and not S.host then hello()
      elseif event.event=='disconnect'then
        if S.host then departed(event.peer);send{type='world_departed',session=S.session,id=event.peer}
        else S.disconnect('Host disconnected')end
      elseif event.event=='message'then handle(event.message,event.peer)end
      if not net then return end
    end
    if not S.connected then return end
    configureProvider();if delegation then delegation.update(dt)end;activities.update(dt);client:update(dt);if authority then authority:update(dt)end
    skies.update(dt)
    tick=tick+dt
    if tick<.1 then return end
    tick=tick%.1;sequence=sequence+1
    local p=adapter.position()
    if p then
      if S.host then pendingPositions.host={id='host',sequence=sequence,position=p}
      else send{type='world_position',session=S.session,sequence=sequence,position=p}end
    end
    if S.host then
      -- Coalesce each guest's latest position into bounded room snapshots,
      -- instead of relaying every incoming packet separately to every peer.
      local rows={}
      for id,row in pairs(pendingPositions)do
        rows[#rows+1]=row;pendingPositions[id]=nil
        if #rows==32 then send{type='world_positions',session=S.session,rows=rows};rows={}end
      end
      if #rows>0 then send{type='world_positions',session=S.session,rows=rows}end
    end
    if (authority or delegated())and provider then
      local map,rows=provider.snapshot()
      if map then if authority then authority:publish(map,rows)else send{type='world_ecology',session=S.session,epoch=S.ecologyEpoch,domain='wilds',map=map,rows=rows}end end
      local seen={[map or '']=true}
      for _,peer in pairs(S.peers)do
        if not seen[peer.map]and provider.remoteSnapshot then
          seen[peer.map]=true;local rows=provider.remoteSnapshot(peer.map,peer,.1)
          if rows then if authority then authority:publish(peer.map,rows)else send{type='world_ecology',session=S.session,epoch=S.ecologyEpoch,domain='wilds',map=peer.map,rows=rows}end end
        end
      end
    end
  end
  function S.publishSky(snapshot)if S.ecologyOwners and S.ecologyOwners.skies==S.localId then send{type='world_ecology',session=S.session,epoch=S.ecologyEpoch,domain='skies',map=snapshot.map,rows=snapshot.spawns}end end
  function S.state()return {connected=S.connected,host=S.host,session=S.session,address=S.address,code=S.code,
    peers=S.peers,notice=S.notice,spawns=client and client.maps or {},authority=authority and authority.maps or {}}end
  mod.hooks:wrap('input.step',function(nextFn,game,dt)nextFn(game,dt);S.update(dt)end)
  return S
end
