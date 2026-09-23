-- Gen1 resolves queued actions over multiple presentation frames. Hash only
-- once that queue has drained; never acknowledge a pre-animation state.
local M={}
function M.attach(b,proxy,provider,host)
 local api,err=provider.attach(b);if not api then return false,err end
 local F=require('src.link.Fingerprint')
 local state={turn=1,verified=0,hashes={},peerHashes={}}
 local update,finish=b.update,b.finish
 local function fail(why)
  if state.failed then return end;state.failed=true;api.finish(why);proxy:send{type='bye'}
 end
 local function verify(n)
  if state.hashes[n]and state.peerHashes[n]then
   if state.hashes[n]~=state.peerHashes[n]then fail('Double battle state mismatch.')else state.verified=math.max(state.verified,n)end
  end
 end
 local function resolve()
  if state.failed or state.resolving or not state.mine or not state.remote then return end
  local ok,why=api.resolve(state.mine,state.remote)
  if not ok then fail(why);return end
  state.resolving=true
 end
 function b:__dbSubmit(a,c)
  if state.mine or state.resolving then return end
  local rows,why=api.encode(a,c)
  if not rows then self:say(why);self.phase='messages';self.afterQueue='menu';return end
  local valid,reason=api.decode(rows,'player')
  if not valid then self:say(reason);self.phase='messages';self.afterQueue='menu';return end
  state.mine=rows;self.phase='waitRemote';proxy:send{type='room_double_turn',turn=state.turn,actions=rows};resolve()
 end
 local function completed()
  local n=state.turn;state.hashes[n]=F.digest(api.signature(host))
  proxy:send{type='room_double_hash',turn=n,hash=state.hashes[n]};verify(n)
  state.resolving=nil;state.mine=nil;state.remote=nil;state.turn=n+1
 end
 b.finish=function(self)
  if state.resolving then completed()end
  if not state.failed and not proxy.closed and state.verified<state.turn-1 then self.phase='waitRemote';state.finishPending=true;return end
  return finish(self)
 end
 b.tryRun=function()fail('Link battle ended by a trainer.')end
 b.update=function(self,dt)
  if proxy.closed and not self.result then fail('Peer disconnected.')end
  update(self,dt)
  if state.resolving and self.phase=='menu'then completed();self.phase='waitRemote';state.menuPending=true end
  while #proxy.inbox>0 do
   local msg=table.remove(proxy.inbox,1);local n=msg.turn
   if type(n)~='number'or n%1~=0 or n<1 or n>state.turn then fail('Invalid double turn sequence.');break end
   if msg.type=='room_double_turn'then
    if n==state.turn and not state.remote then state.remote=msg.actions;resolve()end
   elseif msg.type=='room_double_hash'and type(msg.hash)=='string'and #msg.hash<=128 then state.peerHashes[n]=msg.hash;verify(n)end
  end
  if state.finishPending and (state.failed or proxy.closed or state.verified>=state.turn-1)then state.finishPending=nil;self:finish()
  elseif state.menuPending and state.verified>=state.turn-1 then state.menuPending=nil;self.phase='menu'end
 end
 b.doubleRoom=state;return true
end
return M
