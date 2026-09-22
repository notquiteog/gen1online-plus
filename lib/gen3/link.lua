-- Native FRLG battle/trade protocol over the persistent room's virtual link.
-- Gen3Link performs its normal version/fingerprint handshake on both endpoints.
return function(mod,adapter)
  local Link=require('src.core.game3.link')
  local LB=require('src.core.game3.link.battle')
  local LT=require('src.core.game3.link.trade')
  local current
  function adapter.capabilities()
    local found=mod.find and mod.find('double_battles')
    local api=found and found.exports and found.exports.online
    return {single=true,trade=true,double=api and api.generation==3 and api.supportsDouble()or false}
  end
  function adapter.startActivity(mode,transport,host,onDone)
    if current then return false,'Native link already active' end
    local game=mod.world.game
    local kind=mode=='trade' and 0x1111 or mode=='double' and 0x2244 or 0x2233
    if mode~='trade'then
      local ok,why=LB.validateParty(game.session,mode=='double' and Link.USING.DOUBLE_BATTLE or Link.USING.SINGLE_BATTLE)
      if not ok then return false,why end
    elseif not game.session.party or #game.session.party==0 then return false,'No Pokemon to trade' end
    LB.reset();LT.reset()
    current={mode=mode,host=host,done=onDone,elapsed=0}
    local link,why=Link.open{transport=transport,role=host and 'host'or'guest',linkType=kind,game=game}
    if not link then current=nil;return false,why end
    current.link=link;return true
  end
  local function fail(why)
    local c=current;if not c or c.finished then return end
    c.finished=true
    if c.savedParty then
      local ctx,adapters=Link.vmCtx();Link.callSpecial(ctx,adapters,0x28);Link.savePlayerBag();c.savedParty=false
    end
    c.done(why or 'link failed')
  end
  function adapter.updateActivity(dt)
    local c=current;if not c or c.finished then return end
    c.elapsed=c.elapsed+dt
    if not c.link:isOpen()then fail('link closed');return end
    if not c.prepared and c.link:isReady()then
      c.prepared=true
      if c.mode=='trade'then
        LT.startMenu{onDone=function(result)c.finished=true;c.done(result);if c.disconnected then adapter.closeActivity()end end}
      else
        LB.mode=c.mode=='double' and Link.USING.DOUBLE_BATTLE or Link.USING.SINGLE_BATTLE
        LB.unionRoom=false;LB.state='setup';LB.seed=c.host and LB.dealSeed()or nil
        local ctx,adapters=Link.vmCtx()
        -- Preserve the actual party before healing for a fair link match.
        Link.callSpecial(ctx,adapters,0x27);c.savedParty=true
        Link.loadPlayerBag();Link.callSpecial(ctx,adapters,0x00)
        if c.host then LB.sendSetup();c.sent=true end
      end
    end
    if c.prepared and c.mode~='trade' and not c.started then
      c.setup=c.setup or c.link:take(LB.MSG.SETUP)
      if c.setup and c.setup.mode~=LB.mode then fail('battle mode mismatch');return end
      if c.setup and not c.host and not c.sent then
        LB.seed=tonumber(c.setup.seed)
        if not LB.seed then fail('missing battle seed');return end
        LB.sendSetup();c.sent=true
      end
      if c.setup and c.sent then
        c.started=true
        local ok,why=LB.beginBattle(c.setup,function(result)c.savedParty=false;c.finished=true;c.done(result)end)
        if not ok then fail(why)end
      end
    end
    if not c.prepared and c.elapsed>15 or c.mode~='trade' and not c.started and c.elapsed>30 then fail('link setup timed out')end
  end
  function adapter.closeActivity()
    require('src.ui.game3.link_trade_menu').close()
    Link.closeLink('activity complete');LB.reset();LT.reset();current=nil
  end
  function adapter.abortActivity()
    if not current then return end
    if current.mode=='trade' and not LT.abort('disconnected')then current.disconnected=true;return end
    local Battle=require('src.core.game3.battle')
    if Battle.isActive()then Battle.abort('draw')end
    fail('disconnected');adapter.closeActivity()
  end
end
