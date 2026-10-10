-- Native GB consent state machine with Gen2 records, operating on the live
-- game. The launcher's offline SaveHandle writer must never own this trade.
local Protocol=require('src.link.Protocol')
local Wire=require('src.link.Wire')
local M={}
function M.new(data,party,net,host,peerName)
 local t=Protocol.TradeSession.new(data,party,{strict=true,peerName=peerName})
 local R={session=t};local sent,received,digest,phase
 local function cancel(why)
  if phase~='cancelled'and not net.closed then net:send{type='bye'}end
  phase='cancelled';t.error=why;return phase
 end
 local function barrier()
  if phase or t.stage~='done'then return end
  local a,b=sent and sent[t:wireIndex(t.myPick)],received and received[t.theirPick]
  if not a or not b then return cancel('Invalid offered Pokemon')end
  digest=host and Protocol.tradeDigest(a,b)or Protocol.tradeDigest(b,a)
  phase='commit_wait';net:send{type='trade_confirm',digest=digest}
 end
 function R:start()
  local msg={type='party',mons=Protocol.packParty2(party)}
  local clean=Wire.sanitize(msg);sent=clean and clean.mons
  if not sent then return cancel('Invalid local party')end
  net:send(msg)
 end
 function R:pick(index)
  if t.stage~='picking'or type(index)~='number'or index%1~=0 or not party[index]then return false,'Invalid selection'end
  net:send(t:pick(index));return true
 end
 function R:confirm(yes)
  if t.stage~='confirming'or t.myConfirm~=nil then return false end
  net:send(t:confirm(yes==true));barrier();return true
 end
 function R:update()
  if phase=='done'or phase=='cancelled'then return phase end
  net:update()
  for _,msg in ipairs(net:poll()or{})do
   if msg.type=='bye'then return cancel('Disconnected')
   elseif msg.type=='trade_commit'and phase=='commit_wait'then
    local d=msg.digests
    if not(type(d)=='table'and d[1]==digest and d[2]==digest)then return cancel('Trade confirmation mismatch')end
    phase='done'
   elseif msg.type=='trade_abort'then return cancel('Trade confirmation refused')
   elseif not phase then
    if msg.type=='party'and t.stage=='waitParty'then
     if type(msg.mons)~='table'or #msg.mons<1 or #msg.mons>6 then return cancel('Invalid remote party')end
     t.theirParty={};received=msg.mons
     for _,packed in ipairs(received)do
      local mon,why=Protocol.unpackMon2(data,packed,{strict=true})
      if not mon then return cancel(why or'Invalid remote Pokemon')end
      t.theirParty[#t.theirParty+1]=mon
     end
     t.stage='picking'
    elseif msg.type~='party'and msg.type~='records'then
     local reply=t:handle(msg);if reply then net:send(reply)end
    end
   end
  end
  barrier()
  if phase~='done'and net.closed then return cancel('Disconnected')end
  return phase or t.stage
 end
 return R
end
return M
