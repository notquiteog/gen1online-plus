local M=dofile('lib/crossgen/discovery.lua')
local sockets={};local port=30000
local socket={udp=function()
 local s={queue={},sent={}};sockets[#sockets+1]=s
 function s:settimeout()end;function s:setoption()end
 function s:setsockname(_,p)port=port+1;self.port=p==0 and port or p;return true end
 function s:sendto(data,ip,p)
  self.sent[#self.sent+1]={data,ip,p}
  for _,other in ipairs(sockets)do if not other.closed and other.port==p then other.queue[#other.queue+1]={data,'192.168.1.2',self.port}end end
  return #data
 end
 function s:receivefrom()local q=table.remove(self.queue,1);if q then return unpack(q)end end
 function s:close()self.closed=true end
 return s
end}
local host=M.new('crystal',2,socket);assert(host.host(7777,'ASH'))
local client=M.new('crystal',2,socket);assert(client.scan())
client.update(.1);host.update(.1,true);client.update(.1)
assert(#client.list()==1 and client.list()[1].address=='192.168.1.2:7777')
local wrong=M.new('gold',2,socket);wrong.scan();wrong.update(.1);host.update(.1,true);wrong.update(.1);assert(#wrong.list()==0)
for _=1,8 do client.update(1);host.update(1,false)end
assert(#client.list()==0,'busy or departed host did not expire')
client.stop();assert(#client.list()==0);host.stop();wrong.stop()
for _,s in ipairs(sockets)do assert(s.closed)end
print('PASS compatible LAN discovery, deduplication, occupied-host expiry and socket cleanup')
