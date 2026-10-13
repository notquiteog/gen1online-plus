local J=dofile('server/json.lua')
local t={name='Pokémon',text='hello\n"world"',sequence=12.25,yes=true,no=false,rows={{x=1},{x=2}}}
local r=assert(J.decode(J.encode(t)));assert(r.name==t.name and r.text==t.text and r.rows[2].x==2 and r.no==false)
assert(J.decode('"\\u00e9"')=='é');assert(J.decode('"\\ud83d\\ude00"')=='😀')
for _,bad in ipairs({'{}garbage','[1,]','{"x":}','01','1.','"\\uXXXX"','"\\ud800"',string.rep('[',65)..string.rep(']',65)})do assert(J.decode(bad)==nil,bad)end
assert(J.decode('{}',1)==nil)
print('PASS standalone JSON wire codec, unicode and malformed/deep/oversized bounds')
