-- Optional doubles traffic on a normal native link session. Native hello /
-- fingerprint checks, party clones, battle mechanics and cleanup still apply.
local M={}
function M.transport(net)
 local inbox={};local proxy={inbox=inbox}
 setmetatable(proxy,{__index=function(_,key)
  if key=='poll'then return function()
   local pass={};for _,msg in ipairs(net:poll())do
    if msg.type=='room_double_turn'or msg.type=='room_double_hash'then
     if #inbox<32 then inbox[#inbox+1]=msg end
    else pass[#pass+1]=msg end
   end;return pass
  end end
  local value=net[key]
  if type(value)=='function'then return function(_,...)return value(net,...)end end
  return value
 end})
 return proxy
end
function M.attach(screen,proxy,provider,host)
 local api,why=provider.attach(screen);if not api then return false,why end
 local Fingerprint=require('src.link.Fingerprint')
 local state={turn=1,selected=1,picks={false,false},remote=nil,hashes={},peerHashes={},verified=0}
 local originalUpdate=screen.update
 local function fail(reason)
  if state.failed then return end
  state.failed=true;api.finish(reason);proxy:send{type='bye'}
 end
 local function verify(turn)
  local a,b=state.hashes[turn],state.peerHashes[turn]
  if a and b then if a~=b then fail('Double battle state mismatch.')else state.verified=math.max(state.verified,turn)end end
 end
 local function resolve()
  if state.failed or not state.mine or not state.remote then return end
  local n=state.turn;local ok,err=api.resolve(state.mine,state.remote)
  if not ok then fail(err);return end
  local sig=Fingerprint.digest(api.signature(host));state.hashes[n]=sig
  proxy:send{type='room_double_hash',turn=n,hash=sig};verify(n)
  state.turn=n+1;state.mine=nil;state.remote=nil;state.picks={false,false};state.selected=1
 end
 function screen.link.submit(s,action)
  if state.failed or state.mine then return end
  if state.turn>state.verified+1 then return s:refuseMenu('Waiting for turn confirmation.')end
  local slots=api.slots();local index=slots[state.selected]
  if not index then return end
  local value,err=api.encode(action,index)
  if not value then return s:refuseMenu(err)end
  state.picks[index]=value
  if slots[state.selected+1]then
   state.selected=state.selected+1;api.select(slots[state.selected]);s.phase='menu';return
  end
  api.restore()
  local valid,why=api.decode(state.picks,'player')
  if not valid then state.picks={false,false};state.selected=1;return s:refuseMenu(why)end
  state.mine=state.picks;proxy:send{type='room_double_turn',turn=state.turn,actions=state.mine};s.phase='link-wait';resolve()
 end
 screen.update=function(s,dt)
  if proxy.closed then api.restore()end
  originalUpdate(s,dt)
  if s.phase=='menu' or s.phase=='moves' then
   local slots=api.slots();if slots[state.selected] then api.select(slots[state.selected])end
  end
  local inbox=proxy.inbox
  while #inbox>0 do
   local msg=table.remove(inbox,1);local n=msg.turn
   if type(n)~='number'or n%1~=0 or n<1 or n>state.turn then fail('Invalid double turn sequence.');break end
   if msg.type=='room_double_turn'then
    if n==state.turn and not state.remote then state.remote=msg.actions;resolve()end
   elseif msg.type=='room_double_hash'and type(msg.hash)=='string'and #msg.hash<=128 then
    state.peerHashes[n]=msg.hash;verify(n)
   end
  end
 end
 screen.doubleRoom=state
 return true
end
return M
