function love.load()
 local ok,why=xpcall(function()dofile(assert(os.getenv('ONLINE_ROOT'))..'/tests/multi_room_test.lua')end,debug.traceback)
 if not ok then io.stderr:write(why..'\n')end
 love.event.quit(ok and 0 or 1)
end
