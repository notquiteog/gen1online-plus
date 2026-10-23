-- One live playthrough scope for room preferences and legacy GTS saves.
return function(mod)
 local S={}
 local function call(method,key,...)
  local game=mod.game
  local storage=mod.storage
  if not(game and storage and type(storage[method])=='function')then return nil,'storage_unavailable'end
  key=tostring(key or ''):gsub('%.lua.*$','')
  local ok,value,code,message=pcall(storage[method],storage,game,key,...)
  if not ok then return nil,'storage_error',tostring(value)end
  return value,code,message
 end
 function S.read(key)return call('read',key)end
 function S.write(key,value)local ok,code,message=call('write',key,value);return ok==true,code,message end
 function S.delete(key)return call('delete',key)end
 return S
end
