-- A small room/chat overlay shared by all generations. Battle and trade menus
-- remain generation-native. It only consumes controls while explicitly open.
return function(mod, session, adapter)
  local UI={open=false,selection=1,text='',mode='menu'}
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
    if type(list)=='table'then list[#list+1]={label='ONLINE',onSelect=function()UI.show()end}end
    return list
  end)
  local function bubblePoint(p,v)
    if not p then return end
    local here=adapter.position();if not here or p.map~=here.map or here.busy then return end
    local other=mod.find and mod.find('BATTLE_ART_VOXEL_FORK')
    local art=other and other.exports
    local scene=art and (art.gen3 or art.firered)
    local active=scene and scene.camera and scene.camera.active
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
    if not UI.open and #session.chat==0 then return end
    local gen3=adapter.generation==3
    local Font=require(gen3 and 'src.ui.game3.font' or 'src.render.Font')
    local Window=gen3 and require('src.ui.game3.window')or nil
    local width,height=gen3 and 240 or 160,gen3 and 160 or 144
    local pitch=gen3 and 16 or 12
    local scale=math.max(1,math.floor(math.min(v.width/width,v.height/height)))
    local ox,oy=math.floor((v.width-width*scale)/2),math.floor((v.height-height*scale)/2)
    local gfx=love.graphics;gfx.push('all')
    local ok,err=pcall(function()
      gfx.origin();gfx.setShader();gfx.translate(ox,oy);gfx.scale(scale);gfx.setColor(1,1,1,1)
      local function measure(t)return gen3 and Font.measure(t)or Font.width(t)end
      local function text(t,x,y,w)
        if gen3 then Font.draw(t,x,y,{maxWidth=w,colors=Font.COLOR.NORMAL})else Font.draw(t,x,y)end
      end
      local function plate(x,y,w,h)
        if gen3 then local tpl=Window.template(x/8,y/8,w/8,h/8);Window.fill(tpl);Window.stdFrame(tpl)
        else
          gfx.push();gfx.translate(x,y);Font.drawBox(0,0,math.ceil(w/8),math.ceil(h/8));gfx.pop()
        end
      end
      -- Preserve message text/network payload. Wrap only its visual copy using
      -- the active game font, including fonts supplied by translation mods.
      local function lines(value,maxWidth)
        local out,line={},''
        for ch in tostring(value or ''):gmatch('[%z\1-\127\194-\244][\128-\191]*')do
          if ch=='\n' then out[#out+1]=line;line=''
          else
            if line~=''and measure(line..ch)>maxWidth then out[#out+1]=line;line=''end
            line=line..ch
          end
        end
        out[#out+1]=line;return out
      end
      local function block(value,x,y,w,count,tail)
        local list=lines(value,w);local first=tail and math.max(1,#list-count+1)or 1
        for i=first,math.min(#list,first+count-1)do text(list[i],x,y+(i-first)*pitch,w)end
      end
      if UI.open then
        plate(8,8,width-16,height-16)
        text(UI.mode=='menu'and'MULTIPLAYER'or UI.mode=='chat'and'CHAT'or UI.mode=='join-online'and'ROOM CODE'or'HOST ADDRESS',16,16,width-32)
        if UI.mode=='menu'then
          local list=rows();local count=math.max(1,math.floor((height-76)/pitch))
          local first=math.max(1,UI.selection-count+1)
          for i=first,math.min(#list,first+count-1)do
            local y=34+(i-first)*pitch
            if i==UI.selection then
              if gen3 then Window.cursorPx(16,y)else Font.drawCode(require('src.ui.Theme').cursor,16,y)end
            end
            local label=({['HOST ONLINE ROOM']='HOST ONLINE',['JOIN ONLINE ROOM']='JOIN ONLINE',['ACCEPT INVITATION']='ACCEPT',['DECLINE INVITATION']='DECLINE'})[list[i]]or list[i]
            block(label,26,y,width-42,1)
          end
          block(session.code and('Room: '..session.code)or session.address and('Address: '..session.address)or session.status or'F8/F9: chat',16,height-40,width-32,1)
        else block(UI.text..'-',16,38,width-32,math.max(1,math.floor((height-82)/pitch)),true)end
        block(UI.error or session.notice or'ENTER OK  ESC X',16,height-24,width-32,1)
      else
        local shown,placed={},{}
        for i=#session.chat,1,-1 do
          local msg=session.chat[i];local who=msg.localSender and'local'or'remote'
          if msg.age<7 and not shown[who]then
            shown[who]=true
            local p=msg.localSender and adapter.position()or session.peers.remote
            local x,y=bubblePoint(p,v)
            if x and y and x>=0 and x<=v.width and y>=0 and y<=v.height then
              x,y=(x-ox)/scale,(y-oy)/scale
              local w=math.min(width-16,math.max(64,math.ceil((measure(msg.text)+16)/8)*8))
              local count=math.min(3,#lines(msg.text,w-16));local h=math.ceil((count*pitch+16)/8)*8
              x=math.floor(math.max(8,math.min(width-w-8,x-w/2)));y=math.floor(math.max(8,math.min(height-h-8,y-h)))
              for _,other in ipairs(placed)do
                if x<other.x+other.w and x+w>other.x and y<other.y+other.h and y+h>other.y then
                  y=other.y-h-4
                  if y<8 then y=math.min(height-h-8,other.y+other.h+4)end
                end
              end
              placed[#placed+1]={x=x,y=y,w=w,h=h}
              plate(x,y,w,h);block(msg.text,x+8,y+8,w-16,count)
            end
          end
        end
      end
    end)
    gfx.pop();if not ok then error(err,0)end
  end)
  local function nearPeer()
    local p,q=adapter.position(),session.peers.remote
    if session.activity or not session.connected or not p or p.busy or not q or p.map~=q.map then return false end
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
