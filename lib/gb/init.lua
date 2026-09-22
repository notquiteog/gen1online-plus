-- Gen 1/2 adapter for the same persistent host-authoritative room protocol.
return function(mod)
  local function loadLocal(path)return assert((loadstring or load)(assert(mod:read(path)),'@online/'..path))()end
  local GV=require('src.core.GameVersion')
  local adapter={generation=GV.generation(),game=GV.get()}
  local remote,attached
  local function game()return mod.world.game end
  local function world()local g=game();return g and (g.world or g.overworld)end
  local function detach()
    if attached and remote then
      for _,list in ipairs({attached.npcs or {},attached.entities or {}})do
        for i=#list,1,-1 do if list[i]==remote then table.remove(list,i)end end
      end
    end
    attached=nil
  end
  function adapter.position()
    local g,w=game(),world();local p=w and w.player
    if not g or not p or not w.map then return end
    local top=g.stack and g.stack:top()
    return {map=w.map.id,x=p.cellX,y=p.cellY,px=p.px,py=p.py,facing=p.facing,
      moving=p.moving,busy=adapter.menuBusy or (top~=nil and top~=w)
        or (w.busy and w:busy())or w.battleActive==true,
      name=g.save and g.save.player and g.save.player.name or 'TRAINER'}
  end
  function adapter.clearPeers()detach();remote=nil end
  function adapter.peer(p)
    if not remote or remote.map~=p.map then
      detach()
      remote={id='gen1online_room_peer',name='ONLINE TRAINER',map=p.map,
        px=p.px,py=p.py,passable=true,visible=true,netPeer=true,def={index=820000,sprite='SPRITE_RED',movement='STAY',x=p.x,y=p.y}}
      function remote:update()end -- Only the network snapshot owns this pose.
      function remote:pose()
        local w=world();local sprite=w and w.player and w.player.sprite
        return sprite,self.px,self.py,self.facing,self.moving and (math.floor(self.clock/8)%2)or 0,false
      end
      function remote:draw(camX,camY,scale)
        local sprite,x,y,facing,phase,flip=self:pose()
        if sprite and sprite.draw then
          if adapter.generation==2 and scale then
            love.graphics.push();love.graphics.translate(camX or 0,camY or 0);love.graphics.scale(scale,scale)
            sprite:draw(x,y,0,0,facing,phase,flip);love.graphics.pop()
          else sprite:draw(x,y,camX,camY,facing,phase,flip)end
        end
      end
    end
    remote.cellX,remote.cellY=p.x,p.y;remote.targetPx,remote.targetPy=p.px,p.py
    remote.facing=p.facing;remote.moving=p.moving;remote.clock=remote.clock or 0
  end
  function adapter.update(dt)
    if not remote then return end
    local w=world()
    if attached~=w or not w or not w.map or w.map.id~=remote.map then detach()end
    if w and w.map and w.map.id==remote.map then
      for _,key in ipairs({'npcs','entities'})do
        w[key]=w[key]or{};local found=false
        for _,e in ipairs(w[key])do if e==remote then found=true;break end end
        if not found then table.insert(w[key],remote)end
      end
      attached=w
    end
    remote.px=remote.px+(remote.targetPx-remote.px)*math.min(1,dt*15)
    remote.py=remote.py+(remote.targetPy-remote.py)*math.min(1,dt*15)
    remote.clock=remote.clock+dt*60
  end
  loadLocal('lib/gb/link.lua')(mod,adapter)
  if adapter.generation==2 then loadLocal('lib/gen2/link.lua')(mod,adapter)end
  local session=loadLocal('lib/crossgen/session.lua')(mod,loadLocal,adapter)
  loadLocal('lib/crossgen/ui.lua')(mod,session,adapter)
  mod.exports.multiplayer=session
  return session
end
