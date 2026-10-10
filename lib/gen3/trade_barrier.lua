-- The persistent room carries a native link over a virtual channel, so the
-- external relay cannot see its trade confirmations. Coordinate that channel
-- only: both native transaction digests must agree before either side commits.
local M={}
function M.wrap(transport,host)
 if not host then return transport end
 local send,poll=assert(transport.send),assert(transport.poll)
 local own,peer,decided,committed,queued,round=nil,nil,false,false,{},0
 local function valid(d)return type(d)=='string'and #d==16 and not d:find('[^0-9a-f]')end
 local function decide()
  if decided or not own or not peer or transport.closed then return end
  decided=true;committed=own==peer;round=round+1
  local result=own==peer and {type='trade_commit',n=round,digests={own,peer}}
    or {type='trade_abort',n=round,why='digest'}
  -- Deliver the same decision locally and remotely; native LT.onCommit still
  -- validates both hashes and applies the native plan/evolution/save sequence.
  if send(transport,result)~=false then queued[#queued+1]=result end
 end
 local function observe(msg,localSender)
  if type(msg)~='table'or committed then return end
  -- The native UI may retry a refused/cancelled exchange within this activity.
  -- A new locally selected MON starts its next digest pair, never a replayed
  -- confirmation; successful commits remain sealed until channel teardown.
  if localSender and msg.type=='game3_trade_mon'then own,peer,decided=nil,nil,false;return end
  if not decided and msg.type=='game3_trade_cmd'and
    (msg.cmd==0xDDEE or msg.cmd==0xEEAA or msg.cmd==0xEEBB or msg.cmd==0xEECC or msg.cmd==0xBBCC)then
   own,peer=nil,nil;return
  end
  if decided then return end
  if msg.type=='game3_trade_confirm'and valid(msg.digest)then
   if localSender then own=msg.digest else peer=msg.digest end
   decide()
  end
 end
 function transport:send(msg)
  local sent=send(self,msg)
  if sent~=false then observe(msg,true)end
  return sent
 end
 function transport:poll()
  local out={}
  for _,msg in ipairs(poll(self)or{})do
   -- Guests cannot impersonate the coordinator of this host-owned channel.
   if msg.type~='trade_commit'and msg.type~='trade_abort'then
    out[#out+1]=msg;observe(msg,false)
   end
  end
  for _,msg in ipairs(queued)do out[#out+1]=msg end;queued={}
  return out
 end
 return transport
end
return M
