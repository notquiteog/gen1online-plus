-- Emerald/FRLG numeric specials differ. Exercise setup and interrupted cleanup
-- through the adapter, with named and legacy engine APIs.
local count=0
for _,version in ipairs({'emerald','firered','leafgreen'})do for _,named in ipairs({true,false})do
 local calls={};local hp=7;local saved;local ready=false;local result
 local game={session={party={{hp=7}}}}
 local link={isOpen=function()return true end,isReady=function()return true end,take=function()end}
 local function call(name)
  calls[#calls+1]=name
  if name=='SavePlayerParty' then saved=hp elseif name=='HealPlayerParty' then hp=100 elseif name=='LoadPlayerParty'then hp=saved end
  return true
 end
 local Link={USING={DOUBLE_BATTLE=2,SINGLE_BATTLE=1},vmCtx=function()return {},{}end,
  loadPlayerBag=function()end,savePlayerBag=function()end,open=function()return link end,
  closeLink=function()end,callSpecial=function(_,_,id)assert(version~='emerald','wrong family special');return call(({[0x27]='SavePlayerParty',[0x28]='LoadPlayerParty',[0]='HealPlayerParty'})[id])end}
 if named then Link.callSpecialNamed=function(_,_,name)return call(name)end end
 package.loaded['src.core.GameVersion']={get=function()return version end}
 package.loaded['src.core.game3.link']=Link
 package.loaded['src.core.game3.link.battle']={MSG={SETUP='setup'},reset=function()end,validateParty=function()return true end,dealSeed=function()return 1 end,sendSetup=function()ready=true end}
 package.loaded['src.core.game3.link.trade']={reset=function()end}
 package.loaded['src.core.game3.battle']={isActive=function()return false end}
 package.loaded['src.ui.game3.link_trade_menu']={close=function()end}
 local A={};dofile('lib/gen3/link.lua')({world={game=game}},A)
 local sent;local transport={send=function(_,m)sent=m;return true end}
 assert(A.startActivity('single',transport,true,function(r)result=r end))
 local packet={type='setup',mode=1};assert(transport:send(packet));assert(sent.mode=='1' and packet.mode==1,'wire mode changed native enum or would be dropped')
 A.updateActivity(.1)
 if named or version~='emerald' then
  assert(hp==100 and ready and calls[1]=='SavePlayerParty' and calls[2]=='HealPlayerParty')
  A.abortActivity();assert(hp==7 and calls[3]=='LoadPlayerParty' and result=='disconnected')
 else assert(hp==7 and not ready and result=='Party backup unavailable')end
 count=count+1
end end
print('PASS '..count..' named/legacy party backup, preparation and disconnect restoration cases')
