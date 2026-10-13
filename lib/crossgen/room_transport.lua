-- ENet star transport: the host is the only relay and assigns connection IDs.
local Json=require('src.link.Json')
local Native=require('src.link.Net')
local T={MAX_PLAYERS=65,MAX_PACKET=262144,MAX_EVENTS=512}
function T.new()
 local self={closed=false,paired=false,peers={},inbox={},serial=0}
 local h,server,hosting;local byPeer={};local budgets={};local clock=0
 local function fail(why)self.error=tostring(why);return false,self.error end
 function self:host(port,limit)
  local ok,enet=pcall(require,'enet');if not ok then return fail('ENet unavailable')end
  limit=math.max(4,math.min(T.MAX_PLAYERS,math.floor(tonumber(limit)or T.MAX_PLAYERS)))
  local good,value=pcall(enet.host_create,'*:'..tostring(port),limit-1,1,0,0)
  if not good or not value then return fail(value or'Unable to bind room')end
  h=value;hosting=true;self.capacity=limit;self.mode='hosting';self.address=(Native.lanIP()or'127.0.0.1')..':'..port;return true
 end
 function self:join(address)
  local ok,enet=pcall(require,'enet');if not ok then return fail('ENet unavailable')end
  h=enet.host_create();if not h then return fail('Unable to create client')end
  if not address:match(':%d+$')then address=address..':'..Native.defaultPort()end
  server=h:connect(address,1);hosting=false;self.mode='joining';self.address=address;self.elapsed=0;return true
 end
 function self:hostOnline()return fail('Multi-player relay is not configured. Host a LAN/direct-address room.')end
 function self:joinOnline()return fail('Multi-player relay is not configured. Join by host address.')end
 function self:send(msg,target)
  if self.closed or not h then return false end
  local ok,data=pcall(Json.encode,msg);if not ok or #data>T.MAX_PACKET then return false end
  if hosting then
   if target then local p=self.peers[target];return p and pcall(p.send,p,data,0,'reliable')or false end
   for _,p in pairs(self.peers)do pcall(p.send,p,data,0,'reliable')end;return true
  end
  if server and self.paired then return pcall(server.send,server,data,0,'reliable')end
  return false
 end
 function self:kick(id)
  local p=self.peers[id];if not p then return false end
  self.peers[id]=nil;byPeer[p]=nil;budgets[id]=nil;pcall(p.disconnect_now,p)
  self.inbox[#self.inbox+1]={event='disconnect',peer=id};return true
 end
 function self:update(dt)
  if not h or self.closed then return end
  if not hosting and not self.paired then self.elapsed=(self.elapsed or 0)+(dt or .016);if self.elapsed>10 then return fail('Room connection timed out')end end
  clock=clock+(tonumber(dt)or .016)
  local counts={}
  for _=1,T.MAX_EVENTS do
   local ok,e=pcall(h.service,h,0);if not ok then return fail(e)end;if not e then break end
   if e.type=='connect'then
    local id='host';if hosting then self.serial=self.serial+1;id='p'..self.serial;self.peers[id]=e.peer;byPeer[e.peer]=id end
    self.paired=true;self.inbox[#self.inbox+1]={event='connect',peer=id}
   elseif e.type=='disconnect'then
    local id=hosting and byPeer[e.peer]or'host'
    if id then self.peers[id]=nil;byPeer[e.peer]=nil;budgets[id]=nil;self.inbox[#self.inbox+1]={event='disconnect',peer=id}end
    if not hosting then self.closed=true;self.error='Host disconnected'end
   elseif e.type=='receive'then
    local id=hosting and byPeer[e.peer]or(e.peer==server and'host')
    if id and type(e.data)=='string'and #e.data<=T.MAX_PACKET then
     counts[id]=(counts[id]or 0)+1
     local b=budgets[id];if not b or clock-b.start>=1 then b={start=clock,bytes=0,messages=0};budgets[id]=b end
     b.bytes=b.bytes+#e.data;b.messages=b.messages+1
     if counts[id]<=(hosting and 128 or 512) and b.bytes<=(hosting and 2097152 or 16777216) and b.messages<=(hosting and 512 or 8192) then
      local ok,msg=pcall(Json.decode,e.data,T.MAX_PACKET)
      if ok and type(msg)=='table'then self.inbox[#self.inbox+1]={event='message',peer=id,message=msg}end
     end
    end
   end
  end
 end
 function self:poll()local q=self.inbox;self.inbox={};return q end
 function self:close()
  if h then for _,p in pairs(self.peers)do pcall(p.disconnect_now,p)end;if server then pcall(server.disconnect_now,server)end;pcall(h.flush,h)end
  h=nil;self.closed=true;self.paired=false;self.peers={};self.inbox={}
 end
 return self
end
return T
