-- Live Crystal trade UI over the engine's generation-aware trade protocol.
-- Save through Game2's normal writer; launcher/offline slot writers are never
-- used against a running save. Native trade/evolution screens own their art.
return function(game,net,peerName,onDone)
  local Trade=require('src.online.Trade')
  local Protocol=require('src.link.Protocol')
  local Chrome=require('src.ui.gen2.Chrome')
  local Runtime=require('src.mods.Runtime')
  local Screens=require('src.ui.Screens')
  local Evolution=require('src.core.gen2.Evolution')
  local handle={generation=2,data=game.data,save=game.save,party=game.save.party}
  local remote,why=Trade.remote(handle,net,{strict=true,peerName=peerName})
  if not remote then return nil,why end
  local screen={game=game,remote=remote,index=1,isOpaque=true,screenId='OnlineCrystalTrade',phase='select'}
  local finished,committed=false,false
  function screen:finish(result)
    if finished then return end
    finished=true
    if game.stack:top()==self then game.stack:pop()end
    onDone(result)
  end
  local function name(mon)
    local def=mon and game.data.pokemon[mon.species]
    return mon and (mon.nickname or def and def.name or mon.species)or '?'
  end
  function screen:pick(index)
    local ok,err=remote:pick(index)
    if not ok then self.error=err end
    return ok,err
  end
  function screen:confirm()
    local t=remote.session;local incoming=t.theirParty and t.theirParty[t.theirPick]
    if not incoming or incoming.isEgg or Trade.holdsMail({generation=2,party={incoming}},1)then
      self.error='Cannot trade this Pokemon';return false,self.error
    end
    -- Both players explicitly confirm the offered species before either swap.
    -- Save the original party before signalling readiness to the other game.
    if game:writeSave()==false then self.error='Could not save';return false,self.error end
    remote:confirm(true);return true
  end
  function screen:commit()
    if committed then return end
    local t=remote.session;local index=t.myPick
    local incoming=t.theirParty and t.theirParty[t.theirPick]
    local received,err=Protocol.unpackMon2(game.data,Protocol.packMon2(incoming),{strict=true})
    if not received then return self:finish(err or 'invalid received Pokemon')end
    local given=game.save.party[index]
    committed=true;self.phase='animating';received.traded=true
    Runtime.emit('pokemon.received',{mon=received,from='link',peerName=peerName})
    game.save.party[index]=received
    local dex=game.save.pokedex or {};game.save.pokedex=dex
    dex.seen=dex.seen or {};dex.caught=dex.caught or {}
    dex.seen[received.species]=true;dex.caught[received.species]=true
    game:writeSave()
    local entry,consume=Evolution.checkMon(game.data,received,{link=true})
    Runtime.emit('trade.completed',{sent=given,received=received,evolveTo=entry and entry.into})
    Screens.push(game,'Gen2TradeAnim',{given=given,received=received,save=game.save,onDone=function()
      game.stack:pop()
      if not entry then self:finish('trade complete');return end
      Screens.push(game,'Gen2EvolutionAnim',{mon=received,entry=entry,index=index,
        party=game.save.party,save=game.save,force=true,onDone=function()
          game.stack:pop()
          if consume then game.save.party[index].item=nil end
          game:writeSave();self:finish('trade complete')
        end})
    end})
  end
  function screen:update()
    if finished or committed then return end
    local stage=remote:update();local t=remote.session
    if stage=='cancelled'then return self:finish(t.error or 'trade cancelled')end
    if stage=='done'then return self:commit()end
    local input=game.input
    if input:wasPressed('b')and t.myConfirm~=true then
      net:send{type='bye'};return self:finish('trade cancelled')
    end
    if stage=='picking'then
      if input:wasPressed('up')then self.index=(self.index-2)%#handle.party+1 end
      if input:wasPressed('down')then self.index=self.index%#handle.party+1 end
      if input:wasPressed('a')then self:pick(self.index)end
    elseif stage=='confirming'and not t.myConfirm and input:wasPressed('a')then self:confirm()end
  end
  function screen:draw()
    love.graphics.setColor(1,1,1,1);love.graphics.rectangle('fill',0,0,160,144)
    Chrome.box(0,0,20,18);Chrome.print('LINK TRADE',2,1)
    local t=remote.session
    if t.stage=='picking'then
      for i,mon in ipairs(handle.party)do
        Chrome.print(name(mon):sub(1,10),3,3+(i-1)*2)
        Chrome.print('L'..tostring(mon.level),14,3+(i-1)*2)
      end
      Chrome.cursor(1,3+(self.index-1)*2)
      Chrome.print(self.error and self.error:sub(1,18)or'A:SELECT  B:CANCEL',1,16)
    elseif t.stage=='confirming'then
      Chrome.print('GIVE '..name(handle.party[t.myPick]):sub(1,11),1,4)
      Chrome.print('FOR '..name(t.theirParty[t.theirPick]):sub(1,12),1,7)
      Chrome.print(self.error and self.error:sub(1,18)or(t.myConfirm and 'Waiting...'or'A:TRADE   B:CANCEL'),1,12)
    else Chrome.print('Waiting for',2,6);Chrome.print((peerName or 'TRAINER'):sub(1,14),2,8)end
  end
  remote:start()
  return screen
end
