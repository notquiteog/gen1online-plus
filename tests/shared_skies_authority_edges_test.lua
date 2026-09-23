local Sky=dofile('lib/crossgen/sky_world.lua')
local n=0
local function check(v,m)n=n+1;assert(v,m)end
local sent={}
local host=Sky.new{host=true,session='edge',send=function(_,m)sent[#sent+1]=m end,canClaim=function()return true end}
local function row(id)return{id=id,species='PIDGEY',level=5,x=0,y=0,alt=8,bold=true}end
local p={map='M',px=0,py=0}
local function req(id,index,kind)return{type='shared_skies',protocol=1,session='edge',kind=kind or'claim',map='M',spawn=id,request=index,airborne=false}end
host:publish{map='M',spawns={row('a'),row('b')}}
check(host:handle('peer',req('a',1),p),'first claim accepted')
check(not host:handle('peer',req('b',2),p),'same peer cannot reserve second concurrent bird')
check(host.maps.M.rows.b~=nil,'second bird remains available')
check(host:handle('peer',req('a',1,'release'),p),'release accepted')
check(host:publish{map='M',spawns={}},'empty stale provider snapshot accepted')
check(host.maps.M.rows.a~=nil,'unacknowledged restore survives empty source refresh')
local revision=host.maps.M.revision
check(host:acknowledgeSnapshot('M',revision),'host ecology acknowledges applied snapshot')
host:publish{map='M',spawns={}}
check(not host.maps.M.rows.a,'acknowledged ecology resumes population ownership')
host:publish{map='M',spawns={row('a')}};check(host:handle('peer',req('a',3),p),'claim after release accepted')
local full={};for i=1,32 do full[i]=row('new'..string.format('%02d',i))end
host:publish{map='M',spawns=full}
check(host:handle('peer',req('a',3,'release'),p),'release into a replenished sky')
local count=0;for _ in pairs(host.maps.M.rows)do count=count+1 end
check(count==32 and host.maps.M.rows.a,'released bird retained within maximum population')
check(#sent[#sent].rows==32,'broadcast remains valid for peers')
host:publish{map='M',spawns=full};count=0;for _ in pairs(host.maps.M.rows)do count=count+1 end
check(count==32 and host.maps.M.rows.a,'unacknowledged restore and provider refresh stay bounded')
print('PASS '..n..' shared skies authority restoration/capacity/concurrency contracts')
