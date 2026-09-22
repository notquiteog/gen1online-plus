-- A small room/chat overlay shared by all generations. Battle and trade menus
-- remain generation-native. It only consumes controls while explicitly open.
return function(mod, session, adapter)
  local UI={open=false,selection=1,text='',mode='menu'}
  local font
  local function game()return mod.world.game end
  local function quietInput()
    local input=game() and game().input
    if input then input.state={};input.pressed={};input.pressQueue={} end
  end
  function UI.close()UI.open=false;adapter.menuBusy=false;quietInput()end
  function UI.show(mode)
    UI.open=true;UI.mode=mode or 'menu';UI.text='';UI.selection=1;adapter.menuBusy=true;quietInput()
  end
  local function rows()
    if session.activity and session.activity.status=='incoming'then return {'ACCEPT INVITATION','DECLINE INVITATION'}end
    if session.connected then
      local list={'CHAT'};local caps=adapter.capabilities and adapter.capabilities()or{}
      for _,choice in ipairs({{'single','SINGLE BATTLE'},{'double','DOUBLE BATTLE'},{'trade','TRADE'}})do
        if caps[choice[1]]and(session.peerCapabilities or{})[choice[1]]then list[#list+1]=choice[2]end
      end
      list[#list+1]='DISCONNECT';list[#list+1]='CLOSE';return list
    end
    return {'HOST ONLINE ROOM','JOIN ONLINE ROOM','HOST LAN','JOIN LAN','CLOSE'}
  end
  local function submit()
    local ok,why
    if UI.mode=='chat'then ok,why=session.say(UI.text)
    elseif UI.mode=='join-online'then ok,why=session.joinOnline(nil,UI.text:upper())
    elseif UI.mode=='join-lan'then ok,why=session.joinLan(UI.text)
    else return end
    if ok then UI.close()else UI.error=why end
  end
  local function choose()
    local row=rows()[UI.selection]
    UI.error=nil
    if row=='ACCEPT INVITATION'then UI.close();session.respond(true)
    elseif row=='DECLINE INVITATION'then UI.close();session.respond(false)
    elseif row=='SINGLE BATTLE'or row=='DOUBLE BATTLE'or row=='TRADE'then
      UI.close();local ok,why=session.invite(row=='SINGLE BATTLE'and'single'or row=='DOUBLE BATTLE'and'double'or'trade')
      if not ok then UI.show();UI.error=why end
    elseif row=='HOST ONLINE ROOM'then local ok,why=session.hostOnline();if not ok then UI.error=why end
    elseif row=='JOIN ONLINE ROOM'then UI.show('join-online')
    elseif row=='HOST LAN'then local ok,why=session.hostLan();if not ok then UI.error=why end
    elseif row=='JOIN LAN'then UI.show('join-lan')
    elseif row=='CHAT'then UI.show('chat')
    elseif row=='DISCONNECT'then session.disconnect();UI.close()
    else UI.close()end
  end
  function UI.textinput(text)
    if not UI.open or UI.mode=='menu' or type(text)~='string'then return false end
    local clean=text:gsub('[%z\1-\31\127]','')
    local limit=UI.mode=='chat' and 240 or 128
    if #UI.text+#clean<=limit then UI.text=UI.text..clean end
    return true
  end
  local boundGame
  local function bind(g)
    if not g or boundGame==g then return end
    boundGame=g
    local previous=g.textinput
    g.textinput=function(self,text,...)
      if UI.textinput(text)then return end
      if previous then return previous(self,text,...)end
    end
  end
  mod.events:on('game.ready',function(ev)bind(ev and ev.game or game())end)
  mod.hooks:wrap('input.step',function(nextFn,g,dt)
    bind(g)
    if session.activity and session.activity.status=='incoming' and not UI.open then UI.show()end
    if UI.open then quietInput()end
    return nextFn(g,dt)
  end)
  mod.hooks:wrap('input.key',function(nextFn,g,ev)
    local key=ev and ev.key
    if ev and ev.phase=='pressed' then
      if key=='f8'then if UI.open then UI.close()else UI.show()end;return end
      if key=='f9'and session.connected then UI.show('chat');return end
      if UI.open then
        if key=='escape'then UI.close()
        elseif key=='return' or key=='kpenter'then if UI.mode=='menu'then choose()else submit()end
        elseif UI.mode=='menu'then
          if key=='up'then UI.selection=(UI.selection-2)%#rows()+1
          elseif key=='down'then UI.selection=UI.selection%#rows()+1 end
        elseif key=='backspace'then UI.text=UI.text:gsub('[%z\1-\127\194-\244][\128-\191]*$','')end
        return
      end
    end
    -- Always let releases clear the underlying physical held-key sources.
    return nextFn(g,ev)
  end)
  mod.hooks:wrap('ui.start_menu.items',function(nextFn,g,items)
    local list=nextFn(g,items) or items
    if type(list)=='table'then list[#list+1]={label='MULTIPLAYER ROOM',onSelect=function()UI.show()end}end
    return list
  end)
  local function bubblePoint(p,v)
    if not p then return end
    local here=adapter.position();if not here or p.map~=here.map or here.busy then return end
    local other=mod.find and mod.find('BATTLE_ART_VOXEL_FORK')
    local art=other and other.exports
    local active=art and art.firered and art.firered.camera and art.firered.camera.active
    if adapter.generation~=3 then
      local ok,P=pcall(require,'src.render.Pipelines')
      active=ok and P and P.level and P.level('voxel')>0
    end
    if active and art and art.lib then
      local R=art.lib.require('Voxel3D');local x,y=R.project(p.px+8,38,p.py+16)
      local w,h=R.size();if x and w>0 and h>0 then return x/w*v.width,y/h*v.height end
      return
    end
    local scale=v.scale or 1
    local g=game();local w=g and (g.world or g.overworld)
    local camera=w and w.camera
    if adapter.generation~=3 and camera and camera.x and camera.y then
      return (v.gameX or 0)+(p.px-camera.x+8)*scale,
        (v.gameY or 0)+(p.py-camera.y-8)*scale
    end
    return (v.gameX or 0)+(v.gameWidth or v.width)/2+(p.px-here.px)*scale,
      (v.gameY or 0)+(v.gameHeight or v.height)/2+(p.py-here.py-24)*scale
  end
  mod.hooks:wrap('render.hud',function(nextFn,g,v)
    nextFn(g,v)
    font=font or love.graphics.newFont(18);font:setFilter('nearest','nearest')
    love.graphics.push('all');love.graphics.origin();love.graphics.setShader();love.graphics.setFont(font)
    local function plate(x,y,w,h)
      love.graphics.setColor(.08,.12,.19,.94);love.graphics.rectangle('fill',x,y,w,h,5,5)
      love.graphics.setColor(.75,.82,.92,1);love.graphics.rectangle('line',x+.5,y+.5,w-1,h-1,5,5)
    end
    if not UI.open then
      local shown,placed={},{}
      for i=#session.chat,1,-1 do
        local msg=session.chat[i];local who=msg.localSender and 'local' or 'remote'
        if msg.age<7 and not shown[who]then
          shown[who]=true
          local p=msg.localSender and adapter.position()or session.peers.remote
          local x,y=bubblePoint(p,v)
          if x and y and x>=0 and x<=v.width and y>=0 and y<=v.height then
            local width=math.min(280,math.max(80,font:getWidth(msg.text)+20))
            local _,lines=font:getWrap(msg.text,width-20);local height=#lines*font:getHeight()+16
            x=math.floor(math.max(4,math.min(v.width-width-4,x-width/2)));y=math.floor(math.max(4,y-height))
            for _,other in ipairs(placed)do
              if x<other.x+other.w+4 and x+width+4>other.x
                and y<other.y+other.h+4 and y+height+4>other.y then
                local above=other.y-height-5
                y=above>=4 and above or other.y+other.h+5
              end
            end
            placed[#placed+1]={x=x,y=y,w=width,h=height}
            plate(x,y,width,height);love.graphics.setColor(1,1,1,1);love.graphics.printf(msg.text,x+10,y+8,width-20,'left')
          end
        end
      end
    else
      local w=math.min(540,v.width-24);local h=UI.mode=='menu'and math.max(310,118+#rows()*32) or 190
      local x,y=math.floor((v.width-w)/2),math.floor((v.height-h)/2)
      plate(x,y,w,h);love.graphics.setColor(1,1,1,1)
      love.graphics.print(UI.mode=='menu' and 'MULTIPLAYER' or UI.mode=='chat' and 'CHAT' or UI.mode=='join-online' and 'ROOM CODE' or 'HOST ADDRESS',x+20,y+16)
      if UI.mode=='menu'then
        for i,label in ipairs(rows())do
          love.graphics.setColor(i==UI.selection and .95 or .72,i==UI.selection and .83 or .78,i==UI.selection and .38 or .86,1)
          love.graphics.print((i==UI.selection and '> 'or '  ')..label,x+20,y+50+(i-1)*32)
        end
        love.graphics.setColor(.85,.9,1,1)
        love.graphics.printf(session.code and ('Room: '..session.code)or session.address and ('Address: '..session.address)or (session.activity and (session.activity.status..': '..session.activity.mode)) or session.status or 'F8: room   F9: chat',x+20,y+h-64,w-40)
      else
        love.graphics.printf(UI.text..'_',x+20,y+52,w-40,'left')
      end
      love.graphics.setColor(.95,.8,.6,1)
      love.graphics.printf(UI.error or session.notice or 'Enter: select/send    Esc: close',x+20,y+h-32,w-40)
    end
    love.graphics.pop()
  end)
  local function nearPeer()
    local p,q=adapter.position(),session.peers.remote
    if not session.connected or not p or p.busy or not q or p.map~=q.map then return false end
    local d=({up={0,-1},down={0,1},left={-1,0},right={1,0}})[p.facing]
    if d and q.x==p.x+d[1]and q.y==p.y+d[2]then UI.show();return true end
    return false
  end
  -- Crystal dispatches the compatibility interaction seam also used by the
  -- follower mod. Compose at that seam so a later follower wrapper preserves
  -- the remote trainer's interaction instead of falling through to NPC text.
  local class=require(adapter.generation==3 and 'src.core.game3.field'
    or 'src.world.OverworldController')
  local interact=class.interact
  class.interact=function(self,...)
    if nearPeer()then return true end
    return interact(self,...)
  end
  session.ui=UI
  return UI
end
