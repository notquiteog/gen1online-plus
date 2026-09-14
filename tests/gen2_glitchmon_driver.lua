-- Run with a disposable profile and the real core.update hook dispatch.
-- Stock POKEPORT_DRIVER skips that hook; use PlatformHooks.update(Game,1/60)
-- in the driver's update branch of a disposable launcher, never a user build.
return function(game)
 local U=dofile((os.getenv('ENGINE_ROOT') or '.')..'/tests/drivers/util.lua')
 local Mon=require('src.battle.gen2.Mon')
 game.save.party={Mon.new(game.data,'CYNDAQUIL',5)}
 -- Keep story conversations from pausing this stationary spawn regression.
 game.world.trySceneScript=function()return false end
 local provider=assert(game.mods.exports.overworld_wild_spawns)
 assert(provider.supportsFeature('encounters'))
 for _,loc in ipairs({{'NEW_BARK_TOWN',7,5},{'CHERRYGROVE_CITY',21,11},{'VIOLET_CITY',10,10}}) do
  local id=loc[1]
  assert(game.world:setMap(id,loc[2],loc[3]))
  if not game.world.map:isWalkableCell(loc[2],loc[3]) then
    local map=game.world.map
    local bx,by,best=nil,nil,math.huge
    for y=1,map.heightCells-2 do for x=1,map.widthCells-2 do
      local d=math.abs(x-loc[2])+math.abs(y-loc[3])
      if d<best and map:isWalkableCell(x,y) and map:isWalkableCell(x,y+1)
          and map:isWalkableCell(x+1,y) and not game.world:npcAt(x,y) then bx,by,best=x,y,d end
    end end
    assert(bx,'no clear town fixture')
    assert(game.world:setMap(id,bx,by))
    print('[fixture]',id,bx,by)
  end
  game.stack:clear()
  local ambient=false
  for frame=1,360 do
   U.wait(1)
   local followers=0
   for _,e in ipairs(game.world.entities) do
    assert(not e.isWildMon,'Online+ created a duplicate offline encounter: '..tostring(e.species))
    if e.wildsAmbientPokemon then ambient=true end
    if e.pikachuFollower or e.pokepcTrailer then followers=followers+1 end
   end
   if frame>60 then assert(followers==1,'expected one local follower, got '..followers) end
  end
  assert(ambient,'town ambient Pokemon disappeared')
  print('[glitchmon]',id,'PASS: no duplicate wilds, one follower, ambient retained')
 end
 love.event.quit()
end
