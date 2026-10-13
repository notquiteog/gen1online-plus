local A=dofile('lib/crossgen/host_address.lua')
assert(A.ipv4(' 203.0.113.4\n')=='203.0.113.4')
for _,s in ipairs({'256.1.1.1','1.2.3','1.2.3.4:7777','<html>','1.2.3.4\n5.6.7.8'})do assert(not A.ipv4(s))end
local a=A.new();a.start();assert(a.status=='Unavailable')
a.start('198.51.100.8');assert(a.ip=='198.51.100.8')
local pending
love={thread={newChannel=function()pending={pop=function(self)local r=self.value;self.value=nil;return r end};return pending end,newThread=function()return {start=function()end,getError=function()end}end}}
a.start();assert(a.status=='Looking up...');pending.value='203.0.113.5';a.update(.1);assert(a.ip=='203.0.113.5')
a.start();a.update(11);assert(a.status=='Unavailable'and not a.ip)
a.start();local old=pending;a.clear();old.value='203.0.113.8';a.update(.1);assert(not a.ip)
print('PASS address validation, unavailable fallback, nonblocking result, timeout and stale result isolation')

love=setmetatable({},{__index=function()error('compute denied')end});a.start();assert(a.status=='Unavailable','permission error escaped optional lookup')
