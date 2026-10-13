-- ROM-free server: elected clients simulate ecology, server owns all claims.
-- Re-election is a new lease; old snapshots/validation replies cannot apply.
return function(S,send,world,Sky,members)
 local D={};local owners={};local epoch=0;local pending={};local serial=0;local clock=0;local approved
 local sky=Sky.new({host=true,session=S.session,send=function(peer,msg)send(msg,peer)end,
 canClaim=function()return approved==true end})
 function D.canCatch()return approved==true end
 local function pose(id,domain)
  local p=S.peers[id];if not p then return end
  local out={};for k,v in pairs(p)do out[k]=v end
  if domain=='skies'then out.busy=p.skyBusy==true;out.altitude=(p.ride and p.ride.mode=='fly'and p.ride.height)or p.height or 0 end
  return out
 end
 local function finish(r,allowed)
  approved=allowed==true
  if r.domain=='wilds'then world:handle(r.peer,r.msg,pose(r.peer,r.domain))else sky:handle(r.peer,r.msg,pose(r.peer,r.domain))end
  approved=nil
 end
 function D.refresh(force)
  local ids={};for id,m in pairs(members())do if id~='host'then ids[#ids+1]=id end end;table.sort(ids)
  local nextOwners={}
  for _,id in ipairs(ids)do local c=members()[id].capabilities;for domain,key in pairs({wilds='sharedWilds',skies='sharedSkies'})do if not nextOwners[domain]and c[key]then nextOwners[domain]=id end end end
  local changed=nextOwners.wilds~=owners.wilds or nextOwners.skies~=owners.skies
  if changed or force then
   for key,r in pairs(pending)do finish(r,false);pending[key]=nil end
   owners=nextOwners;epoch=epoch+1;S.ecologyOwners=owners;S.ecologyEpoch=epoch
   send{type='world_delegate',session=S.session,epoch=epoch,owners=owners}
   for map in pairs(world.maps)do world:broadcast(map)end;for map in pairs(sky.maps)do sky:broadcast(map)end
  end
 end
 local function occupied(map)for _,p in pairs(S.peers)do if p.map==map then return true end end end
 function D.handle(msg,peer)
  if msg.type=='world_ecology'then
   if msg.epoch==epoch and owners[msg.domain]==peer and type(msg.map)=='string'and occupied(msg.map)and type(msg.rows)=='table'then
    if msg.domain=='wilds'then world:publish(msg.map,msg.rows)else sky:publish{map=msg.map,spawns=msg.rows}end
   end;return true
  elseif msg.type=='world_validated'then
   local r=pending[msg.request]
   if r and r.owner==peer and msg.epoch==epoch then pending[msg.request]=nil;finish(r,msg.allowed==true)end;return true
  elseif msg.type=='shared_wilds'or msg.type=='shared_skies'then
   local domain=msg.type=='shared_wilds'and'wilds'or'skies';local model=domain=='wilds'and world or sky
   local key=msg.spawn;local state=model.maps[msg.map];local row=state and state.rows[key]
   local needs=domain=='skies'and msg.kind=='claim'or domain=='wilds'and msg.kind=='claim'and type(msg.action)=='table'
   if needs and row and owners[domain]then
    local n=0;for _,r in pairs(pending)do n=n+1;if r.peer==peer then return true end end
    if n>=64 then finish({peer=peer,msg=msg,domain=domain},false);return true end
    serial=serial+1;local id=tostring(serial);local r={owner=owners[domain],peer=peer,msg=msg,domain=domain,time=clock};pending[id]=r
    send({type='world_validate',session=S.session,epoch=epoch,request=id,domain=domain,position=pose(peer,domain),row=row,action=domain=='skies'and{airborne=msg.airborne}or msg.action,map=msg.map},r.owner)
   else finish({peer=peer,msg=msg,domain=domain},false)end
   return true
  end
  return false
 end
 function D.departed(id)sky:disconnect(id);for key,r in pairs(pending)do if r.peer==id then pending[key]=nil end end;D.refresh()end
 function D.update(dt)clock=clock+dt;for key,r in pairs(pending)do if clock-r.time>5 then pending[key]=nil;finish(r,false)end end end
 function D.clear()pending={}end
 return D
end
