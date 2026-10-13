function love.conf(t)
 t.identity='gen1online-dedicated';t.window=false;t.audio=false
 for _,name in ipairs({'audio','graphics','image','joystick','keyboard','mouse','physics','sound','touch','video'})do t.modules[name]=false end
end
