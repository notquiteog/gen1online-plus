local captured
_G.captureAdapter=function(a)captured=a end
local sprite={draw=function()end}
for generation=1,3 do
 local w={map={id='town'},player={sprite=sprite,cellX=0,cellY=0,px=0,py=0,facing='down'},npcs={},entities={}}
 local g={phase='field',world=w,session={playerName='TEST'},save={player={name='TEST'}}}
 package.loaded['src.core.GameVersion']={get=function()return generation==3 and'leafgreen'or generation==2 and'crystal'or'yellow'end,generation=function()return generation end}
 package.loaded['src.core.game3.player']=w.player
 package.loaded['src.core.game3.map']={current='town'}
 local Objects={forDraw=function()return{}end};package.loaded['src.core.game3.objects']=Objects
 package.loaded['src.core.game3.ow_sprites']={playerGraphicsId=function()return 1 end,getDraw=function()return true end}
 package.loaded['src.mods.Gen3Compat']={worldBusy=function()return false end}
 local mod={game=g,exports={},log={info=function()end},events={on=function(_,_,f)f()end}}
 function mod:read(path)if path=='lib/crossgen/session.lua'then return'return function(m,l,a)captureAdapter(a);return{}end'end;return'return function()end'end
 dofile(generation==3 and'lib/gen3/init.lua'or'lib/gb/init.lua')(mod)
 local a=captured
 for i=1,3 do a.peer({map='town',x=i,y=0,px=i*16,py=0,facing='down',moving=true,graphics=1},'p'..i)end
 a.update(.1)
 local list=generation==3 and Objects.forDraw()or w.npcs
 assert(#list==3,'all three peers rendered gen'..generation)
 local ids={};for _,r in ipairs(list)do local id=r.localId or r.def.index;assert(not ids[id],'duplicate object id');ids[id]=true end
 a.removePeer('p2');a.update(.1);list=generation==3 and Objects.forDraw()or w.npcs;assert(#list==2,'targeted despawn')
 a.peer({map='route',x=1,y=1,px=16,py=16,facing='up',graphics=1},'p1');a.update(.1);list=generation==3 and Objects.forDraw()or w.npcs;assert(#list==1,'map isolation')
 a.clearPeers();a.update(.1);list=generation==3 and Objects.forDraw()or w.npcs;assert(#list==0,'cleanup')
end
print('PASS unique multi-peer entities, map visibility and individual cleanup across Gen1/2/3')
