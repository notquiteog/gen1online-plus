-- Persistent world connection. Native battle/trade transports can be carried
-- on separate channels without closing presence or chat when a match ends.
return function(mod, loadLocal, adapter)
  local Net = require('src.link.Net')
  local SharedWorld = loadLocal('lib/crossgen/shared_world.lua')
  local S = { connected = false, peers = {}, chat = {}, channels = {} }
  local net, authority, client, provider, config, activities
  local tick, sequence = 0, 0
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
      moving=p.moving==true,busy=p.busy==true,skyBusy=p.skyBusy==true or(p.skyBusy==nil and p.busy==true),graphics=p.graphics,height=finite(p.height)and math.max(0,math.min(96,p.height))or 0,name=tostring(p.name or 'TRAINER'):sub(1,16)}
  end
  local function send(msg) if net and not net.closed then return net:send(msg) end end
  local skies=loadLocal('lib/crossgen/sky_session.lua')(mod,loadLocal,adapter,S,send)
  activities=loadLocal('lib/crossgen/activities.lua')(S,adapter,send)
  local function findProvider()
    local other=mod.find and mod.find('overworld_wild_spawns')
    local p=other and other.exports and other.exports.sharedSpawns
    return p and p.version==1 and p or nil
  end
  local function configureProvider()
    local p=findProvider()
    if provider~=p then
      if provider then provider.configure(nil) end
      provider=p
      if provider and config then provider.configure(config) end
    end
  end
  local function installWorld(session)
    S.session=session
    config={session=session,catching=S.host or (S.peerCapabilities or {}).sharedCatching==true,role=S.host and 'host' or 'guest',request=function(map,id,action)
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
        return provider and provider.canCatch and provider.canCatch(position,row,action,map)==true
      end,send=function(peer,msg)
        if peer=='local' or not peer then client:handle('host',msg,nil,true) end
        if peer~='local' then send(msg) end
      end}
    end
    configureProvider()
    if provider then provider.configure(config) end
  end
  function S.disconnect(reason)
    skies.clear()
    S.connected=false;S.notice=reason;S.peers={}
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
  function S.hostLan(port)return start(true,'host',port)end
  function S.joinLan(address)return start(false,'join',address)end
  function S.hostOnline(relay)return start(true,'hostOnline',relay or Net.defaultRelayAddress())end
  function S.joinOnline(relay,code)return start(false,'joinOnline',relay or Net.defaultRelayAddress(),code)end
  local function capabilities()
    local out={};for k,v in pairs(adapter.capabilities and adapter.capabilities()or{})do out[k]=v end
    local p=findProvider();out.sharedCatching=p and type(p.beginCatch)=='function' and type(p.canCatch)=='function' or false
    out.sharedSkies=skies.available()
    return out
  end
  local function hello()
    send{type='world_hello',protocol=1,generation=adapter.generation,game=adapter.game,
      host=S.host,name=(adapter.position() or {}).name,capabilities=capabilities()}
  end
  local function ready(session)
    installWorld(session);S.connected=true;S.status='connected'
  end
  local function chat(msg,localSender)
    if type(msg.text)~='string' then return end
    local text=msg.text:gsub('[%z\1-\31\127]',''):sub(1,240)
    if text=='' then return end
    local p=localSender and adapter.position() or S.peers.remote
    local item={text=text,name=p and p.name or 'TRAINER',localSender=localSender,age=0}
    S.chat[#S.chat+1]=item;if #S.chat>50 then table.remove(S.chat,1)end
    if adapter.chat then adapter.chat(item,p)end
  end
  function S.say(text)
    if not S.connected then return false,'not connected' end
    if type(text)~='string' or #text>240 then return false,'message too long' end
    local msg={type='world_chat',session=S.session,text=text};send(msg);chat(msg,true);return true
  end
  function S.channel(name)
    assert(validToken(name));if S.channels[name]then return S.channels[name] end
    local C={paired=S.connected,closed=not S.connected,inbox={},mode=S.host and 'hosting' or 'joining'}
    function C:send(msg)if not self.closed then return send{type='world_channel',session=S.session,channel=name,payload=msg}end end
    function C:update()end -- The world owns the one physical socket pump.
    function C:poll()local q=self.inbox;self.inbox={};return q end
    function C:close()self.closed=true;self.paired=false;S.channels[name]=nil end
    S.channels[name]=C;return C
  end
  local function handle(msg)
    if type(msg)~='table'then return end
    if msg.type=='world_hello'then
      if msg.protocol~=1 or msg.generation~=adapter.generation or msg.game~=adapter.game or msg.host==S.host then
        S.disconnect('Both players must use the same game and compatible online mod.');return
      end
      S.peerCapabilities=type(msg.capabilities)=='table' and msg.capabilities or{}
      if S.host and not S.connected then
        local id=tostring(os.time())..'-'..tostring(love.math.random(1,2147483646))
        ready(id);send{type='world_welcome',protocol=1,session=id,generation=adapter.generation,game=adapter.game,capabilities=capabilities()}
      end
      return
    end
    if msg.type=='world_welcome' and not S.host and not S.connected then
      if msg.protocol==1 and validToken(msg.session) and msg.generation==adapter.generation and msg.game==adapter.game then S.peerCapabilities=type(msg.capabilities)=='table'and msg.capabilities or{};ready(msg.session)end
      return
    end
    if not S.connected or msg.session~=S.session then return end
    if activities.handle(msg)then return end
    if skies.handle(msg)then return end
    if msg.type=='world_position'then
      local p=position(msg.position)
      if p and finite(msg.sequence) and msg.sequence>(S.remoteSequence or 0)then
        S.remoteSequence=msg.sequence;S.peers.remote=p
        if adapter.peer then adapter.peer(p)end
        if S.host and authority.maps[p.map]then authority:broadcast(p.map,'remote')end
      end
    elseif msg.type=='shared_wilds'then
      if S.host then authority:handle('remote',msg,S.peers.remote) else client:handle('host',msg,nil,true)end
    elseif msg.type=='world_chat'then chat(msg,false)
    elseif msg.type=='world_channel' and validToken(msg.channel) and type(msg.payload)=='table'then
      local c=S.channels[msg.channel]
      if c and not c.closed and #c.inbox<256 then c.inbox[#c.inbox+1]=msg.payload end
    end
  end
  function S.update(dt)
    dt=math.max(0,math.min(.25,tonumber(dt)or 0))
    for _,msg in ipairs(S.chat)do msg.age=msg.age+dt end
    if adapter.update then adapter.update(dt)end
    if not net then return end
    net:update()
    S.address,S.code=net.address,net.code
    if net.closed or net.error then S.disconnect(net.error or 'Disconnected');return end
    if net.paired and not S.sentHello then S.sentHello=true;hello()end
    for _,msg in ipairs(net:poll())do handle(msg);if not net then return end end
    if not S.connected then return end
    configureProvider();activities.update(dt);client:update(dt);if authority then authority:update(dt)end
    skies.update(dt)
    tick=tick+dt
    if tick<.1 then return end
    tick=tick%.1;sequence=sequence+1
    local p=adapter.position()
    if p then send{type='world_position',session=S.session,sequence=sequence,position=p}end
    if authority and provider then
      local map,rows=provider.snapshot()
      if map then authority:publish(map,rows)end
      local peer=S.peers.remote
      if peer and peer.map~=map and provider.remoteSnapshot then
        local remoteRows=provider.remoteSnapshot(peer.map,peer,.1)
        if remoteRows then authority:publish(peer.map,remoteRows)end
      end
    end
  end
  -- Reset handshake sequencing between connections, not merely between maps.
  local oldDisconnect=S.disconnect
  function S.disconnect(reason)S.sentHello=false;S.remoteSequence=0;return oldDisconnect(reason)end
  function S.state()return {connected=S.connected,host=S.host,session=S.session,address=S.address,code=S.code,
    peers=S.peers,notice=S.notice,spawns=client and client.maps or {},authority=authority and authority.maps or {}}end
  mod.hooks:wrap('input.step',function(nextFn,game,dt)nextFn(game,dt);S.update(dt)end)
  return S
end
