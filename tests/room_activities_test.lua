local make=dofile('lib/crossgen/activities.lua')
local S={connected=true,host=true,session='one',peers={remote={map='town',x=1,y=0}},
 peerCapabilities={single=true},channels={}}
function S.channel(id)
 if not S.channels[id]then S.channels[id]={close=function()S.channels[id]=nil end}end
 return S.channels[id]
end
local sent,callbacks,closed={},{},0
local adapter={position=function()return {map='town',x=0,y=0}end,
 capabilities=function()return {single=true}end,
 startActivity=function(_,_,_,done)callbacks[#callbacks+1]=done;return true end,
 closeActivity=function()closed=closed+1 end}
local A=make(S,adapter,function(msg)sent[#sent+1]=msg end)
assert(S.invite('single'));local first=S.activity
A.handle{type='world_activity',kind='accept',id=first.id}
callbacks[1]('win');assert(S.activity==first,'local completion must keep peer channel alive')
A.handle{type='world_activity',kind='done',id=first.id,result='lose'}
assert(not S.activity and closed==1);assert(S.lastActivity.result=='win'and S.lastActivity.peerResult=='lose')
assert(S.invite('single'));local cancelled=S.activity
A.handle{type='world_activity',kind='accept',id=cancelled.id}
A.disconnect();S.peerCapabilities={single=true};S.session='two'
assert(S.invite('single'));local nextActivity=S.activity
A.handle{type='world_activity',kind='accept',id=nextActivity.id}
callbacks[2]('old animation finished')
assert(S.activity==nextActivity and not nextActivity.localDone,'old callback completed a new activity')
callbacks[3]('draw');A.handle{type='world_activity',kind='done',id=nextActivity.id,result='draw'}
assert(not S.activity and closed==2)
assert(not S.invite('double'),'missing optional double support must not advertise or start doubles')
print('PASS paired completion, channel retention, reconnect callback isolation, optional capability gate')
