-- Real ENet, four independent session state machines, JSON wire boundaries.
-- Run with tools/qa/multi-room/main.lua under LÖVE; no ROM/save needed.
local root=assert(os.getenv('ONLINE_ROOT'))
local function loadLocal(path)return dofile(root..'/'..path)end
package.loaded['src.link.Net']={defaultPort=function()return 19777 end,lanIP=function()return '127.0.0.1'end}
package.loaded['src.link.Json']=os.getenv('STANDALONE_JSON')=='1'and loadLocal('server/json.lua')or dofile(assert(os.getenv('ENGINE_ROOT'))..'/src/link/Json.lua')
local count=0
local function check(v,why)count=count+1;assert(v,why)end
local sessions,ends={},{}
local function endpoint(i,dedicated,noWilds)
 local e={position={map='town',x=i%2,y=0,px=(i%2)*16,py=0,facing='down',name='PLAYER'..i},drawn={},starts={},applied={},encounters=0}
 local rows={{id='bird',species='PIDGEY',level=5,x=1,y=0}}
 local provider={version=1,configure=function(c)e.config=c end,apply=function(map,data)e.applied[map]=data end,
 snapshot=function()return'town',rows end,remoteSnapshot=function(map)return{{id='remote',species='PIDGEY',level=5,x=1,y=0}}end,
 beginEncounter=function()e.encounters=e.encounters+1;return true end,
 beginCatch=function()e.encounters=e.encounters+1;return true,{caught=true}end,canCatch=function()return true end}
 local skyRows={town={{id='skybird',species='PIDGEY',level=5,x=16,y=0,alt=8,vx=0,vy=0,bold=true,mode='roam'}}}
 local sky={registerSharedSkyProvider=function(_,c)e.skyConfig=c;return true end,unregisterSharedSkyProvider=function()e.skyConfig=nil end,
 canClaimSky=function()return true end,grantSharedSkyFieldContact=function()e.skyEncounters=(e.skyEncounters or 0)+1;return true end,
 denySharedSkyFieldContact=function()end,applySharedSkyFieldSnapshot=function(p)skyRows[p.map]=p.spawns;return true end,
 sharedSkyFieldSnapshot=function(map)return{map=map,spawns=skyRows[map]or{}}end}
 local a={publicIP='203.0.113.10',dedicated=dedicated,generation=3,game='leafgreen',position=function()return e.position end,capabilities=function()return{single=true,double=true,trade=true}end,
 peer=function(p,id)e.drawn[id]=p end,removePeer=function(id)e.drawn[id]=nil end,clearPeers=function()e.drawn={}end,
 startActivity=function(mode,ch,host,done)e.starts[#e.starts+1]={mode=mode,ch=ch,host=host,done=done};return true end,
 abortActivity=function()e.aborted=true end}
 local function loader(path)
  if path=='lib/crossgen/room_transport.lua'then local T=loadLocal(path);return{new=function()e.net=T.new();return e.net end}end
  if path=='lib/crossgen/discovery.lua'then return{new=function()return{stop=function()end,host=function()return true end,update=function()end}end}end
  return loadLocal(path)
 end
 e.S=loadLocal('lib/crossgen/session.lua')({hooks={wrap=function()end},find=function(id)if dedicated then return end;if id=='overworld_wild_spawns'and not noWilds then return{exports={sharedSpawns=provider}}elseif id=='wild_skies'then return{exports=sky}end end},loader,a)
 sessions[#sessions+1]=e.S;ends[#ends+1]=e;return e
end
local realtime=false
local function step(n)
 for _=1,n or 25 do for _,s in ipairs(sessions)do s.update(.02)end;love.timer.sleep(realtime and .02 or .001)end
end
local H=endpoint(1);local started,why=H.S.hostLan(19777);check(started,'host bind: '..tostring(why))
local A,B,C=endpoint(2),endpoint(3),endpoint(4)
for _,e in ipairs({A,B,C})do check(e.S.joinLan('127.0.0.1:19777'),'guest join')end
step(150)
for _,e in ipairs(ends)do check(e.S.connected and #e.S.roster()==3,'four member roster');local n=0;for _ in pairs(e.drawn)do n=n+1 end;check(n==3,'render three distinct peers')end
check(A.S.localId~=B.S.localId and B.S.localId~=C.S.localId,'unique host assigned IDs')
check(A.S.say('Hello room'),'chat');step();for _,e in ipairs(ends)do check(#e.S.chat==1 and e.S.chat[1].text=='Hello room','one chat delivered each')end
-- Two simultaneous disjoint activities; one is guest-to-guest.
check(A.S.invite('double',B.S.localId),'guest invites guest');check(H.S.invite('trade',C.S.localId),'parallel host trade');step()
check(B.S.activity and B.S.activity.status=='incoming','target receives invite');check(C.S.activity and C.S.activity.mode=='trade','other pair isolated')
check(B.S.respond(true),'guest accept');check(C.S.respond(true),'host trade accept');step()
check(A.starts[1].host and not B.starts[1].host,'inviter owns native battle host role')
check(H.starts[1].host and not C.starts[1].host,'host trade roles')
A.starts[1].ch:send{type='private',value=17};step();check(B.starts[1].ch:poll()[1].value==17,'targeted channel delivered');check(#C.starts[1].ch:poll()==0,'no channel leak')
-- A third room member cannot inject into an activity channel.
local alien=C.S.channel(A.S.activity.id,B.S.localId,false);alien:send{type='forged'};step();check(#B.starts[1].ch:poll()==0,'sender authenticated for virtual link');alien:close()
for _,e in ipairs({A,B,H,C})do e.starts[1].done('finished')end;step();for _,e in ipairs(ends)do check(not e.S.activity and e.S.connected,'activity completion preserves room')end
-- Shared encounter grants exactly one simultaneous claimant.
check(A.config.request('town','bird'),'first claim');check(B.config.request('town','bird'),'second claim queued');step();check(A.encounters+B.encounters==1,'host arbitrates single encounter owner');check(C.encounters==0,'uninvolved guest never receives grant')
check(A.skyConfig and B.skyConfig and C.skyConfig,'all sky providers registered')
check(A.skyConfig.requestClaim('town','skybird',{airborne=false}),'first sky claim');check(B.skyConfig.requestClaim('town','skybird',{airborne=false}),'second sky claim');step();check((A.skyEncounters or 0)+(B.skyEncounters or 0)==1 and not C.skyEncounters,'one targeted sky grant')
C.position.map='route';step();check(H.S.state().authority.route~=nil,'host publishes remote occupied maps')
-- Kick/rejoin must not tear down anyone else's room or presence.
local removed=B.S.localId;check(H.S.kick(removed),'host kicks selected guest');step();check(not B.S.connected and H.S.connected and A.S.connected and C.S.connected,'targeted kick preserves others');check(#A.S.roster()==2 and not A.drawn[removed],'departure prunes entity/roster')
check(B.S.joinLan('127.0.0.1:19777'),'rejoin');step(100);check(B.S.connected and #B.S.roster()==3 and B.S.localId~=removed,'rejoin receives fresh identity')
-- New clients may join after previous activities.
local bad=endpoint(5);check(bad.S.joinLan('127.0.0.1:19777'),'extra client');step(100);check(#H.S.roster()==4,'room accepts fifth client')
bad.S.disconnect();step();check(H.S.connected and #H.S.roster()==3,'ordinary guest departure keeps host')
for _,s in ipairs(sessions)do s.disconnect()end
sessions,ends={},{}
local D=endpoint(0,true);check(D.S.hostLan(19778),'dedicated bind')
local players={};for i=1,4 do players[i]=endpoint(i);check(players[i].S.joinLan('127.0.0.1:19778'),'dedicated join')end
step(180)
for _,e in ipairs(players)do check(e.S.connected and #e.S.roster()==3,'server hidden, four-player roster');check(e.config and e.skyConfig,'dedicated providers installed')end
local owner=D.S.ecologyOwners.wilds;check(owner and D.S.ecologyOwners.skies,'elected ecology leases');check(D.S.state().authority.town~=nil,'ROM-free server receives delegated world snapshot')
local G1,G2=players[2],players[3]
check(G1.config.request('town','bird',{action='catch',ballId=1,charge=1}),'delegated capture request');step(120)
check(G1.encounters==1,'server grants capture after elected client collision validation')
check(G2.skyConfig.requestClaim('town','skybird',{airborne=false}),'dedicated sky contact');step(120);check(G2.skyEncounters==1,'dedicated server validates and grants sky encounter')
local epoch=D.S.ecologyEpoch;check(D.S.kick(owner),'remove simulator');step(160)
check(D.S.ecologyOwners.wilds and D.S.ecologyOwners.wilds~=owner and D.S.ecologyEpoch>epoch,'owner re-election increments lease')
check(D.S.state().authority.town.rows.bird==nil,'committed ground identity does not respawn on owner replacement')
local survivor=players[4]
survivor.net:send{type='world_ecology',session=D.S.session,epoch=epoch,domain='wilds',map='town',rows={{id='forged',species='MEW',level=100,x=0,y=0}}};step()
check(not D.S.state().authority.town.rows.forged,'expired or non-owner ecology rejected')
check(survivor.S.say('Still connected'),'survivor chat');step();check(D.S.connected,'dedicated host survives owner departure')
for _,s in ipairs(sessions)do s.disconnect()end
sessions,ends={},{};local vanillaHost=endpoint(1,false,true);local moddedGuest=endpoint(2)
check(vanillaHost.S.hostLan(19780),'optional host bind');check(moddedGuest.S.joinLan('127.0.0.1:19780'),'optional guest join');step(150)
check(moddedGuest.S.connected and not moddedGuest.config,'host without Wilds must not suppress guest standalone spawns')
for _,s in ipairs(sessions)do s.disconnect()end
local loadCount=tonumber(os.getenv('ONLINE_LOAD_PLAYERS'))or(os.getenv('ONLINE_LOAD64')=='1'and 64)
if loadCount then
 assert(loadCount>=4 and loadCount<=128)
 realtime=true;sessions,ends={},{};local server=endpoint(0,true);check(server.S.hostLan(19779,loadCount),'load-test dedicated bind')
 local clients={};for i=1,loadCount do clients[i]=endpoint(i);assert(clients[i].S.joinLan('127.0.0.1:19779'))end
 local start=love.timer.getTime();step(250)
 for _,e in ipairs(clients)do check(e.S.connected and #e.S.roster()==loadCount-1,'load-test handshake and roster '..tostring(e.S.localId)..' '..tostring(e.S.notice)..' members='..#e.S.roster()..' host='..tostring(server.S.notice))end
 check(#server.S.roster()==loadCount,'load-test server roster');clients[loadCount].S.say('large room');step(80)
 for _,e in ipairs(clients)do check(e.S.chat[#e.S.chat].text=='large room','large room chat')end
 print(string.format(tostring(loadCount)..'-client localhost transport load: %.2fs wall time; mock game adapters, not rendering benchmark',love.timer.getTime()-start))
 for _,s in ipairs(sessions)do s.disconnect()end
end
print('PASS '..count..' real ENet multi-player roster, rendering dispatch, chat, guest-to-guest doubles, concurrent trade, authenticated channels, shared encounters and rejoin checks')
