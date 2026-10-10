for _,name in ipairs{'src.online.Trade','src.link.Protocol','src.ui.gen2.Chrome','src.mods.Runtime','src.ui.Screens','src.core.gen2.Evolution'}do package.loaded[name]={}end
local remote={session={},start=function()end}
local Factory={new=function()return remote end}
local world={};local states={world};local called=0
local stack={top=function()return states[#states]end,pop=function()return table.remove(states)end}
local game={data={},save={party={}},stack=stack}
local screen=assert(dofile('lib/gen2/trade.lua')(game,{},'PEER',function()called=called+1 end,Factory,true))
states[#states+1]=screen;local native={};states[#states+1]=native
screen:finish('done');assert(called==1 and stack:top()==native,'finish stole native screen')
stack:pop();screen:update();assert(stack:top()==world,'finished trade stranded above world')
screen:finish('again');assert(called==1,'duplicate completion')
print('PASS trade callback preserves covering native screen and removes own state when uncovered')
