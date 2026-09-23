local M=dofile('lib/crossgen/shared_world.lua')
local packets,rolls={},0
local caught=false
local host=M.new{host=true,session='catch-room',send=function(peer,msg)packets[#packets+1]=msg end,
 canCatch=function(pos,row)return pos.facing=='right' and row.x>pos.x end}
local guest=M.new{session='catch-room',send=function(_,msg)packets[#packets+1]=msg end,
 onCatch=function(row,map,request)
  rolls=rolls+1;assert(row.species==25 and request.ballId==4 and map=='FIELD')
  return true,{caught=caught,shakes=2}
 end,onEncounter=function()error('direct catch opened a battle')end}
local row={id='field:1',species=25,level=7,x=8,y=5,behavior='wander'}
local position={map='FIELD',x=5,y=5,facing='right'}
local function throw(charge)
 assert(guest:request('FIELD',row.id,{action='catch',ballId=4,charge=charge}))
 return host:handle('guest',packets[#packets],position)
end
assert(host:publish('FIELD',{row}))
assert(not throw(0),'uncharged throw cannot reach three cells')
assert(guest:handle('host',packets[#packets],nil,true))
assert(throw(.5));local grant=packets[#packets]
assert(not host.maps.FIELD.rows[row.id],'host reserves before resolving catch')
assert(guest:handle('host',grant,nil,true));assert(rolls==1)
assert(packets[#packets].kind=='release');assert(host:handle('guest',packets[#packets]))
assert(host.maps.FIELD.rows[row.id],'failed catch restores shared spawn')
assert(not guest:handle('host',grant,nil,true));assert(rolls==1,'grant replay consumes no second ball')
caught=true
assert(throw(1));grant=packets[#packets]
assert(guest:handle('host',grant,nil,true));assert(packets[#packets].kind=='commit')
assert(host:handle('guest',packets[#packets]));host:disconnect('guest')
assert(not host.maps.FIELD.rows[row.id],'successful catch stays consumed')
assert(host:publish('FIELD',{row}));assert(not host.maps.FIELD.rows[row.id],'stale roster cannot resurrect caught mon')
row={id='field:2',species=25,level=7,x=8,y=5,scenery=true,behavior='idle'}
assert(host:publish('FIELD',{row}));assert(host.maps.FIELD.rows[row.id].scenery)
assert(not throw(1),'scenery is never a catch target');guest:handle('host',packets[#packets],nil,true)
row.scenery=false;assert(host:publish('FIELD',{row}));position.facing='left'
assert(not throw(1),'authority rejects throw facing away');guest:handle('host',packets[#packets],nil,true)
assert(not guest:request('FIELD',row.id,{action='catch',ballId=0,charge=1}))
assert(not guest:request('FIELD',row.id,{action='catch',ballId=4,charge=0/0}))
print('PASS shared direct capture range, host reservation, replay, failed roll, commit, scenery and facing guards')
