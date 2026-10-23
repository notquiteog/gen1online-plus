local A=dofile('lib/crossgen/host_address.lua')
assert(A.ipv4(' 203.0.113.4\n')=='203.0.113.4')
for _,s in ipairs{'256.1.1.1','1.2.3','1.2.3.4:7777','<html>','1.2.3.4\n5.6.7.8'}do assert(not A.ipv4(s))end
love=setmetatable({},{__index=function()error('raw LÖVE services must not be read')end})
local a=A.new();a.start();assert(a.status=='Unavailable')
a.start('198.51.100.8');assert(a.ip=='198.51.100.8')
local current,released,cancelled,requests=nil,{}, {},0
local fetch={available=function()return true end,get=function(_,url,opts)
 assert(url=='https://api.ipify.org'and opts.maxSeconds==4 and opts.accept=='text/plain')
 requests=requests+1;current={status='pending'};return current
end,poll=function(_,h)return h end,release=function(_,h)assert(not released[h]);released[h]=true end,cancel=function(_,h)cancelled[h]=true end}
a=A.new(fetch);a.start();assert(a.status=='Looking up...');local old=current;current.status='ok';current.body='203.0.113.5';a.update(.1);assert(a.ip=='203.0.113.5'and released[old]and not cancelled[old])
a.start();old=current;a.update(11);assert(a.status=='Unavailable'and not a.ip and cancelled[old]and released[old])
a.start();old=current;a.clear();old.status='ok';old.body='203.0.113.8';a.update(.1);assert(not a.ip and cancelled[old]and released[old])
a.start();old=current;a.start();assert(cancelled[old]and released[old]);old=current;current.status='error';a.update(.1);assert(a.status=='Unavailable'and released[old])
a.start();old=current;current.status='ok';current.body=string.rep('1',65);a.update(.1);assert(not a.ip and a.status=='Unavailable'and released[old])
fetch.available=function()error('network denied')end;a.start();assert(a.status=='Unavailable')
assert(requests==6)
print('PASS public fetch HTTPS, unavailable fallback, bounded result, timeout/restart/cancel/release and stale isolation; no raw threads')
