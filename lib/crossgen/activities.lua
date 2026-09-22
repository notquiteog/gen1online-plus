-- Consent and capability negotiation for a nearby trainer. An activity closes
-- only its virtual link; the world and chat socket survive the battle/trade.
return function(S,adapter,send)
  local A={serial=0,elapsed=0}
  local function capabilities()return adapter.capabilities and adapter.capabilities()or{}end
  local function packet(kind,p)
    p=p or {};p.type='world_activity';p.kind=kind;p.session=S.session;return p
  end
  local function near()
    local p=adapter.position();local q=S.peers.remote
    return p and q and p.map==q.map and math.abs(p.x-q.x)+math.abs(p.y-q.y)<=1,p,q
  end
  local function finishBoth()
    local a=S.activity
    if not a or not(a.localDone and a.peerDone)then return end
    if adapter.closeActivity then adapter.closeActivity()end
    if S.channels[a.id]then S.channels[a.id]:close()end
    S.lastActivity={mode=a.mode,result=a.result,peerResult=a.peerResult}
    S.activity=nil
  end
  local function completed(result)
    local a=S.activity;if not a or a.localDone then return end
    a.localDone=true;a.result=tostring(result or 'finished')
    send(packet('done',{id=a.id,result=a.result}));finishBoth()
  end
  local function begin()
    local a=S.activity;if not a then return end
    a.status='active';A.elapsed=0
    if S.ui then S.ui.close()end
    local ok,why=adapter.startActivity(a.mode,S.channel(a.id),S.host,function(result)
      -- A native trade animation may finish after its room disconnected.
      -- Its callback must never complete a new room's unrelated invitation.
      if S.activity==a then completed(result)end
    end)
    if not ok then S.notice=tostring(why);completed('error')end
  end
  function S.invite(mode)
    if not S.connected or S.activity then return false,'Already busy or disconnected' end
    if not capabilities()[mode] or not(S.peerCapabilities or {})[mode] then return false,'Both players need support for this activity' end
    local nearby,p,q=near()
    if not nearby then return false,'Walk next to the other trainer' end
    if p.busy or q.busy then return false,'A trainer is busy' end
    A.serial=A.serial+1
    local id=(S.host and 'host' or 'guest')..':'..A.serial
    S.activity={id=id,mode=mode,status='waiting'};S.channel(id);A.elapsed=0
    send(packet('invite',{id=id,mode=mode}));return true
  end
  function S.respond(accept)
    local a=S.activity
    if not a or a.status~='incoming'then return false,'No invitation' end
    local nearby,p=near()
    if not accept or not nearby or (p and p.busy) then
      send(packet('decline',{id=a.id}));S.channel(a.id):close();S.activity=nil;return false
    end
    send(packet('accept',{id=a.id}));begin();return true
  end
  function A.handle(msg)
    if msg.type~='world_activity'then return false end
    if type(msg.id)~='string' or #msg.id>64 then return true end
    if msg.kind=='invite'then
      local nearby,p=near()
      if S.activity or not nearby or not p or p.busy or not capabilities()[msg.mode]
        or not (S.peerCapabilities or {})[msg.mode]then send(packet('decline',{id=msg.id}));return true end
      S.activity={id=msg.id,mode=msg.mode,status='incoming'};S.channel(msg.id);A.elapsed=0
    else
      local a=S.activity;if not a or a.id~=msg.id then return true end
      if msg.kind=='accept' and a.status=='waiting'then begin()
      elseif msg.kind=='decline' and (a.status=='waiting' or a.status=='incoming')then
        S.channel(a.id):close();S.activity=nil;S.notice='Invitation declined'
      elseif msg.kind=='done' and a.status=='active'then
        a.peerDone=true;a.peerResult=tostring(msg.result or 'finished'):sub(1,200);finishBoth()
      end
    end
    return true
  end
  function A.update(dt)
    A.elapsed=A.elapsed+dt
    local a=S.activity
    if a and (a.status=='waiting' or a.status=='incoming')and A.elapsed>30 then
      send(packet('decline',{id=a.id}));S.channel(a.id):close();S.activity=nil;S.notice='Invitation expired'
    end
    if adapter.updateActivity then adapter.updateActivity(dt)end
  end
  function A.disconnect()
    if adapter.abortActivity then adapter.abortActivity()end
    S.activity=nil;S.peerCapabilities={}
  end
  return A
end
