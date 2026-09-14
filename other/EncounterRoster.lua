-- A local population lasts for a map visit. Rendering/update frequency must
-- never reroll rarity, species, shiny status or the set of encounter IDs.
local R = {}
local function finite(n)
  return type(n) == 'number' and n == n and n > -math.huge and n < math.huge
end
local function speciesKnown(species, speciesData)
  return type(species) == 'string' and type(speciesData) == 'table'
    and type(speciesData[species]) == 'table'
end
local function slots(rows, speciesData)
  local result = {}
  for _, row in ipairs(type(rows) == 'table' and rows or {}) do
    if type(row) == 'table' and speciesKnown(row.species, speciesData)
        and finite(row.minLevel) and finite(row.maxLevel)
        and row.minLevel >= 1 and row.maxLevel <= 100
        and row.minLevel <= row.maxLevel then
      result[#result + 1] = row
    end
  end
  return result
end
function R.generate(mapId, config, tod, tileCount, speciesData, random)
  local result = {}
  local grass = config.grass or {}
  local common = slots(grass[tod] or grass.DAY or grass.NITE, speciesData)
  local rare = slots(config.rare_ow, speciesData)
  if #common == 0 and #rare == 0 then return result end
  local count = math.min(6, math.max(3, math.floor(tileCount / 4)))
  for idx = 1, count do
    local isRare = #rare > 0 and random(1, 100) <= 15
    local pool = isRare and rare or common
    if #pool > 0 then
      local row = pool[random(1, #pool)]
      result[#result + 1] = {
        id = string.format('local_%s_%d', mapId, idx), species = row.species,
        level = random(math.floor(row.minLevel), math.floor(row.maxLevel)),
        shiny = random(1, isRare and 512 or 8192) == 1,
      }
    end
  end
  return result
end
function R.validTargets(rows, speciesData)
  local result, seen = {}, {}
  for _, row in ipairs(type(rows) == 'table' and rows or {}) do
    if type(row) == 'table' and type(row.id) == 'string' and row.id ~= ''
        and not seen[row.id] and speciesKnown(row.species, speciesData)
        and finite(row.level) and row.level >= 1 and row.level <= 100 then
      seen[row.id] = true
      result[#result + 1] = row
    end
  end
  return result
end
function R.consume(rows, id)
  for i = #(rows or {}), 1, -1 do
    if rows[i].id == id then table.remove(rows, i) end
  end
end
return R
