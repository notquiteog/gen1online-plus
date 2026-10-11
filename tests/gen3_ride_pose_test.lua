-- Native composite graphics remain authoritative; optional pose metadata must
-- track mount mode without requiring Ride or altering another player's state.
local adapter
local game={phase='field',session={playerName='TEST'}}
local ride
package.loaded['src.core.GameVersion']={get=function()return 'leafgreen'end}
package.loaded['src.core.game3.player']={cellX=1,cellY=2,px=16,py=32,facing='down',spriteYOffset=-4}
package.loaded['src.core.game3.map']={current='FR_ROUTE_19'}
package.loaded['src.core.game3.objects']={forDraw=function()return{}end}
package.loaded['src.core.game3.ow_sprites']={playerGraphicsId=function()return 999 end,getDraw=function()end}
package.loaded['src.core.game3.pokemon']={keyName=function(s)if s==131 then return 'LAPRAS'end end}
package.loaded['src.mods.Gen3Compat']={worldBusy=function()return false end}
_G.captureAdapter=function(a)adapter=a end
local mod={world={game=game},exports={},log={info=function()end},find=function()return ride end}
function mod:read(path)
 if path=='lib/crossgen/session.lua' then return 'return function(mod,load,a) captureAdapter(a); return {} end'end
 return 'return function() end'
end
dofile('lib/gen3/init.lua')(mod)
assert(adapter.position().ride==nil,'standalone requires no Ride')
local pose={mounted=true,mode='surf',species=131,height=4,scale=1.25,showRider=false}
ride={exports={gen3Pose=function()return pose end,isFlying=function()return false end}}
local p=adapter.position();assert(p.ride.mode=='surf' and p.ride.species=='LAPRAS' and p.ride.mountScale==1.25 and p.ride.showRider==false and p.graphics==999)
for _,mode in ipairs({'ground','fly'})do pose.mode=mode;assert(adapter.position().ride.mode==mode)end
pose.mounted=false;assert(adapter.position().ride==nil)
pose.mounted=true;pose.species=9999;assert(adapter.position().ride==nil)
ride={exports={}};assert(adapter.position().ride==nil,'older Ride fallback')
game.phase='battle';assert(adapter.position()==nil)
print('PASS Gen3 optional ride pose, modes, dismount, invalid species and native graphics')
