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
 function S.read(key)
  local value,code,message=call('read',key)
  if type(value)=='table'and value.__gen1online_scalar_v1==true then return value.value,code,message end
  return value,code,message
 end
 function S.write(key,value)
  -- Storage accepts data-only tables, including for scalar preferences.
  if type(value)~='table'then value={__gen1online_scalar_v1=true,value=value}end
  local ok,code,message=call('write',key,value);return ok==true,code,message
 end
 function S.delete(key)return call('delete',key)end
 return S
end
