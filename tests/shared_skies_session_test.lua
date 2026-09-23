-- Two endpoints with real Sky authority/session modules and deterministic
-- public-provider mocks. No sockets, ROM, game loop or persistent writes.
local n=0
local function check(v,m)n=n+1;assert(v,m)end
local function clone(t)local c={};for k,v in pairs(t or{})do c[k]=type(v)=='table'and clone(v)or v end;return c end
local wire={};local endpoints={}
local function endpoint(id,isHost)
 local E={starts=0,registered=0,removed=0,canStart=true,apply=true,rows={TOWN={}},snapshots=0}
 E.position={map='TOWN',x=5,y=6,px=80,py=96,busy=false,skyBusy=false,height=0}
 E.S={connected=false,host=isHost,session='room1',peerCapabilities={},peers={}}
 local P={};E.provider=P
 function P.registerSharedSkyProvider(_,cfg)E.registered=E.registered+1;E.config=cfg;return E.accept~=false end
 function P.unregisterSharedSkyProvider()E.removed=E.removed+1;E.config=nil;E.pending=nil;return true end
 function P.sharedSkyNeighborMaps()return{}end
 function P.sharedSkyFieldSnapshot(map)
  local out={map=map,spawns={}}
  if not E.stale then for _,r in pairs(E.rows[map]or{})do out.spawns[#out.spawns+1]=clone(r)end end
  return out
 end
 function P.applySharedSkyFieldSnapshot(snapshot)
  E.snapshots=E.snapshots+1
  if not E.apply then return false end
  local rows={};for _,r in ipairs(snapshot.spawns)do rows[r.id]=clone(r)end
  E.rows[snapshot.map]=rows;E.stale=false;return true
 end
 function P.canClaimSky(p,row,context)
  E.lastClaimPose=clone(p)
  return context.airborne and math.abs(p.altitude-row.alt)<=20 or not context.airborne and row.alt<=12
 end
 function P.grantSharedSkyFieldContact(map,key)
  check(E.pending and E.pending.map==map and E.pending.id==key,'grant waits until provider recorded pending contact')
  E.pending=nil;E.starts=E.starts+1
  if not E.canStart then return false end
  E.rows[map][key]=nil;return true
 end
 function P.denySharedSkyFieldContact()E.pending=nil;return true end
 local mod={find=function()return E.enabled~=false and{exports=P}or nil end}
 E.M=dofile('lib/crossgen/sky_session.lua')(mod,dofile,{position=function()return E.position end},E.S,function(msg)
  wire[#wire+1]={target=id=='host'and'guest'or'host',msg=clone(msg)}
 end)
 function E:request(key,airborne)
  local accepted,why=self.config.requestClaim('TOWN',key,{airborne=airborne==true})
  if accepted then self.pending={map='TOWN',id=key}end
  return accepted,why
 end
 endpoints[id]=E;return E
end
local H=endpoint('host',true);local G=endpoint('guest',false)
local function pose()H.S.peers.remote=clone(G.position);G.S.peers.remote=clone(H.position)end
local function pump()
 for _=1,100 do if #wire==0 then return end;local pending=wire;wire={};for _,r in ipairs(pending)do endpoints[r.target].M.handle(r.msg)end end
 error('network did not quiesce')
end
local function step(dt)pose();H.M.update(dt or .11);G.M.update(dt or .11);pump()end
local function row(id,alt)return{id=id,species='PIDGEY',level=7,x=80,y=96,alt=alt or 8,vx=0,vy=0,bold=true,mode='roam'}end
H.rows.TOWN.bird1=row('bird1');H.rows.TOWN.bird2=row('bird2')
check(H.M.available()and G.M.available(),'complete local provider advertises capability')
step();check(not H.config and not G.config,'disconnected keeps standalone ecology')
H.S.connected=true;G.S.connected=true;step();check(not H.config and not G.config,'peer capability required before registration')
H.S.peerCapabilities.sharedSkies=true;G.S.peerCapabilities.sharedSkies=true;step()
check(H.config.localAuthority and G.config.role=='guest','handshake selects one authority')
check(G.rows.TOWN.bird1 and G.rows.TOWN.bird2,'guest receives host population')
H.canStart=false;check(H:request('bird1'),'host can request own contact');check(H.starts==0,'localhost request is deferred')
step();check(H.starts==1 and H.rows.TOWN.bird1,'failed native entry restores host ecology before next publication')
step();check(H.rows.TOWN.bird1 and G.rows.TOWN.bird1,'release survives subsequent publication')
H.canStart=true;check(H:request('bird1'),'retry restored contact');step();check(H.starts==2 and not H.rows.TOWN.bird1,'host entry removes reserved identity')
check(H.config.finishClaim('TOWN','bird1',{consumed=false}),'host run releases claim');step();check(H.rows.TOWN.bird1 and G.rows.TOWN.bird1,'run release restored on both endpoints')
check(G:request('bird2'),'guest contact accepted');pump();check(G.starts==1,'remote grant enters once');step();check(not H.rows.TOWN.bird2 and not G.rows.TOWN.bird2,'remote reservation removes both replicas')
-- Force failed local snapshot application while a remote release arrives. The
-- next provider snapshot is stale/empty; authority must retain the released row.
H.apply=false;H.stale=true;check(G.config.finishClaim('TOWN','bird2',{consumed=false}),'guest release');pump();step()
check(G.rows.TOWN.bird2,'authority preserves restored row while host application fails')
H.apply=true;step();check(H.rows.TOWN.bird2 and G.rows.TOWN.bird2,'later applied snapshot restores host ecology')
step();check(H.rows.TOWN.bird2,'restored row remains after acknowledgement')
-- Ground busy is true in flight, while skyBusy still permits aerial contact.
H.rows.TOWN.high=row('high',50);G.position.ride={mode='fly',height=48};G.position.height=0;G.position.busy=true;G.position.skyBusy=false
step();check(G:request('high',true),'flight can request an aerial contact');pump();check(G.starts==2 and H.lastClaimPose.altitude==48,'host uses ride height despite normalized height zero')
check(G.config.finishClaim('TOWN','high',{consumed=true}),'caught bird commits');pump();step();check(not H.rows.TOWN.high and not G.rows.TOWN.high,'committed bird remains removed')
G.position.skyBusy=true;check(not G:request('bird1',true),'actual menu/script busy still refuses')
local stale=G.config;G.S.connected=false;G.M.update(.1);check(not G.config and G.removed==1,'disconnect unregisters provider');check(not stale.requestClaim('TOWN','bird1',{}),'old callbacks inert after disconnect')
G.S.connected=true;G.S.session='room2';H.S.session='room2';step();check(G.config and G.config~=stale,'new session installs new provider callbacks');check(not stale.requestClaim('TOWN','bird1',{}),'old room callback cannot enter new room')
local current=G.config;G.S.peerCapabilities.sharedSkies=false;G.M.update(.1);check(not G.config and not current.finishClaim('TOWN','bird2',{}),'capability withdrawal clears agreement')
G.S.peerCapabilities.sharedSkies=true;G.accept=false;G.M.update(.1);check(not G.config,'provider registration refusal stays standalone')
G.accept=true;local deny=G.provider.denySharedSkyFieldContact;G.provider.denySharedSkyFieldContact=nil;check(not G.M.available(),'partial legacy provider does not advertise support');G.provider.denySharedSkyFieldContact=deny
print('PASS '..n..' shared skies two-endpoint handshake/provider/authority lifecycle contracts')
