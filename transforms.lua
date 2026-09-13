-- Generate per-instance shiny art from the player's imported cache. The mod
-- ships this recipe, never ROM-derived pixels.
local SPECIES = {
  "abra", "kadabra", "alakazam", "clefairy", "wigglytuff", "nidorina", "nidoqueen",
  "nidorino", "nidoking", "dratini", "dragonair", "dragonite", "porygon",
  "bulbasaur", "ivysaur", "venusaur", "charmander", "charmeleon", "charizard",
  "squirtle", "wartortle", "blastoise", "omanyte", "omastar", "kabuto",
  "kabutops", "aerodactyl", "sandshrew", "sandslash", "vulpix", "ninetales",
  "meowth", "persian", "bellsprout", "weepinbell", "victreebel", "pinsir",
  "magmar", "ekans", "arbok", "oddish", "gloom", "vileplume", "mankey",
  "primeape", "growlithe", "arcanine", "scyther", "electabuzz",
}

local GOLD = {
  { 248, 248, 224 },
  { 248, 216, 88 },
  { 208, 120, 32 },
  { 64, 32, 64 },
}

local MACHINE_COLORS = {
  outline = { 0.05, 0.04, 0.07, 1 },
  bodyDark = { 0.18, 0.11, 0.22, 1 },
  body = { 0.42, 0.23, 0.42, 1 },
  trim = { 0.94, 0.68, 0.19, 1 },
  screen = { 0.03, 0.16, 0.20, 1 },
  green = { 0.18, 0.76, 0.26, 1 },
  blue = { 0.18, 0.56, 0.76, 1 },
  red = { 0.78, 0.14, 0.20, 1 },
  paper = { 0.95, 0.91, 0.70, 1 },
}

local function pixel(image, x, y, c)
  if x >= 0 and y >= 0 and x < image:getWidth() and y < image:getHeight() then
    image:setPixel(x, y, c[1], c[2], c[3], c[4])
  end
end

local function fill(image, x, y, width, height, c)
  for py = y, y + height - 1 do
    for px = x, x + width - 1 do pixel(image, px, py, c) end
  end
end

local function circle(image, cx, cy, radius, c)
  for y = -radius, radius do
    for x = -radius, radius do
      if x * x + y * y <= radius * radius then pixel(image, cx + x, cy + y, c) end
    end
  end
end

local function buildMachine(ctx, id, c)
  local image = ctx.blank(16, 32, 0, 0, 0, 0)
  fill(image, 1, 0, 14, 30, c.outline)
  fill(image, 2, 1, 12, 28, c.bodyDark)
  fill(image, 3, 2, 10, 26, c.body)
  fill(image, 2, 2, 12, 3, c.trim)
  fill(image, 3, 6, 10, 10, c.outline)
  fill(image, 4, 7, 8, 8, c.screen)
  if id == "crash" then
    pixel(image, 5, 13, c.green); pixel(image, 6, 12, c.green)
    pixel(image, 7, 11, c.green); pixel(image, 8, 9, c.green)
    pixel(image, 9, 8, c.green); pixel(image, 10, 8, c.red)
  elseif id == "flappy" then
    fill(image, 5, 7, 2, 3, c.green); fill(image, 5, 13, 2, 2, c.green)
    fill(image, 10, 7, 2, 5, c.green); fill(image, 10, 14, 2, 1, c.green)
    fill(image, 7, 10, 3, 2, c.trim); pixel(image, 9, 10, c.paper)
  else
    for x = 4, 11, 3 do fill(image, x, 8, 2, 5, x == 10 and c.trim or c.paper) end
    fill(image, 4, 14, 8, 1, c.red)
  end
  fill(image, 4, 18, 8, 3, c.outline)
  fill(image, 5, 18, 3, 2, c.trim)
  circle(image, 10, 19, 1, c.red)
  fill(image, 3, 23, 10, 2, c.outline)
  fill(image, 5, 24, 6, 2, c.paper)
  fill(image, 2, 28, 12, 3, c.outline)
  for piece = 0, 1 do
    local part = ctx.blank(16, 16, 0, 0, 0, 0)
    ctx.blit(part, image, 0, 0, 0, piece * 16, 16, 16)
    ctx.writeImage(part, ("world/%s_machine_%02d.png"):format(id, piece + 1))
  end
end

return function(ctx)
  for _, species in ipairs(SPECIES) do
    local paths = {
      "battle/front/" .. species .. ".png",
      "battle/back/" .. species .. "b.png",
    }
    for _, source in ipairs(paths) do
      if ctx.exists(source) then
        ctx.writeImage(ctx.recolor(ctx.readImage(source), GOLD), "shiny/" .. source)
      end
    end
  end
  buildMachine(ctx, "crash", MACHINE_COLORS)
  buildMachine(ctx, "flappy", MACHINE_COLORS)
  buildMachine(ctx, "case", MACHINE_COLORS)
end
