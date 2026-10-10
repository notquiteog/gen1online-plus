local sockets,stops,hosts,cleanups={},0,0,0
local failBind=false
package.loaded['src.link.Net']={defaultPort=function()return 7777 end,new=function()
 local n={inbox={}};sockets[#sockets+1]=n
 function n:host(port)self.port=port;self.address='127.0.0.1:'..port;if failBind then self.error='bind failed';return false end;return true end
 function n:update()end;function n:send()return true end
 function n:poll()local q=self.inbox;self.inbox={};return q end
 function n:close()self.closed=true end
 return n
end}
love={math={random=function()return 123 end}}
local function localModule(path)
 if path:find('discovery',1,true)then return{new=function()return{
  stop=function()stops=stops+1 end,host=function()hosts=hosts+1;return true end,update=function()end}end}end
 if path:find('shared_world',1,true)then return{new=function()return{maps={},handle=function()end,update=function()end,disconnect=function()end}end}end
 if path:find('sky_session',1,true)then return function()return{clear=function()end,update=function()end,available=function()return false end,handle=function()end}end end
 if path:find('activities',1,true)then return function()return{disconnect=function()cleanups=cleanups+1 end,update=function()end,handle=function()end}end end
 error(path)
end
local S=dofile('lib/crossgen/session.lua')({hooks={wrap=function()end}},localModule,{generation=1,game='red',position=function()end})
local function connect()
 local n=sockets[#sockets];n.paired=true;n.inbox={{type='world_hello',protocol=1,generation=1,game='red',host=false}}
 S.update(.1);assert(S.connected)
end
assert(S.hostLan(7778));connect();local old=sockets[#sockets];old.closed=true;local before=cleanups
S.update(.1);assert(#sockets==2 and sockets[2].port==7778 and hosts==2)
assert(not S.connected and S.host and S.status=='Waiting for player' and cleanups>before)
connect();assert(S.connected,'replacement guest handshake rejected')
S.disconnect();local count=#sockets;S.update(.1);assert(#sockets==count,'explicit disconnect restarted host')
assert(S.hostLan(7778));connect();failBind=true;sockets[#sockets].closed=true
S.update(.1);count=#sockets;S.update(.1);S.update(.1)
assert(#sockets==count and not S.connected,'failed bind retry loop')
failBind=false;assert(S.hostLan(7778));sockets[#sockets].error='listen failure';count=#sockets;S.update(.1)
assert(#sockets==count,'unestablished listener restarted')
print('PASS LAN rejoin, activity cleanup, explicit stop and failed-listener limits')
