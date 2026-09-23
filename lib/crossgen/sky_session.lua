-- Optional Wild Skies bridge. Its public provider owns rendering and ecology;
-- the online room supplies authority, contact arbitration and battle outcomes.
return function(mod,loadLocal,adapter,S,send)
 local World=loadLocal('lib/crossgen/sky_world.lua')
 local M={};local provider,client,host,session,role;local queue={};local tick=0
 local required={'registerSharedSkyProvider','unregisterSharedSkyProvider','canClaimSky',
  'grantSharedSkyFieldContact','denySharedSkyFieldContact','applySharedSkyFieldSnapshot','sharedSkyFieldSnapshot'}
 local function find()
  local m=mod.find and mod.find('wild_skies');local p=m and m.exports
  if not p then return end
  for _,name in ipairs(required)do if type(p[name])~='function'then return end end
  return p
 end
 function M.available()return find()~=nil end
 function M.clear()
  local old=provider
  provider,client,host,session,role=nil,nil,nil,nil,nil;queue={};tick=0
  if old then old.unregisterSharedSkyProvider('gen1online-plus')end
 end
 local function posed(p)
  if not p then return end
  local out={};for k,v in pairs(p)do out[k]=v end
  -- Ground contact/activities may be disabled by flight itself. Aerial contact
  -- still honors actual menus, scripts and battles through the separate flag.
  if out.skyBusy~=nil then out.busy=out.skyBusy==true end
  out.altitude=(out.ride and out.ride.mode=='fly'and out.ride.height)or out.height or 0
  return out
 end
 local function position()
  local out=posed(adapter.position());if out then out.busy=out.busy or S.activity~=nil end;return out
 end
 local function configure()
  local found=find()
  -- Old/incomplete peers keep standalone skies. A removed capability/provider
  -- also unregisters a previous agreement and invalidates all old callbacks.
  if not S.connected or(S.peerCapabilities or{}).sharedSkies~=true or not found then
   if provider then M.clear()end;return
  end
  if provider==found and session==S.session and role==S.host then return true end
  M.clear();provider=found;session=S.session;role=S.host
  local owner,room=found,session
  local function current()return provider==owner and session==room and S.session==room and S.host==role and S.connected end
  local ownClient
  client=World.new{session=session,send=function(_,msg)
   if not current()then return end
   if S.host then queue[#queue+1]={toHost=true,msg=msg}else send(msg)end
  end,onSnapshot=function(map,rows,revision)
   if not current()then return end
   local applied=owner.applySharedSkyFieldSnapshot{domain='SKY',map=map,spawns=rows,revision=revision,localAuthority=S.host==true}
   if applied==true and host then host:acknowledgeSnapshot(map,revision)end
  end,onEncounter=function(row,map)
   local p=position();if not current()or not p or p.busy or p.map~=map then return false end
   return owner.grantSharedSkyFieldContact(map,row.id,row)==true
  end,onDenied=function(map,id,reason)
   if current()then owner.denySharedSkyFieldContact(map,id);S.notice=reason end
  end}
  ownClient=client
  if S.host then
   host=World.new{host=true,session=session,canClaim=function(p,row,context,map)
    return current()and owner.canClaimSky(posed(p),row,context,map)==true
   end,send=function(peer,msg)
    if not current()then return end
    if peer==nil or peer=='local'then queue[#queue+1]={msg=msg}end
    if peer~='local'then send(msg)end
   end}
  end
  local accepted=owner.registerSharedSkyProvider('gen1online-plus',{
   role=S.host and 'host' or 'guest',localAuthority=S.host==true,
   requestClaim=function(map,id,context)
    if not current()or client~=ownClient then return false,'not connected'end
    local p=position();if not p or p.busy then return false,'player busy'end
    return ownClient:request(map,id,context)
   end,
   finishClaim=function(map,id,result)
    if not current()or client~=ownClient then return false,'not connected'end
    return ownClient:finish(map,id,result)
   end,
  })
  if accepted~=true then M.clear();return end
  return true
 end
 function M.handle(msg)
  if type(msg)~='table'or msg.type~='shared_skies'then return false end
  if not configure()then return true end
  if host then host:handle('remote',msg,posed(S.peers.remote))else client:handle('host',msg,nil,true)end
  return true
 end
 local function drain()
  -- Local grants must wait until requestClaim returns and the provider stores
  -- its pending contact. Process all resulting release/restore snapshots before
  -- publishing again, so a stale ecology snapshot cannot delete a restored bird.
  for _=1,16 do
   if #queue==0 then return true end
   local pending=queue;queue={}
   for _,item in ipairs(pending)do
    if not client then return false end
    if item.toHost then if host then host:handle('local',item.msg,position())end
    else client:handle('host',item.msg,nil,true)end
   end
  end
  return #queue==0
 end
 function M.update(dt)
  if not configure()then return end
  if not drain()then return end
  tick=tick+math.max(0,tonumber(dt)or 0)
  if host and tick>=.1 then
   tick=tick%.1;local p=position();local maps={}
   if p and p.map then maps[p.map]=true end
   for _,id in ipairs(provider.sharedSkyNeighborMaps and provider.sharedSkyNeighborMaps()or{})do maps[id]=true end
   if S.peers.remote and S.peers.remote.map then maps[S.peers.remote.map]=true end
   for id in pairs(maps)do
    local snapshot=provider.sharedSkyFieldSnapshot(id)
    if snapshot then host:publish(snapshot)end
   end
  end
  drain()
 end
 return M
end
