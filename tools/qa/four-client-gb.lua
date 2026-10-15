-- Run four isolated *-qa processes with QA_ROLE=host/a/b/c and QA_MODE=single/double.
-- Requires Online; doubles additionally require Double Battles. Other mods remain optional.
-- Exercises real room invitations and native battle entry; no intro/turn bypass.
return function(game)
 assert(love.filesystem.getIdentity():match('%-qa$'))
 local U=dofile('tests/drivers/util.lua');local dir=assert(os.getenv('SHOT_DIR'))
 love.window.setMode(640,480,{vsync=0,msaa=0});local options=game.options or(game.save and game.save.options)or{};options.animations=false;options.textSpeed='fast'
 love.joystick.getJoysticks=function()return{}end;love.joystick.getJoystickCount=function()return 0 end
 local role=os.getenv('QA_ROLE')or'host';local host=role=='host';local fighter=role=='a'or role=='b';local leader=role=='a';local mode=os.getenv('QA_MODE')or'single'
 -- Driver ticks use fixed dt even with vsync off; pace network peers in real time.
 local R=require('src.mods.Runtime');local update=game.update;game.update=function(self,dt)love.timer.sleep(1/60);return R.call('core.update',update,self,dt)end
 local gen=require('src.core.GameVersion').generation()
 if gen==2 then game.world.trySceneScript=function()return false end;game.stack:clear();assert(game.world:setMap('NEW_BARK_TOWN',role=='a'and 7 or role=='b'and 8 or role=='host'and 5 or 10,8,'down'))else U.teleport(game,'PALLET_TOWN',role=='a'and 9 or role=='b'and 10 or role=='host'and 7 or 12,8,'down')end
 game.save.player.name=role
 local Pokemon=require(gen==2 and 'src.battle.gen2.Mon'or'src.pokemon.Pokemon');game.save.party={}
 for i=1,2 do game.save.party[i]=Pokemon.new(game.data,leader and 'PIKACHU'or'RATTATA',leader and 100 or 1);game.save.party[i].moves={{id='TACKLE',pp=35,maxPP=35}}end
 local S=assert(game.mods.exports['gen1online-plus'].multiplayer)
 local port=tonumber(os.getenv('QA_PORT'))or 27991
 if host then assert(S.hostLan(port,64,'203.0.113.10'))else U.wait(100);assert(S.joinLan('127.0.0.1:'..port))end
 local function untilTrue(fn,label,n)
  -- Uncapped clients advance at different rates while their peers import.
  local deadline=love.timer.getTime()+(n or 1800)/60
  repeat if fn()then return end;U.wait(1)until love.timer.getTime()>=deadline
  error(label..' '..tostring(S.notice)..' connected='..tostring(S.connected)..' status='..tostring(S.status)..' roster='..#S.roster())
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
  local top=game.stack:top();if i%300==0 then print('[progress]',role,i,top and top.phase,top and top.current and top.current.kind)end;local phase=top and (top.phase or top.stage)
  if phase and not seen[phase]then print('[room phase]',role,phase);seen[phase]=true;U.shot(game,dir..'/'..phase..'.png')end
  if top and top.phase=='menu'then command=true end
  if S.lastActivity and not S.activity then U.wait(20);U.shot(game,dir..'/returned.png');assert(command,'no command menu');assert(S.connected,'room closed');assert(#S.roster()==3,'room peers lost');assert(S.say('DONE'));U.wait(120);print('[PASS four-player native battle]',role,mode,S.lastActivity.result);love.event.quit();return end
  local picked=top and top.party and top.index and top.party[top.index]
  U.tap(game,picked and picked.hp<=0 and 'down'or'a');U.wait(2)
 end
 error('room battle stalled')
end
