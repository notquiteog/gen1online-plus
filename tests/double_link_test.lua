package.loaded['src.link.Fingerprint']={digest=function(s)assert(type(s)=='string' and #s>0,'hash must cover serialized state');return s end}
local M=dofile('lib/crossgen/double_link.lua')
local function net()return {inbox={},send=function(self,m)table.insert(self.peer.inbox,m)end,poll=function(self)local q=self.inbox;self.inbox={};return q end}end
local a,b=net(),net();a.peer=b;b.peer=a
local function screen(n)
 local proxy=M.transport(n)
 local s={net=proxy,phase='menu',link={},turns=0,restored=0,refuseMenu=function()error('unexpected refusal')end}
 s.update=function(self)self.net:poll()end
 local provider={attach=function()
  return {slots=function()return {1,2}end,select=function()end,encode=function(action)return action end,decode=function(rows)return rows end,
   restore=function()s.restored=s.restored+1 end,
   resolve=function(mine,theirs)assert(mine[1] and mine[2] and theirs[1] and theirs[2]);s.turns=s.turns+1;s.phase='resolving';return true end,
   signature=function()return 'turn='..s.turns..';hp='..(100-s.turns*10)end,
   finish=function()s.failed=true end}
 end}
 assert(M.attach(s,proxy,provider,true));return s
end
local x,y=screen(a),screen(b)
x.link.submit(x,{kind='move',move=1});assert(#b.inbox==0 and x.turns==0,'first choice sent a half turn')
x.link.submit(x,{kind='move',move=2});y:update(1);assert(x.turns==0 and y.turns==0,'opponent acted without local choices')
y.link.submit(y,{kind='move',move=1});y.link.submit(y,{kind='move',move=2})
x:update(1);y:update(1);assert(x.turns==1 and y.turns==1);assert(x.doubleRoom.verified==1 and y.doubleRoom.verified==1)
a.inbox={{type='room_double_hash',turn=1,hash='different'}};x:update(1);assert(x.failed,'desync was accepted')
b.closed=true;y:update(1);assert(y.restored>0,'disconnect did not restore active slot')
print('PASS paired choices, wait-for-both, state hashes, desync rejection and disconnect restore')
