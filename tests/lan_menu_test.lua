package.preload['src.core.game3.field']=function()return {interact=function()end}end
local hooks={};local calls={};local hosts={{name='ASH',address='192.168.1.4:7777'}}
local S={chat={},peers={},scanLan=function()calls.scan=true;return true end,
 localGames=function()return hosts end,stopScan=function()calls.stop=true end,
 hostLan=function()calls.host=true;return true end,joinLan=function(a)calls.join=a;return true end}
local stored
local mod={storage={read=function()return {}end,write=function(_,k,v)stored=v end},world={game={input={isDown=function()return true end,wasPressed=function()return true end}}},events={on=function()end},hooks={wrap=function(_,k,f)hooks[k]=f end}}
local UI=dofile('lib/crossgen/ui.lua')(mod,S,{generation=3})
local function key(k)hooks['input.key'](function()end,{}, {phase='pressed',key=k})end
UI.show();key('return');assert(calls.host,'Host Local is not first/default action')
UI.show();key('down');key('return');assert(UI.mode=='join-list'and calls.scan)
key('return');assert(calls.join=='192.168.1.4:7777'and not UI.open)
UI.show('join-list');hosts={};key('return');assert(UI.mode=='join-lan','empty scan should offer direct address')
UI.textinput('example.net:7777');key('return');assert(calls.join=='example.net:7777')
print('PASS one-action hosting, automatic join scan, selected host and direct-address flow')

local function pad(button)
 local g=mod.world.game;g.input.pressQueue={button}
 hooks['input.step'](function()end,g,.016)
 assert(#g.input.pressQueue==0,'menu leaked input into game')
end
UI.show();pad('down');pad('a');assert(UI.mode=='join-list')
pad('a');assert(UI.mode=='join-lan');UI.textinput('server.example:7777');pad('select');assert(stored[1]=='server.example:7777')
pad('b');pad('down');pad('a');assert(UI.mode=='join-list');pad('a');assert(UI.mode=='server')
pad('a');assert(calls.join=='server.example:7777')
UI.show('join-list');pad('a');pad('down');pad('a');assert(#stored==0)
print('PASS mapped controller navigation, persistent server save/connect/remove')
S.host=true;S.connected=true;S.status='hosting';S.roster=function()return {{id='2',name='ASH'},{id='3',name='MISTY'}}end
S.selectPeer=function(id)S.selectedPeer=id;S.peers.remote={id=id,name='MISTY'};return true end
S.kick=function(id)calls.kicked=id;return true end
UI.show();pad('a');assert(UI.mode=='players');pad('down');pad('a');assert(UI.mode=='peer'and S.selectedPeer=='3')
pad('a');assert(calls.kicked=='3','host kicked the wrong guest')
print('PASS multiplayer roster selection and targeted kick')

UI.show();hooks['input.step'](function()end,mod.world.game,.016)
assert(not mod.world.game.input:isDown('up') and not mod.world.game.input:wasPressed('a'))
UI.close();assert(not mod.world.game.input:isDown('up'),'close-frame input leaked')
hooks['input.step'](function()end,mod.world.game,.016)
assert(mod.world.game.input:isDown('up'),'closed menu retained game input')
print('PASS held gameplay input blocked only during menu and close frame')
