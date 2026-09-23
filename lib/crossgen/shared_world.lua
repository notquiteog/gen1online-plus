-- A session host owns the visible wild population. Renderers and encounter
-- adapters consume snapshots; clients never submit species, levels or positions.
local M = { PROTOCOL = 1 }
local function finite(n)
  return type(n) == 'number' and n == n and math.abs(n) < 1e7
end
local function token(s)
  return type(s) == 'string' and #s > 0 and #s <= 128
end
local function integer(n) return finite(n) and n % 1 == 0 end
local function copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = type(v) == 'table' and copy(v) or v end
  return out
end
-- Copy only the wire schema; never recursively copy arbitrary remote tables.
local function record(r)
  if type(r) ~= 'table' or not token(r.id) or not finite(r.x) or not finite(r.y)
      or not integer(r.level) or r.level < 1 or r.level > 100 then return end
  if not (token(r.species) or (integer(r.species) and r.species > 0 and r.species < 65536)) then return end
  local out = { id = r.id, species = r.species, level = r.level, x = r.x, y = r.y }
  for _, k in ipairs({'px', 'py', 'phase', 'targetX', 'targetY', 'progress'}) do
    if r[k] ~= nil then if not finite(r[k]) then return end; out[k] = r[k] end
  end
  if r.personality~=nil then
    local pid=r.personality
    if type(pid)~='number' or pid~=pid or pid%1~=0 or pid<0 or pid>4294967295 then return end
    out.personality=pid
  end
  for _, k in ipairs({'terrain', 'surface', 'encounterKind', 'form', 'behavior', 'variant'}) do
    if r[k] ~= nil then if not token(r[k]) then return end; out[k] = r[k] end
  end
  if r.facing ~= nil then
    if r.facing ~= 'up' and r.facing ~= 'down' and r.facing ~= 'left' and r.facing ~= 'right' then return end
    out.facing = r.facing
  end
  out.moving, out.shiny = r.moving == true, r.shiny == true
  out.visibleSprite, out.hiddenEncounter = r.visibleSprite ~= false, r.hiddenEncounter == true
  out.scenery = r.scenery == true
  out.ambient, out.wanders, out.stepFlip = r.ambient == true, r.wanders == true, r.stepFlip == true
  return out
end
M.record = record
function M.new(opts)
  assert(opts and token(opts.session) and type(opts.send) == 'function')
  local W = { host = opts.host == true, session = opts.session, maps = {}, claims = {},
    sequence = 0, received = {}, pending = {}, clock = 0, closed = false }
  local function envelope(kind, map)
    return { type = 'shared_wilds', protocol = M.PROTOCOL, session = W.session, kind = kind, map = map }
  end
  local function claimKey(map, id) return map .. '\0' .. id end
  function W:publish(map, rows)
    if self.closed or not self.host then return false, 'not authority' end
    if not token(map) or type(rows) ~= 'table' or #rows > 128 then return false, 'invalid map' end
    local nextRows = {}
    for _, row in ipairs(rows) do
      local r = record(row)
      if not r or nextRows[r.id] then return false, 'invalid spawn' end
      if not self.claims[claimKey(map, r.id)] then nextRows[r.id] = r end
    end
    local state = self.maps[map] or { revision = 0 }
    state.rows, state.revision = nextRows, state.revision + 1
    self.maps[map] = state
    return self:broadcast(map)
  end
  function W:broadcast(map, peer)
    local state = self.maps[map]
    if self.closed or not self.host or not state then return false end
    local msg = envelope('snapshot', map)
    msg.revision, msg.rows = state.revision, {}
    for _, row in pairs(state.rows) do msg.rows[#msg.rows + 1] = copy(row) end
    table.sort(msg.rows, function(a, b) return a.id < b.id end)
    opts.send(peer, msg)
    return true
  end
  function W:request(map, id, action)
    if self.closed then return nil, 'disconnected' end
    if not token(map) or not token(id) then return nil, 'invalid spawn' end
    for _, p in pairs(self.pending) do
      if p.map == map and p.spawn == id then return nil, 'claim pending' end
    end
    local request
    if action ~= nil then
      if type(action) ~= 'table' or action.action ~= 'catch' or not integer(action.ballId)
          or action.ballId < 1 or action.ballId > 65535 or not finite(action.charge or 0) then return nil, 'invalid action' end
      request = {action='catch',ballId=action.ballId,charge=math.max(0,math.min(1,action.charge or 0))}
    end
    self.sequence = self.sequence + 1
    local msg = envelope('claim', map)
    msg.spawn, msg.request, msg.action = id, self.sequence, request
    self.pending[msg.request] = {map = map, spawn = id, time = self.clock, action=request}
    opts.send(nil, msg)
    return self.sequence
  end
  local function restore(claim, key)
    W.claims[key] = nil
    local state = W.maps[claim.map]
    state.rows[claim.row.id] = claim.row
    state.revision = state.revision + 1
    -- Replaying a released/expired claim must never grant it again.
    local reply = envelope('deny', claim.map)
    reply.request, reply.reason = claim.request, 'claim released'
    W.received[claim.peer] = W.received[claim.peer] or {}
    W.received[claim.peer][claim.request] = reply
    W:broadcast(claim.map)
  end
  function W:handle(peer, msg, position, isHost)
    if self.closed or type(msg) ~= 'table' or msg.type ~= 'shared_wilds'
        or msg.protocol ~= M.PROTOCOL or msg.session ~= self.session then return false, 'wrong session' end
    if not token(msg.map) then return false, 'invalid map' end
    if not self.host then
      if not isHost then return false, 'not authority' end
      if msg.kind == 'snapshot' then
        if not integer(msg.revision) or msg.revision < 1 or type(msg.rows) ~= 'table' or #msg.rows > 128 then return false, 'invalid snapshot' end
        local old = self.maps[msg.map]
        if old and msg.revision <= old.revision then return false, 'stale' end
        local rows, list = {}, {}
        for _, row in ipairs(msg.rows) do
          local r = record(row)
          if not r or rows[r.id] then return false, 'invalid spawn' end
          rows[r.id], list[#list + 1] = r, r
        end
        self.maps[msg.map] = { revision = msg.revision, rows = rows }
        if opts.onSnapshot then opts.onSnapshot(msg.map, list) end
        return true
      elseif msg.kind == 'grant' or msg.kind == 'deny' then
        if not integer(msg.request) then return false, 'invalid request' end
        local p = self.pending[msg.request]
        if not p or p.map ~= msg.map then return false, 'no pending claim' end
        if msg.kind == 'deny' then
          self.pending[msg.request] = nil
          if opts.onDenied then opts.onDenied(msg.reason,p.map,p.spawn) end
          return true
        end
        local r = record(msg.row)
        if not r or r.id ~= p.spawn then return false, 'invalid grant' end
        self.pending[msg.request] = nil -- Consume before calling native battle.
        local catcher = p.action and p.action.action == 'catch'
        local callback = catcher and opts.onCatch or opts.onEncounter
        local ran, ok, why = pcall(callback or function() return false end, r, msg.map, p.action)
        local consumed = ran and ok == true and (not catcher or type(why)=='table' and why.caught==true)
        local reply = envelope(consumed and 'commit' or 'release', msg.map)
        reply.request, reply.spawn = msg.request, r.id
        opts.send(nil, reply)
        return ran and ok == true, ran and why or ok
      end
      return false, 'unknown packet'
    end
    if msg.kind == 'subscribe' then return self:broadcast(msg.map, peer) end
    if msg.kind == 'claim' then
      if not integer(msg.request) or msg.request < 1 or not token(msg.spawn) then return false, 'invalid request' end
      self.received[peer] = self.received[peer] or {}
      local cache = self.received[peer]
      if cache[msg.request] then opts.send(peer, copy(cache[msg.request])); return true end
      local state = self.maps[msg.map]
      local row = state and state.rows[msg.spawn]
      local reason
      local action=msg.action
      local catching=type(action)=='table' and action.action=='catch'
      local validAction=action==nil or catching and integer(action.ballId) and action.ballId>=1 and action.ballId<=65535
        and finite(action.charge) and action.charge>=0 and action.charge<=1
      local range=catching and validAction and 2+math.floor(action.charge*4) or 1
      if not validAction then reason='invalid action'
      elseif not position or position.map ~= msg.map or not finite(position.x) or not finite(position.y) then reason = 'different map'
      elseif position.busy then reason = 'player busy'
      elseif not row then reason = 'already claimed'
      elseif row.ambient or row.scenery then reason = 'not a wild encounter'
      elseif math.abs(position.x - row.x) + math.abs(position.y - row.y) > range then reason = 'too far'
      elseif catching and position.x~=row.x and position.y~=row.y then reason='not in throw line'
      elseif catching and opts.canCatch and not opts.canCatch(position,row,action,msg.map) then reason='blocked throw' end
      local reply = envelope(reason and 'deny' or 'grant', msg.map)
      reply.request, reply.reason = msg.request, reason
      if not reason then
        reply.row = copy(row)
        state.rows[msg.spawn], state.revision = nil, state.revision + 1
        self.claims[claimKey(msg.map, msg.spawn)] = {peer = peer, request = msg.request, map = msg.map, row = copy(row), time = self.clock}
        self:broadcast(msg.map) -- Remove everywhere before granting once.
      end
      cache[msg.request] = copy(reply)
      opts.send(peer, reply)
      return reason == nil, reason
    elseif msg.kind == 'commit' or msg.kind == 'release' then
      if not token(msg.spawn) then return false, 'invalid spawn' end
      local key = claimKey(msg.map, msg.spawn)
      local claim = self.claims[key]
      if not claim or claim.peer ~= peer or claim.request ~= msg.request or claim.committed then return false, 'not claim owner' end
      if msg.kind == 'release' then restore(claim, key) else claim.committed = true end
      return true
    end
    return false, 'unknown packet'
  end
  function W:update(dt)
    self.clock = self.clock + math.max(0, tonumber(dt) or 0)
    -- Reliable ordered transport must acknowledge a grant before a later
    -- heartbeat. An unacknowledged grant is NOT recycled on a timer: a slow
    -- client may already have opened its battle. Disconnect ends that epoch.
  end
  function W:disconnect(peer)
    if not self.host then self.closed = true; self.maps = {}; self.pending = {}; return end
    for key, claim in pairs(self.claims) do
      if claim.peer == peer and not claim.committed then restore(claim, key) end
    end
    self.received[peer] = nil
  end
  return W
end
return M
