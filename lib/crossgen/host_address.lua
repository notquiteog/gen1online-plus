-- Display-only public IPv4 discovery through the engine-owned HTTP worker.
-- No player/save data is sent; unavailable networking never prevents hosting.
local M={}
function M.ipv4(value)
 if type(value)~='string'or #value>64 then return end
 value=value:match('^%s*(.-)%s*$')
 if not value:match('^%d+%.%d+%.%d+%.%d+$')then return end
 for part in value:gmatch('%d+')do if #part>3 or tonumber(part)>255 then return end end
 return value
end
function M.new(fetch)
 local A={};local handle,age
 local function release(cancel)
  local old=handle;handle=nil
  if old then
   if cancel then pcall(fetch.cancel,fetch,old)end
   pcall(fetch.release,fetch,old)
  end
 end
 function A.clear()release(true);age=0;A.ip=nil;A.status=nil end
 function A.start(override)
  A.clear();A.ip=M.ipv4(override)
  if A.ip then return end
  A.status='Unavailable'
  local ok=pcall(function()
   if not(fetch and fetch:available())then return end
   handle=fetch:get('https://api.ipify.org',{maxSeconds=4,accept='text/plain'})
  end)
  if ok and handle then A.status='Looking up...'else release(true)end
 end
 function A.update(dt)
  if not handle then return end
  age=age+(dt or 0)
  local ok,value=pcall(fetch.poll,fetch,handle)
  if not ok or type(value)~='table'then A.status='Unavailable';release(true)
  elseif value.status=='ok'then A.ip=M.ipv4(value.body);A.status=A.ip and nil or'Unavailable';release(false)
  elseif value.status~='pending'or age>10 then A.status='Unavailable';release(true)end
 end
 return A
end
return M
