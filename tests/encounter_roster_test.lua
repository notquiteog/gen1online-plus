local R = dofile('other/EncounterRoster.lua')
local species = {SENTRET={}, TOGEPI={}, MARILL={}}
-- The shipped New Bark corruption: letters from species names were parsed
-- as level/chance fields. Such rows must never create placeholder actors.
local broken = {grass={DAY={}},rare_ow={
 {species='T',minLevel='O',maxLevel='G',chance='E'},
 {species='M',minLevel='A',maxLevel='R',chance='I'},
 {species='MARILL',minLevel=0,maxLevel=101},
}}
assert(#R.generate('NEW_BARK_TOWN',broken,'DAY',60,species,math.random)==0)
local config={grass={DAY={{species='SENTRET',minLevel=2,maxLevel=4}}},rare_ow={}}
local calls=0
local function random(a,b) calls=calls+1;return b end
local roster=R.generate('ROUTE_29',config,'DAY',40,species,random)
assert(#roster==6)
local first=roster[1]
for i=1,1000 do
 local validated=R.validTargets(roster,species)
 assert(#validated==6 and validated[1]==first and first.species=='SENTRET')
end
assert(calls==18,'validation must not reroll encounters')
R.consume(roster,first.id)
assert(#roster==5 and roster[1]~=first,'claimed local encounter stays removed')
local targets=R.validTargets({{id='bad',species='T',level=2},
 {id='nan',species='SENTRET',level=0/0},first,first},species)
assert(#targets==1 and targets[1]==first)
print('encounter roster: malformed town data, persistent identity, claims, server validation PASS')
