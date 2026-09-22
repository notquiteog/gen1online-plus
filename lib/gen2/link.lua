-- Crystal's native LinkBattle2 handles turn hashes, held items, forced
-- replacements and mirrored RNG order. Keep its normal compatibility check.
return function(mod,adapter)
  local Session=require('src.link.Session')
  local Handshake=require('src.link.Handshake')
  local Protocol=require('src.link.Protocol')
  local LinkBattle=require('src.link.LinkBattle2')
  local TradeScreen=assert((loadstring or load)(assert(mod:read('lib/gen2/trade.lua')),'@online/gen2/trade'))()
  local Doubles=assert((loadstring or load)(assert(mod:read('lib/crossgen/double_link.lua')),'@online/double_link'))()
  local function provider()
    local m=mod.find and mod.find('double_battles');local p=m and m.exports and m.exports.online
    return p and p.protocol==1 and p.generation==2 and p.attach and p.supportsDouble() and p or nil
  end
  local current
  function adapter.capabilities()return {single=true,trade=true,double=provider()~=nil}end
  function adapter.startActivity(mode,transport,host,onDone)
    if current then return false,'Native link already active'end
    if mode~='single'and mode~='trade'and mode~='double'then return false,'Unsupported link mode'end
    if mode=='double'and not provider()then return false,'Double Battles is required for doubles.'end
    local game=mod.world.game
    if not(game.save and game.save.party and #game.save.party>0)then return false,'No Pokemon in party'end
    local net=Session.new(transport,{role=host and 'host'or'guest',kind='link'})
    local hello=Handshake.hello(game,mode=='trade'and'trade'or'battle')
    current={net=net,hello=hello,host=host,done=onDone,elapsed=0,mode=mode}
    net:send(hello);return true
  end
  local function finish(result)
    if not current or current.finished then return end
    local c=current;c.finished=true
    local game=mod.world.game
    game.linkSession=nil
    if game.linkNet==current.net then game.linkNet=nil end
    current.done(result)
    if c.disconnected and current==c then current=nil end
  end
  function adapter.updateActivity(dt)
    local c=current;if not c or c.finished or c.screen then return end
    c.elapsed=c.elapsed+dt;c.net:update()
    if c.net.closed then finish('disconnected');return end
    if not c.peer then
      c.peer=c.net:take('hello')
      if c.peer then
        c.verdict=Handshake.checkCompat(c.hello,c.peer)
        if not Handshake.battleAllowed(c.verdict)then finish('incompatible games or battle mods');return end
        local game=mod.world.game
        if c.mode=='trade'then
          local screen,why=TradeScreen(game,c.net,c.peer.name,finish)
          if not screen then finish(why or 'trade failed');return end
          c.screen=screen;game.linkSession=true;game.stack:push(screen);return
        end
        c.mine=Protocol.packParty2(game.save.party)
        c.seed=c.host and love.math.random(1,2^30)or nil
        c.net:send{type='room_party2',mons=c.mine,seed=c.seed}
      end
    end
    if c.peer then
      local packet=c.net:take('room_party2')
      if packet then
        if type(packet.mons)~='table'or #packet.mons<1 or #packet.mons>6 then finish('invalid party');return end
        local seed=c.host and c.seed or tonumber(packet.seed)
        if not seed or seed~=seed or seed<1 or seed>2^30 then finish('invalid seed');return end
        local game=mod.world.game
        local opts={myParty=c.mine,theirParty=packet.mons,theirName=c.peer.name,
          seed=seed,verdict=c.verdict,strict=Handshake.strict(c.verdict),keepNetOpen=true}
        local proxy=c.mode=='double'and Doubles.transport(c.net)or c.net
        local screen,why=(c.host and LinkBattle.newHost or LinkBattle.newGuest)(game,proxy,opts)
        if screen and c.mode=='double'then
          local ok,err=Doubles.attach(screen,proxy,provider(),c.host)
          if not ok then finish(err);return end
        end
        if not screen then finish(why or 'battle failed');return end
        c.screen=screen;screen.onFinish=finish;game.linkSession=true;game.stack:push(screen)
      end
    end
    if c.elapsed>20 and not c.screen then finish('link setup timed out')end
  end
  function adapter.closeActivity()
    if current then current.net:close()end
    current=nil
  end
  function adapter.abortActivity()
    if not current then return end
    current.disconnected=true
    current.net:close()
    if not current.screen then finish('disconnected');current=nil end
  end
end
