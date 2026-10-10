-- Optional LAN discovery. ENet remains the game transport; replies only name
-- an available host. No save, player-position or chat data is broadcast.
local M={PORT=7776}
function M.new(game,generation,socket)
 if not socket then local ok,s=pcall(require,'socket');if ok then socket=s end end
 local D={hosts={},clock=0,elapsed=2}
 local udp,advertised,scanning
 local function close()if udp then udp:close();udp=nil end end
 local function open(host)
  close()
  if not socket or not socket.udp then return nil,'LAN discovery unavailable; use DIRECT ADDRESS' end
  local s,err=socket.udp();if not s then return nil,err end
  s:settimeout(0);pcall(s.setoption,s,'reuseaddr',true);pcall(s.setoption,s,'broadcast',true)
  local ok,why=s:setsockname('*',host and M.PORT or 0)
  if not ok then s:close();return nil,'LAN scan unavailable; use DIRECT ADDRESS ('..tostring(why)..')' end
  udp=s;return true
 end
 local prefix='G1ONLINE_LAN_1\t'..tostring(generation)..'\t'..tostring(game)..'\t'
 function D.host(port,name)
  D.stop();local ok,err=open(true);if not ok then return nil,err end
  advertised={port=port,name=tostring(name or 'TRAINER'):gsub('[^%w _%-]',''):sub(1,20)}
  return true
 end
 function D.scan()
  D.stop();local ok,err=open(false);if not ok then return nil,err end
  scanning=true;D.elapsed=2;return true
 end
 function D.stop()close();advertised=nil;scanning=false;D.hosts={}end
 function D.list()
  local rows={};for _,row in pairs(D.hosts)do rows[#rows+1]=row end
  table.sort(rows,function(a,b)return a.address<b.address end);return rows
 end
 function D.update(dt,available)
  D.clock=D.clock+dt;D.elapsed=D.elapsed+dt
  if not udp then return end
  if scanning and D.elapsed>=2 then
   D.elapsed=0
   udp:sendto(prefix..'QUERY','255.255.255.255',M.PORT)
   udp:sendto(prefix..'QUERY','127.0.0.1',M.PORT)
  end
  for _=1,32 do
   local data,ip,port=udp:receivefrom(512);if not data then break end
   if data:sub(1,#prefix)==prefix then
    local body=data:sub(#prefix+1)
    if advertised and available and body=='QUERY' then
     udp:sendto(prefix..'HOST\t'..advertised.port..'\t'..advertised.name,ip,port)
    elseif scanning then
     local p,name=body:match('^HOST\t(%d+)\t([%w _%-]*)$');p=tonumber(p)
     if p and p>=1 and p<=65535 and ip:match('^%d+%.%d+%.%d+%.%d+$')then
      local address=ip..':'..p
      if D.hosts[address]or #D.list()<64 then D.hosts[address]={address=address,name=name:sub(1,20),seen=D.clock}end
     end
    end
   end
  end
  for key,row in pairs(D.hosts)do if D.clock-row.seen>6 then D.hosts[key]=nil end end
 end
 return D
end
return M
