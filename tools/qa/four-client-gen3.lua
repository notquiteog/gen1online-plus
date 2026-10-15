-- Run four isolated *-qa processes with QA_ROLE=host/a/b/c and QA_MODE=single/double.
-- Requires Online; doubles additionally require Double Battles. Other mods remain optional.
-- Exercises real room invitations and native battle entry; no intro/turn bypass.
return function(game)
 assert(love.filesystem.getIdentity():match('%-qa$'))
 local U=dofile('tests/drivers/util.lua');local dir=assert(os.getenv('SHOT_DIR'))
 love.window.setMode(640,480,{vsync=0,msaa=0});game.options.animations=false;game.options.textSpeed='fast'
 love.joystick.getJoysticks=function()return{}end;love.joystick.getJoystickCount=function()return 0 end
 local role=os.getenv('QA_ROLE')or'host';local host=role=='host';local fighter=role=='a'or role=='b';local leader=role=='a';local mode=os.getenv('QA_MODE')or'single'
 -- Driver ticks use fixed dt even with vsync off; pace network peers in real time.
 local R=require('src.mods.Runtime');local update=game.update;game.update=function(self,dt)love.timer.sleep(1/60);return R.call('core.update',update,self,dt)end
 game:_handleBootAction({action='new_game',start={map=require('src.core.GameVersion').get()=='emerald'and'EM_OLDALE_TOWN'or'FR_PALLET_TOWN',x=role=='a'and 7 or role=='b'and 8 or role=='host'and 5 or 10,y=8,facing='down'}})
 local space=require('src.core.game3.scripting.space');space.runOnFrame=function()end;local vm=space.getVm();if vm then vm:halt(true)end;require('src.ui.game3.message').reset()
 local Party=require('src.core.game3.party');game.session.name=role;game.session.party={}
 for i=1,2 do assert(Party.giveMon(game.session,leader and 25 or 19,leader and 100 or 1));local m=game.session.party[i];m.moves={153};m.pp={35};m.maxPp={35}end
 local B=require('src.core.game3.battle');local Ui=require('src.core.game3.battle.ui')
 local PartyMenu=require('src.ui.game3.party_menu')
 U.wait(40)
 local S=assert(game.mods.exports['gen1online-plus'].multiplayer)
 local port=tonumber(os.getenv('QA_PORT'))or 27992
 if host then assert(S.hostLan(port,64,'203.0.113.10'))else U.wait(100);assert(S.joinLan('127.0.0.1:'..port))end
 local function untilTrue(fn,label,n)
  -- Uncapped clients advance at different rates while their peers import.
  local deadline=love.timer.getTime()+(n or 1800)/60
  repeat if fn()then return end;U.wait(1)until love.timer.getTime()>=deadline
  error(label..' '..tostring(S.notice))
 end
 untilTrue(function()return S.connected and #S.roster()==3 end,'room connection')
 assert(S.say('QA '..role));U.wait(30);U.shot(game,dir..'/room.png')
 if not fighter then
  untilTrue(function()local done=0;for _,m in ipairs(S.chat)do if m.text=='DONE'then done=done+1 end end;return done>=2 end,'fighters return',18000)
  U.shot(game,dir..'/returned.png');print('[PASS four-player observer]',role);love.event.quit();return
 end
 if leader then local target;for _,p in ipairs(S.roster())do if p.name=='b'then target=p.id end end;assert(target,'target name');assert(S.invite(mode,target))else untilTrue(function()return S.activity and S.activity.status=='incoming'end,'invite');U.shot(game,dir..'/incoming.png');game:keypressed('return');game:keyreleased('return');U.wait(4)end
 untilTrue(function()return S.activity and S.activity.status=='active'end,'activity start')
 local seen,command={},false
 for i=1,18000 do
  if i%300==0 then print('[progress]',role,i,B._phase,Ui._mode)end
  local top=game.stack and game.stack:top();local phase=B._phase and (B._phase..'-'..tostring(Ui._mode))
  if phase and not seen[phase]then print('[room phase]',role,phase);seen[phase]=true;U.shot(game,dir..'/'..phase..'.png')end
  if B._phase=='command' and Ui._mode=='menu'then command=true end
  if S.lastActivity and not S.activity then U.wait(20);U.shot(game,dir..'/returned.png');assert(command,'no command menu');assert(S.connected,'room closed');assert(#S.roster()==3,'room peers lost');assert(S.say('DONE'));U.wait(120);print('[PASS four-player native battle]',role,mode,S.lastActivity.result);love.event.quit();return end
  local picked=PartyMenu.isOpen()and PartyMenu._party and PartyMenu._party[PartyMenu.cursor]
  local invalid=picked and picked.hp<=0
  if picked and B._st and B._st.battlers then
   for id,b in pairs(B._st.battlers)do if id%2==0 and b.mon==picked then invalid=true end end
  end
  U.tap(game,invalid and (PartyMenu.mode=='action'and'b'or'down')or'a');U.wait(2)
 end
 error('room battle stalled')
end
