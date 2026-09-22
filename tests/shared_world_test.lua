local M=dofile('lib/crossgen/shared_world.lua')
local sent,applied,encounters={},{},0
local host=M.new{host=true,session='room1',send=function(peer,msg)sent[#sent+1]={peer,msg}end}
local guest=M.new{session='room1',send=function(peer,msg)sent[#sent+1]={peer,msg}end,onSnapshot=function(map,rows)applied=rows end,onEncounter=function(row)encounters=encounters+1;assert(row.species=='SENTRET'and row.level==3);return true end}
local spawn={id='ROUTE29:1:1',x=5,y=7,species='SENTRET',level=3,personality=1234}
assert(host:publish('ROUTE29',{spawn}));local packet=sent[#sent][2]
assert(not guest:handle('fake',packet,nil,false));assert(guest:handle('host',packet,nil,true));assert(#applied==1)
assert(not guest:handle('host',packet,nil,true))
assert(not guest:publish('ROUTE29',{}))
local function claim(peer,n,x)return host:handle(peer,{type='shared_wilds',protocol=1,session='room1',kind='claim',map='ROUTE29',spawn=spawn.id,request=n},{map='ROUTE29',x=x,y=7})end
assert(not claim('far',1,50));assert(host.maps.ROUTE29.rows[spawn.id])
assert(guest:request('ROUTE29',spawn.id)==1);assert(claim('a',1,5));local grant=sent[#sent][2]
assert(not claim('b',1,5),'second player cannot claim the same mon')
assert(guest:handle('host',grant,nil,true));local commit=sent[#sent][2]
assert(not guest:handle('host',grant,nil,true));assert(encounters==1)
assert(not host:handle('b',commit));assert(host:handle('a',commit));host:disconnect('a')
assert(not host.maps.ROUTE29.rows[spawn.id],'committed encounter cannot respawn on disconnect')
assert(host:publish('ROUTE29',{spawn}));assert(not host.maps.ROUTE29.rows[spawn.id],'stale producer cannot recreate claimed spawn')
local nextSpawn={id='ROUTE29:1:2',x=5,y=7,species='PIDGEY',level=4}
assert(host:publish('ROUTE29',{nextSpawn}));spawn=nextSpawn;assert(claim('c',1,5));host:disconnect('c');assert(host.maps.ROUTE29.rows[spawn.id],'uncommitted disconnect releases reservation')
local bad={type='shared_wilds',protocol=1,session='old',kind='snapshot',map='ROUTE29',revision=99,rows={}}
assert(not guest:handle('host',bad,nil,true))
local denied = 0
local throwing = M.new{session='room1', send=function(_,m)sent[#sent+1]={'throwing',m}end,
 onEncounter=function()error('native battle unavailable')end}
assert(throwing:request('ROUTE29',spawn.id)==1)
assert(claim('throwing',1,5));local failedGrant=sent[#sent][2]
assert(not throwing:handle('host',failedGrant,nil,true))
local release=sent[#sent][2];assert(release.kind=='release')
assert(host:handle('throwing',release));assert(host.maps.ROUTE29.rows[spawn.id])
assert(claim('throwing',1,5));assert(sent[#sent][2].kind=='deny','expired requests cannot be granted again')
assert(not guest:handle('host',failedGrant,nil,true),'unsolicited grant cannot start battle')
assert(not M.record{id='bad',x=0,y=0,level=4,species=0/0})
local recursive={id='safe',x=0,y=0,level=4,species='PIDGEY'};recursive.payload=recursive
assert(M.record(recursive).payload==nil,'unknown recursive input is discarded')
local town={id='town:1',x=5,y=7,species='SENTRET',level=1,ambient=true,wanders=true}
assert(host:publish('ROUTE29',{town}));spawn=town
assert(not claim('town-guest',1,5),'peaceful shared town Pokemon cannot be claimed as wilds')
assert(host.maps.ROUTE29.rows[town.id].ambient,'denied claim preserves town actor')
print('PASS host ownership, snapshots, stale sessions/revisions, distance, atomic duplicate claims, replay and disconnect recovery')
