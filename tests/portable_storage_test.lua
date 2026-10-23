-- Saved servers use the live game/playthrough storage scope, after game.ready.
local hooks,events={},{};local first,second={input={}},{input={}};local buckets={[first]={'one.example'},[second]={'two.example'}}
local mod={game=first,events={on=function(_,k,f)events[k]=f end},hooks={wrap=function(_,k,f)hooks[k]=f end}}
mod.storage={read=function(_,g,key)assert(buckets[g]and key=='saved_servers','public storage scope omitted');return buckets[g]end,
write=function(_,g,key,value)assert(buckets[g]and key=='saved_servers');buckets[g]=value;return true end}
package.loaded['src.core.game3.field']={interact=function()end}
local session={scanLan=function()return true end,localGames=function()return{}end,peers={},chat={}}
local ui=dofile('lib/crossgen/ui.lua')(mod,session,{generation=3})
local function key(k)hooks['input.key'](function()end,mod.game,{phase='pressed',key=k})end
ui.show('join-list');key('return');assert(ui.mode=='server','first scoped saved server was not loaded')
mod.game=second;events['game.ready']{game=second};ui.show('join-list');key('return');assert(ui.mode=='server')
key('down');key('return');assert(#buckets[second]==0 and buckets[first][1]=='one.example','server removal crossed playthrough scope')
print('PASS public live-game storage contract, game.ready reload and isolated playthrough writes')

-- Legacy GTS uses the same current game scope for saves/account/address/chat.
local storage=dofile('lib/scoped_storage.lua')(mod)
local calls={};mod.storage={
 read=function(_,g,key)calls[#calls+1]={g,key};return buckets[g][key]end,
 write=function(_,g,key,value)buckets[g][key]=value;return true end,
 delete=function(_,g,key)buckets[g][key]=nil;return true end}
mod.game=first;assert(storage.write('gts_server_url','https://first.example'))
assert(storage.write('online_save.lua',{money=123}))
mod.game=second;assert(storage.read('gts_server_url')==nil)
assert(storage.write('gts_server_url','https://second.example'))
assert(storage.delete('online_save.lua.bak'))
mod.game=first;assert(storage.read('gts_server_url')=='https://first.example')
assert(storage.read('online_save').money==123 and calls[#calls][1]==first)
mod.storage.write=function()return nil,'invalid_game'end
assert(storage.write('online_account',{})==false,'refused storage write reported success')
mod.game=nil;local absent,why=storage.read('online_save');assert(absent==nil and why=='storage_unavailable')
print('PASS legacy GTS live-scope server/save/account persistence and refusal handling')
