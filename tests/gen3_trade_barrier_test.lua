local Barrier=dofile('lib/gen3/trade_barrier.lua')
local function pair()
 local h,g={inbox={}},{inbox={}}
 for _,v in ipairs{h,g}do function v:poll()local q=self.inbox;self.inbox={};return q end end
 function h:send(m)if self.closed then return false end;g.inbox[#g.inbox+1]=m;return true end
 function g:send(m)if self.closed then return false end;h.inbox[#h.inbox+1]=m;return true end
 Barrier.wrap(h,true);assert(Barrier.wrap(g,false)==g);return h,g
end
local a,b=string.rep('a',16),string.rep('b',16)
for _,reverse in ipairs{false,true}do
 local h,g=pair()
 local first,second=reverse and g or h,reverse and h or g
 assert(first:send{type='game3_trade_confirm',digest=a});h:poll()
 assert(second:send{type='game3_trade_confirm',digest=a})
 local hp=h:poll();local gp=g:poll();local hc,gc=0,0
 for _,m in ipairs(hp)do if m.type=='trade_commit'then hc=hc+1;assert(m.digests[1]==a and m.digests[2]==a)end end
 for _,m in ipairs(gp)do if m.type=='trade_commit'then gc=gc+1 end end
 assert(hc==1 and gc==1,'both peers need one decision')
 g:send{type='game3_trade_confirm',digest=a};h:send{type='game3_trade_confirm',digest=a}
 for _,m in ipairs(h:poll())do assert(m.type~='trade_commit')end
 for _,m in ipairs(g:poll())do assert(m.type~='trade_commit')end
end
local h,g=pair();h:send{type='game3_trade_confirm',digest=a};g:send{type='game3_trade_confirm',digest=b}
local aborts=0;for _,m in ipairs(h:poll())do if m.type=='trade_abort'then aborts=aborts+1 end end;assert(aborts==1)
h:send{type='game3_trade_mon'}
h:send{type='game3_trade_confirm',digest=b};g:send{type='game3_trade_confirm',digest=b}
local retried=false;for _,m in ipairs(h:poll())do if m.type=='trade_commit'then assert(m.n==2);retried=true end end;assert(retried,'mismatch retry must work')
h,g=pair();h:send{type='game3_trade_confirm',digest=a};g:send{type='game3_trade_confirm',digest='bad'}
g:send{type='trade_commit',n=9,digests={a,a}}
for _,m in ipairs(h:poll())do assert(m.type~='trade_commit'and m.type~='trade_abort')end
h.closed=true;g:send{type='game3_trade_confirm',digest=a};for _,m in ipairs(h:poll())do assert(m.type~='trade_commit')end
print('PASS native trade barrier ordering, mismatch, malformed/replay/spoof and disconnect')
