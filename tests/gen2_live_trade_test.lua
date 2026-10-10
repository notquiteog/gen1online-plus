-- Run with the engine on LUA_PATH; exercise its real Gen2 wire/consent code.
love=love or require('tests.love_stub')
local Mon=require('src.battle.gen2.Mon')
local Wire=require('src.link.Wire')
local Live=dofile('lib/gen2/trade_session.lua')
local Barrier=dofile('lib/crossgen/trade_barrier.lua')
local data={pokemon={ONIX={name='ONIX',baseStats={hp=35,attack=45,defense=160,speed=70,specialAttack=30,specialDefense=45},types={'ROCK','GROUND'},evolutions={}}},moves={TACKLE={name='TACKLE',pp=35}},items={METAL_COAT={name='METAL COAT'}}}
local function mon(name)
 local dvs={attack=15,defense=15,speed=15,special=15,hp=15};local exp={hp=0,attack=0,defense=0,speed=0,special=0}
 local stats=Mon.stats(data.pokemon.ONIX.baseStats,dvs,20,exp)
 return{species='ONIX',name='ONIX',nickname=name,level=20,experience=8000,dvs=dvs,statExp=exp,stats=stats,hp=stats.hp,maxHp=stats.hp,types={'ROCK','GROUND'},moves={{id='TACKLE',pp=35,maxPp=35}},happiness=70,pokerus=0,caughtLevel=20,ot='TEST',otId=9,item='METAL_COAT'}
end
local function pair()
 local h,g={q={}},{q={}}
 for _,n in ipairs{h,g}do function n:update()end;function n:poll()local q=self.q;self.q={};return q end end
 function h:send(m)g.q[#g.q+1]=assert(Wire.sanitize(m));return true end
 function g:send(m)h.q[#h.q+1]=assert(Wire.sanitize(m));return true end
 Barrier.wrap(h,true,'trade_confirm')
 local hp,gp={mon('HOST')},{mon('GUEST')}
 return Live.new(data,hp,h,true,'GUEST'),Live.new(data,gp,g,false,'HOST'),hp,gp,h,g
end
local a,b,hp,gp=pair();a:start();b:start();assert(a:update()=='picking'and b:update()=='picking')
assert(a:pick(1)and b:pick(1));a:update();b:update();assert(a:confirm(true));a:update();b:update();assert(a:update()~='done','unilateral confirmation committed')
assert(b:confirm(true));for i=1,5 do a:update();b:update()end
assert(a:update()=='done'and b:update()=='done');assert(hp[1].nickname=='HOST'and gp[1].nickname=='GUEST','protocol wrote live save before screen commit')
assert(a.session.theirParty[1].nickname=='GUEST'and a.session.theirParty[1].item=='METAL_COAT','Gen2 record was degraded')
local x,y,_,_,hx=pair();x:start();y:start();x:update();y:update();hx.closed=true;assert(x:update()=='cancelled')
local c,d,_,_,_,dn=pair();c:start();d:start();c:update();d:update();c:pick(1);d:pick(1);c:update();d:update();c:confirm(true);d:confirm(true);c:update();dn:send{type='bye'};assert(c:update()=='cancelled','commit wait ignored peer departure')
local z,other,_,_,_,net=pair();z:start();net:send{type='party',mons={}};assert(z:update()=='cancelled')
print('PASS real Gen2 native consent/wire, two-party barrier, held item, no offline mutation, malformed party/disconnect')
