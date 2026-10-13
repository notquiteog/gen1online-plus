-- Small standalone wire codec. Deliberately bounded; no executable decoding.
local J={}
function J.encode(value)
 local seen={}
 local function enc(v,depth)
  assert(depth<64,'JSON depth');local t=type(v)
  if t=='nil'then return'null'elseif t=='boolean'then return tostring(v)
  elseif t=='number'then assert(v==v and math.abs(v)<math.huge,'JSON number');return string.format('%.17g',v)
  elseif t=='string'then return'"'..v:gsub('[%z\1-\31\\"]',function(c)return c=='"'and'\\"'or c=='\\'and'\\\\'or string.format('\\u%04x',c:byte())end)..'"'
  elseif t=='table'then
   assert(not seen[v],'JSON cycle');seen[v]=true;local out={};local array=#v>0
   if array then for k in pairs(v)do if type(k)~='number'or k%1~=0 or k<1 or k>#v then array=false;break end end end
   if array then for i=1,#v do out[i]=enc(v[i],depth+1)end
   else for k,x in pairs(v)do assert(type(k)=='string','JSON key');out[#out+1]=enc(k,depth+1)..':'..enc(x,depth+1)end end
   seen[v]=nil;return(array and'['or'{')..table.concat(out,',')..(array and']'or'}')
  end;error('JSON type')
 end
 return enc(value,0)
end
function J.decode(s,max)
 if type(s)~='string'or #s>(max or 262144)then return end
 local i,nodes=1,0
 local function ws()local _,last=s:find('^[ \t\r\n]*',i);i=(last or i-1)+1 end
 local function stringValue()
  assert(s:sub(i,i)=='"');i=i+1;local out={}
  while i<=#s do
   local c=s:sub(i,i);i=i+1
   if c=='"'then return table.concat(out)end
   if c=='\\'then
    c=s:sub(i,i);i=i+1;local escapes={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
    if c=='u'then
     local hex=s:sub(i,i+3);assert(hex:match('^%x%x%x%x$'),'JSON unicode');local code=tonumber(hex,16);i=i+4
     if code>=0xd800 and code<=0xdbff then
      assert(s:sub(i,i+1)=='\\u','JSON surrogate');local low=tonumber(s:sub(i+2,i+5),16);assert(low and low>=0xdc00 and low<=0xdfff,'JSON surrogate');i=i+6;code=0x10000+(code-0xd800)*1024+low-0xdc00
     else assert(code<0xdc00 or code>0xdfff,'JSON surrogate')end
     if code<128 then c=string.char(code)elseif code<2048 then c=string.char(192+math.floor(code/64),128+code%64)
     elseif code<65536 then c=string.char(224+math.floor(code/4096),128+math.floor(code/64)%64,128+code%64)
     else c=string.char(240+math.floor(code/262144),128+math.floor(code/4096)%64,128+math.floor(code/64)%64,128+code%64)end
    else c=assert(escapes[c],'JSON escape')end
   else assert(c:byte()>=32,'JSON control')end
   out[#out+1]=c
  end;error('JSON unterminated string')
 end
 local parse
 parse=function(depth)
  nodes=nodes+1;assert(depth<64 and nodes<=32768,'JSON bounds');ws();local c=s:sub(i,i)
  if c=='"'then return stringValue()
  elseif c=='{'or c=='['then
   i=i+1;local object=c=='{';local close=object and'}'or']';local out={};local index=0;ws();if s:sub(i,i)==close then i=i+1;return out end
   while true do
    ws();local key;if object then key=stringValue();ws();assert(s:sub(i,i)==':','JSON colon');i=i+1 else index=index+1;key=index end
    out[key]=parse(depth+1);ws();local nextChar=s:sub(i,i);i=i+1
    if nextChar==close then return out end;assert(nextChar==',','JSON comma')
   end
  elseif s:sub(i,i+3)=='true'then i=i+4;return true
  elseif s:sub(i,i+4)=='false'then i=i+5;return false
  elseif s:sub(i,i+3)=='null'then i=i+4;return nil
  else
   local number=s:match('^-?%d+%.?%d*[eE][+-]?%d+',i)or s:match('^-?%d+%.?%d*',i)
   assert(number and not number:match('^-?0%d')and not number:match('%.$'),'JSON number');local v=tonumber(number);assert(v and v==v and math.abs(v)<math.huge,'JSON number');i=i+#number;return v
  end
 end
 local ok,value=pcall(function()local v=parse(0);ws();assert(i>#s,'JSON suffix');return v end)
 if ok then return value end
 return nil,value
end
return J
