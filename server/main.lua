-- Headless host: no engine, ROM, account, renderer or player save is loaded.
local root=assert(os.getenv('ONLINE_ROOT'),'Use server/run.sh')
local function loadLocal(path)return dofile(root..'/'..path)end
package.loaded['src.link.Json']=loadLocal('server/json.lua')
package.loaded['src.link.Net']={defaultPort=function()return 7777 end,lanIP=function()return '0.0.0.0'end}
local room,commands
function love.load(args)
 local game=args[1]or'crystal';local generation=({red=1,blue=1,yellow=1,gold=2,silver=2,crystal=2,firered=3,leafgreen=3,ruby=3,sapphire=3,emerald=3})[game]
 assert(generation,'Unsupported game: '..tostring(game))
 local adapter={game=game,generation=generation,dedicated=true,serverName=os.getenv('ONLINE_SERVER_NAME')or'ONLINE SERVER',position=function()end,capabilities=function()return{}end}
 room=loadLocal('lib/crossgen/session.lua')({hooks={wrap=function()end}},loadLocal,adapter)
 local ok,why=room.hostLan(tonumber(args[2])or 7777,tonumber(args[3])or 64);assert(ok,why)
 print('Online+ dedicated '..game..' UDP '..tostring(args[2]or 7777)..'; commands: list, kick ID, stop');io.stdout:flush()
 commands=love.thread.getChannel('admin')
 love.thread.newThread([[
local c=love.thread.getChannel('admin');
for line in io.lines()do c:push(line);if line=='stop'or line=='quit'then break end end]]):start()
end
function love.update(dt)
 room.update(dt)
 while true do
  local line=commands:pop();if not line then break end
  if line=='list'then for _,p in ipairs(room.roster())do print(p.id,p.name,p.map or 'joining')end
  elseif line=='stop'or line=='quit'then room.disconnect();love.event.quit();return
  else local id=line:match('^kick%s+(p%d+)$');if id then local ok,why=room.kick(id);print(ok and('Removed '..id)or why)end end
  io.stdout:flush()
 end
 if not room.connected then print(room.notice or 'Room closed');love.event.quit(1)end
 love.timer.sleep(.005)
end
function love.quit()if room then room.disconnect()end end
