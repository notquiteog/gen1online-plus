-- Display-only public IPv4 discovery. Never blocks the game/network loop and
-- never determines whether a room may host. No player or save data is sent.
local M={}
function M.ipv4(value)
 if type(value)~='string' or #value>64 then return end
 value=value:match('^%s*(.-)%s*$')
 if not value:match('^%d+%.%d+%.%d+%.%d+$')then return end
 for part in value:gmatch('%d+')do if #part>3 or tonumber(part)>255 then return end end
 return value
end
local worker=[[
local output=...
local ok,value=pcall(function()
 local secure,http=pcall(require,'ssl.https')
 if not secure then http=require('socket.http')end
 http.TIMEOUT=4
 local body=''
 local _,code=http.request{url=(secure and 'https' or 'http')..'://api.ipify.org',redirect=false,
  sink=function(chunk)if chunk then body=body..chunk;if #body>64 then return nil,'Response too large'end end;return 1 end}
 if tonumber(code)==200 then return body end
end)
output:push(ok and value or '')
]]
function M.new()
 local A={};local channel,thread,age
 function A.clear()channel,thread,age=nil,nil,0;A.ip=nil;A.status=nil end
 function A.start(override)
  A.clear();A.ip=M.ipv4(override)
  if A.ip then return end
  A.status='Unavailable'
  local ok=pcall(function()
   assert(love and love.thread and love.thread.newThread and love.thread.newChannel,'Background networking unavailable')
   channel=love.thread.newChannel();thread=love.thread.newThread(worker);thread:start(channel)
  end)
  if ok then A.status='Looking up...'else channel,thread=nil,nil end
 end
 function A.update(dt)
  if not channel then return end
  age=age+(dt or 0);local value=channel:pop()
  if value~=nil then A.ip=M.ipv4(value);A.status=A.ip and nil or'Unavailable';channel,thread=nil,nil
  elseif age>10 or (thread.getError and thread:getError())then A.status='Unavailable';channel,thread=nil,nil end
 end
 return A
end
return M
