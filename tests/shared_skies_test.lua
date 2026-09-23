local Sky=dofile('lib/crossgen/sky_world.lua')
local sent,starts,denials={},0,0
local canStart=true
local host=Sky.new{host=true,session='room',send=function(peer,msg)sent[#sent+1]={peer=peer,msg=msg}end,
 canClaim=function(p,r,c)return c.airborne and math.abs((p.altitude or 0)-r.alt)<=20 or not c.airborne and r.alt<=12 end}
local guest=Sky.new{session='room',send=function(_,msg)sent[#sent+1]={msg=msg}end,
 onEncounter=function(r,map)starts=starts+1;assert(map=='TOWN' and r.species=='PIDGEY' and r.level==7);return canStart end,
 onDenied=function()denials=denials+1 end}
local row={id='bird1',species='PIDGEY',level=7,x=80,y=96,alt=8,vx=11,vy=-3,mode='toLand',bold=true}
local pos={map='TOWN',px=80,py=96,altitude=0}
assert(host:publish{map='TOWN',spawns={row}})
local first=sent[#sent].msg
assert(guest:handle('host',first,nil,true));assert(not guest:handle('imposter',first,nil,false))
assert(not guest:handle('host',first,nil,true),'stale snapshot')
local function claim()
 assert(guest:request('TOWN','bird1',{}));local q=sent[#sent].msg
 local ok=host:handle('guest',q,pos);return ok,q
end
local ok,request=claim();assert(ok)
local removal=sent[#sent].msg;local grant=sent[#sent-1].msg
assert(grant.kind=='grant' and removal.kind=='snapshot','grant must precede removal')
assert(guest:handle('host',grant,nil,true));assert(starts==1)
assert(not guest:handle('host',grant,nil,true),'duplicate grant cannot start another battle')
assert(guest:handle('host',removal,nil,true));assert(not host.maps.TOWN.rows.bird1)
assert(host:publish{map='TOWN',spawns={row}});assert(not host.maps.TOWN.rows.bird1,'reserved identity stays hidden')
assert(guest:finish('TOWN','bird1',{consumed=false}));assert(host:handle('guest',sent[#sent].msg))
assert(host.maps.TOWN.rows.bird1,'running restores original bird')
assert(host:handle('guest',request,pos));assert(sent[#sent].msg.kind=='deny','released request cannot be replayed')
canStart=false;assert(claim());grant=sent[#sent-1].msg
assert(not guest:handle('host',grant,nil,true));assert(sent[#sent].msg.kind=='release')
assert(host:handle('guest',sent[#sent].msg));assert(host.maps.TOWN.rows.bird1,'failed native entry restores bird')
canStart=true;assert(claim());grant=sent[#sent-1].msg;assert(guest:handle('host',grant,nil,true))
assert(guest:finish('TOWN','bird1',{consumed=true}));assert(host:handle('guest',sent[#sent].msg))
host:disconnect('guest');assert(host:publish{map='TOWN',spawns={row}});assert(not host.maps.TOWN.rows.bird1,'caught or defeated bird stays removed')
row.id='bird2';row.alt=50;assert(host:publish{map='TOWN',spawns={row}})
assert(guest:request('TOWN','bird2',{}));assert(not host:handle('guest',sent[#sent].msg,pos));assert(guest:handle('host',sent[#sent].msg,nil,true));assert(denials==1)
assert(guest:request('TOWN','bird2',{airborne=true}));pos.altitude=48;assert(host:handle('guest',sent[#sent].msg,pos))
host:disconnect('guest');assert(host.maps.TOWN.rows.bird2,'disconnect restores uncompleted battle')
local bad={};for k,v in pairs(row)do bad[k]=v end;bad.vx=math.huge;assert(not Sky.record(bad))
bad.vx=0;bad.x=0/0;assert(not Sky.record(bad))
print('PASS shared skies host authority, ordered grants, replay, native failure, escape, capture, altitude and disconnect')
