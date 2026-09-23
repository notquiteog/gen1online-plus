-- Sky positions are pixels and altitude is independent of the ground grid.
-- The host owns identities; a bird remains reserved until its battle ends.
local M={}
local function finite(n)return type(n)=='number' and n==n and math.abs(n)<=65535 end
local function token(s)return type(s)=='string' and #s>0 and #s<=96 end
local function integer(n)return type(n)=='number' and n==n and math.abs(n)<9007199254740992 and n%1==0 end
local modes={roam=true,ground=true,rise=true,toLand=true,leave=true}
local facing={up=true,down=true,left=true,right=true}
local function copy(row)local r={};for k,v in pairs(row)do r[k]=v end;return r end
local function record(r)
 if type(r)~='table' or not token(r.id) or not token(r.species) or #r.species>48
  or not integer(r.level) or r.level<1 or r.level>100 or not finite(r.x) or not finite(r.y)
  or not finite(r.alt) or r.alt<0 or r.alt>1024 or not finite(r.vx or 0) or math.abs(r.vx or 0)>256
  or not finite(r.vy or 0) or math.abs(r.vy or 0)>256 or not facing[r.facing or 'right']
  or not modes[r.mode or 'roam'] then return end
 return {id=r.id,species=r.species,level=r.level,x=r.x,y=r.y,alt=r.alt,vx=r.vx or 0,vy=r.vy or 0,
  facing=r.facing or 'right',mode=r.mode or 'roam',bold=r.bold==true}
end
M.record=record
function M.new(opts)
 assert(opts and token(opts.session) and type(opts.send)=='function')
 local W={host=opts.host==true,maps={},claims={},pending={},active={},received={},restoring={},sequence=0}
 local function key(map,id)return map..'\0'..id end
 local function capRows(map,rows)
  local ids={};for id in pairs(rows)do ids[#ids+1]=id end
  table.sort(ids)
  local count=#ids
  for i=#ids,1,-1 do
   if count<=32 then break end
   local id=ids[i]
   if not W.restoring[key(map,id)]then rows[id]=nil;count=count-1 end
  end
 end
 local function packet(kind,map)return {type='shared_skies',protocol=1,session=opts.session,kind=kind,map=map}end
 function W:broadcast(map,peer)
  local state=self.maps[map];if not self.host or not state then return false end
  local msg=packet('snapshot',map);msg.revision=state.revision;msg.rows={}
  for _,r in pairs(state.rows)do msg.rows[#msg.rows+1]=copy(r)end
  table.sort(msg.rows,function(a,b)return a.id<b.id end);opts.send(peer,msg);return true
 end
 function W:acknowledgeSnapshot(map,revision)
  if not self.host or not integer(revision)then return false end
  for k,entry in pairs(self.restoring)do
   if entry.map==map and revision>=entry.revision then self.restoring[k]=nil end
  end
  return true
 end
 function W:publish(snapshot)
  if not self.host or type(snapshot)~='table' or not token(snapshot.map) or type(snapshot.spawns)~='table' or #snapshot.spawns>32 then return false end
  local rows,seen={},{}
  for _,r in ipairs(snapshot.spawns)do
   r=record(r);if not r or seen[r.id]then return false end;seen[r.id]=true
   if not self.claims[key(snapshot.map,r.id)]then rows[r.id]=r end
  end
  -- A release must reach the host's ecology before a fresh provider snapshot
  -- may remove it. Keep that identity through stale/failed local application.
  for _,entry in pairs(self.restoring)do if entry.map==snapshot.map then rows[entry.row.id]=copy(entry.row)end end
  capRows(snapshot.map,rows)
  local old=self.maps[snapshot.map]
  self.maps[snapshot.map]={rows=rows,revision=(old and old.revision or 0)+1}
  return self:broadcast(snapshot.map)
 end
 function W:request(map,id,context)
  if not token(map) or not token(id) or next(self.pending) or next(self.active) then return false,'claim unavailable' end
  self.sequence=self.sequence+1
  local msg=packet('claim',map);msg.spawn=id;msg.request=self.sequence;msg.airborne=type(context)=='table' and context.airborne==true
  self.pending[msg.request]={map=map,id=id};opts.send(nil,msg);return true
 end
 function W:finish(map,id,outcome)
  local k=key(map,id);local claim=self.active[k];if not claim then return false end
  self.active[k]=nil
  local msg=packet(type(outcome)=='table' and outcome.consumed==true and 'commit' or 'release',map)
  msg.spawn=id;msg.request=claim.request;opts.send(nil,msg);return true
 end
 local function restore(k,claim)
  W.claims[k]=nil
  local state=W.maps[claim.map]
  state.rows[claim.row.id]=claim.row;state.revision=state.revision+1
  W.restoring[k]={row=copy(claim.row),map=claim.map,revision=state.revision}
  capRows(claim.map,state.rows)
  local reply=packet('deny',claim.map);reply.request=claim.request;reply.reason='claim released'
  W.received[claim.peer]=W.received[claim.peer]or{};W.received[claim.peer][claim.request]=reply
  W:broadcast(claim.map)
 end
 function W:handle(peer,msg,position,isHost)
  if type(msg)~='table' or msg.type~='shared_skies' or msg.protocol~=1 or msg.session~=opts.session or not token(msg.map)then return false end
  if not self.host then
   if not isHost then return false end
   if msg.kind=='snapshot'then
    if not integer(msg.revision) or msg.revision<1 or type(msg.rows)~='table' or #msg.rows>32 then return false end
    local old=self.maps[msg.map];if old and old.revision>=msg.revision then return false end
    local rows,list={},{}
    for _,r in ipairs(msg.rows)do r=record(r);if not r or rows[r.id]then return false end;rows[r.id]=r;list[#list+1]=r end
    self.maps[msg.map]={rows=rows,revision=msg.revision}
    if opts.onSnapshot then opts.onSnapshot(msg.map,list,msg.revision)end;return true
   elseif msg.kind=='grant' or msg.kind=='deny'then
    local p=integer(msg.request)and self.pending[msg.request]
    if not p or p.map~=msg.map then return false end
    if msg.kind=='deny'then self.pending[msg.request]=nil;if opts.onDenied then opts.onDenied(p.map,p.id,msg.reason)end;return true end
    local row=record(msg.row);if not row or row.id~=p.id then return false end
    self.pending[msg.request]=nil
    self.active[key(p.map,p.id)]={request=msg.request}
    local ran,started=pcall(opts.onEncounter or function()return false end,row,p.map)
    if not ran or started~=true then self:finish(p.map,p.id,{consumed=false})end
    return ran and started==true
   end
   return false
  end
  if msg.kind=='claim'then
   if not integer(msg.request) or msg.request<1 or not token(msg.spawn) or type(msg.airborne)~='boolean'then return false end
   local cache=self.received[peer]or{};self.received[peer]=cache
   if cache[msg.request]then opts.send(peer,cache[msg.request]);return true end
   local state=self.maps[msg.map];local row=state and state.rows[msg.spawn];local reason
   local occupied=false
   for _,claim in pairs(self.claims)do if claim.peer==peer and not claim.committed then occupied=true;break end end
   if not position or position.map~=msg.map then reason='different map'
   elseif position.busy or occupied then reason='player busy'
   elseif not row then reason='already claimed'
   elseif not row.bold then reason='scenery bird'
   elseif not finite(position.px) or not finite(position.py) or math.abs(position.px-row.x)+math.abs(position.py-row.y)>32 then reason='too far'
   elseif not opts.canClaim or opts.canClaim(position,row,{airborne=msg.airborne},msg.map)~=true then reason='contact unavailable' end
   local reply=packet(reason and 'deny' or 'grant',msg.map);reply.request=msg.request;reply.reason=reason
   if not reason then
    reply.row=copy(row);state.rows[row.id]=nil;state.revision=state.revision+1
    self.restoring[key(msg.map,row.id)]=nil
    self.claims[key(msg.map,row.id)]={row=copy(row),map=msg.map,request=msg.request,peer=peer}
   end
   cache[msg.request]=reply
   opts.send(peer,reply) -- Native entry consumes its pending contact before the removal snapshot.
   if not reason then self:broadcast(msg.map)end
   return reason==nil
  elseif msg.kind=='commit' or msg.kind=='release'then
   if not token(msg.spawn) or not integer(msg.request)then return false end
   local k=key(msg.map,msg.spawn);local claim=self.claims[k]
   if not claim or claim.peer~=peer or claim.request~=msg.request or claim.committed then return false end
   if msg.kind=='commit'then claim.committed=true else restore(k,claim)end;return true
  end
  return false
 end
 function W:disconnect(peer)
  if self.host then
   for k,claim in pairs(self.claims)do if claim.peer==peer and not claim.committed then restore(k,claim)end end
   self.received[peer]=nil
  else self.maps={};self.active={};self.pending={}end
 end
 return W
end
return M
