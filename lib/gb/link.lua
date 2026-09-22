-- Gen 1's native link state supports adopting a paired transport, retaining
-- the engine handshake, lockstep battle and transactional trade implementation.
return function(mod,adapter)
  if adapter.generation~=1 then return end
  local LinkState=require('src.link.LinkState')
  local current
  function adapter.capabilities()return {single=true,trade=true}end
  function adapter.startActivity(mode,transport,host,onDone)
    if current then return false,'Native link already active'end
    local game=mod.world.game
    if not(game.save and game.save.party and #game.save.party>0)then return false,'No Pokemon in party'end
    if mode~='single'and mode~='trade'then return false,'Unsupported link mode'end
    local state=LinkState.newFromSession(game,transport,mode=='single'and'battle'or'trade',host)
    local originalExit=state.exitWith
    current={state=state,done=false}
    local context=current
    function state:exitWith(message,reason)
      if context.done then return end
      context.done=true
      originalExit(self,message,reason)
      onDone(reason or (message and 'error' or 'finished'))
      if context.disconnected and current==context then current=nil end
    end
    if mode=='trade'then
      -- A room invitation covers one completed trade. This callback runs only
      -- after the native swap, save, animation and any trade evolution finish.
      function state:beginRound()self:exitWith(nil,'trade complete')end
    end
    game.stack:push(state)
    return true
  end
  function adapter.closeActivity()current=nil end
  function adapter.abortActivity()
    local c=current;if not c or c.done then current=nil;return end
    c.disconnected=true
    local game=mod.world.game
    -- Let the native battle/trade state process its closed virtual transport;
    -- it owns party restoration and stack unwind, including a trade animation.
    if c.state.net then c.state.net:close()end
  end
end
