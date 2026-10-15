-- Connection lifecycle now preserves the listener on each guest departure.
local sockets,cleanups={},0
package.loaded['src.link.Net']={defaultPort=function()return 7777 end}
love={math={random=function()return 123 end}}
local function localModule(path)
 if path=='lib/crossgen/host_address.lua'then return dofile(path)end
 if path:find('room_transport',1,true)then return{new=function()
  local n={inbox={}};sockets[#sockets+1]=n
  function n:host(port)self.port=port;self.address='127.0.0.1:'..port;return true end
  function n:update()end;function n:send()return true end
  function n:poll()local q=self.inbox;self.inbox={};return q end
  function n:close()self.closed=true end
  function n:kick(id)self.inbox[#self.inbox+1]={event='disconnect',peer=id};return true end
  return n end}end
 if path:find('discovery',1,true)then return{new=function()return{stop=function()end,host=function()return true end,update=function()end}end}end
 if path:find('shared_world',1,true)then return{new=function()return{maps={},handle=function()end,update=function()end,disconnect=function()end}end}end
 if path:find('sky_session',1,true)then return function()return{clear=function()end,update=function()end,available=function()return false end,handle=function()end}end end
 if path:find('activities',1,true)then return function()return{disconnect=function()cleanups=cleanups+1 end,peerDisconnected=function()end,update=function()end,handle=function()end}end end
 error(path)
end
local S=dofile('lib/crossgen/session.lua')({hooks={wrap=function()end}},localModule,{generation=1,game='red',position=function()end})
local function connect(id)
 local n=sockets[#sockets];n.inbox={{event='message',peer=id,message={type='world_hello',protocol=2,generation=1,game='red',host=false}}};S.update(.1)
end
assert(S.hostLan(7778)and S.connected);connect('p1');connect('p2');assert(#S.roster()==2)
assert(S.kick('p1'));S.update(.1);assert(S.connected and #S.roster()==1 and #sockets==1)
connect('p3');assert(#S.roster()==2,'replacement guest handshake rejected')
sockets[1].inbox={{event='disconnect',peer='p2'},{event='disconnect',peer='p3'}};S.update(.1);assert(S.connected and #S.roster()==0 and #sockets==1)
S.disconnect();local count=#sockets;S.update(.1);assert(#sockets==count and not S.connected,'explicit disconnect restarted host')
assert(not S.hostLan(0));assert(S.hostLan(7778));sockets[#sockets].error='listen failure';count=#sockets;S.update(.1);S.update(.1)
assert(#sockets==count and not S.connected,'failed listener retry loop')
print('PASS persistent LAN listener, targeted kick, rejoin, explicit stop and failed-listener limits')
