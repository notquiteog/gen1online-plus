-- FireRed uses its native object renderer and native link battle/trade seams.
-- No dependency on Wilds, Battle Art, Double Battles or Dramatic Ride.
return function(mod)
  local function loadLocal(path)
    return assert((loadstring or load)(assert(mod:read(path)), '@online/'..path))()
  end
  local Player=require('src.core.game3.player')
  local Map=require('src.core.game3.map')
  local Objects=require('src.core.game3.objects')
  local Sprites=require('src.core.game3.ow_sprites')
  local Compat=require('src.mods.Gen3Compat')
  local adapter={generation=3,game=require('src.core.GameVersion').get()}
  local remote
  local function game()return mod.world.game end
  function adapter.position()
    local g=game()
    if not g or g.phase~='field' or not Map.current then return end
    local session=g.session or {}
    return {map=Map.current,x=Player.cellX,y=Player.cellY,px=Player.px,py=Player.py,
      facing=Player.facing,moving=Player.moving,busy=adapter.menuBusy or Compat.worldBusy(),
      graphics=Sprites.playerGraphicsId(g),name=session.playerName or session.name or 'TRAINER'}
  end
  function adapter.peer(p)
    if not remote or remote.map~=p.map then
      remote={localId=820000,animClock=0,stepFrames=16,stepFlip=false,px=p.px,py=p.py,def={elevation=0},visible=true,passable=true}
    end
    remote.map=p.map;remote.cellX=p.x;remote.cellY=p.y;remote.targetPx=p.px;remote.targetPy=p.py
    remote.facing=p.facing;remote.moving=p.moving
    -- Only a native imported sprite id may be rendered; never a peer path.
    local id=tonumber(p.graphics)
    remote.graphicsId=(id and id>=0 and id<1024 and Sprites.getDraw(id)) and id or Sprites.playerGraphicsId(game())
  end
  function adapter.clearPeers()remote=nil end
  function adapter.update(dt)
    if not remote then return end
    remote.px=remote.px+(remote.targetPx-remote.px)*math.min(1,dt*15)
    remote.py=remote.py+(remote.targetPy-remote.py)*math.min(1,dt*15)
    remote.animClock=(remote.animClock or 0)+dt*60
  end
  local forDraw=Objects.forDraw
  Objects.forDraw=function(...)
    local rows=forDraw(...)
    if remote and remote.map==Map.current then rows[#rows+1]=remote end
    return rows
  end
  loadLocal('lib/gen3/link.lua')(mod,adapter)
  local session=loadLocal('lib/crossgen/session.lua')(mod,loadLocal,adapter)
  loadLocal('lib/crossgen/ui.lua')(mod,session,adapter)
  mod.exports.multiplayer=session
  mod.exports.netNpcs=function()return remote and {remote}or{}end
  mod.log:info('Native FireRed online world adapter loaded')
end
