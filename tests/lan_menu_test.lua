local hooks={};local calls={};local hosts={{name='ASH',address='192.168.1.4:7777'}}
local S={chat={},peers={},scanLan=function()calls.scan=true;return true end,
 localGames=function()return hosts end,stopScan=function()calls.stop=true end,
 hostLan=function()calls.host=true;return true end,joinLan=function(a)calls.join=a;return true end}
local mod={world={game={input={}}},events={on=function()end},hooks={wrap=function(_,k,f)hooks[k]=f end}}
local UI=dofile('lib/crossgen/ui.lua')(mod,S,{generation=3})
local function key(k)hooks['input.key'](function()end,{}, {phase='pressed',key=k})end
UI.show();key('return');assert(calls.host,'Host Local is not first/default action')
UI.show();key('down');key('return');assert(UI.mode=='join-list'and calls.scan)
key('return');assert(calls.join=='192.168.1.4:7777'and not UI.open)
UI.show('join-list');hosts={};key('return');assert(UI.mode=='join-lan','empty scan should offer direct address')
UI.textinput('example.net:7777');key('return');assert(calls.join=='example.net:7777')
print('PASS one-action hosting, automatic join scan, selected host and direct-address flow')
