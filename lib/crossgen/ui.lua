-- A small room/chat overlay shared by all generations. Battle and trade menus
-- remain generation-native. It only consumes controls while explicitly open.
return function(mod, session, adapter)
  local UI={open=false,selection=1,text='',mode='menu'}
  local saved={}
  if mod.storage and mod.storage.read then
    local ok,value=pcall(mod.storage.read,mod.storage,'saved_servers')
    if ok and type(value)=='table' then
      for _,address in ipairs(value)do if type(address)=='string' and #address<=128 and #saved<32 then saved[#saved+1]=address end end
    end
  end
  local function saveServers()
    if not(mod.storage and mod.storage.write)then return false,'Server storage unavailable' end
    local ok,why=pcall(mod.storage.write,mod.storage,'saved_servers',saved)
    return ok,why
  end
  local function menuMode()return UI.mode=='menu'or UI.mode=='join-list'or UI.mode=='server'or UI.mode=='players'or UI.mode=='peer' end
  local keys='1234567890abcdefghijklmnopqrstuvwxyz.-: <'
  UI.key=1
  local function game()return mod.world.game end
  local function quietInput()
    local input=game() and game().input
    if input then input.state={};input.pressed={};input.pressQueue={};input.aliasHeld=nil end
  end
  function UI.close()if session.stopScan then session.stopScan()end;UI.open=false;UI.blockFrame=true;adapter.menuBusy=false;quietInput()end
  function UI.show(mode)
    UI.open=true;UI.mode=mode or 'menu';UI.text='';UI.selection=1;UI.error=nil;adapter.menuBusy=true;quietInput()
    if UI.mode=='join-list' and session.scanLan then local ok,why=session.scanLan();if not ok then UI.error=why end end
  end
  local function rows()
    if UI.mode=='join-list'then
      UI.games=session.localGames and session.localGames()or{}
      local list={};for _,host in ipairs(UI.games)do list[#list+1]=host.name..' '..host.address end
      UI.lanCount=#list
      for _,address in ipairs(saved)do list[#list+1]='SAVED '..address end
      list[#list+1]='DIRECT ADDRESS';list[#list+1]='REFRESH';list[#list+1]='BACK';return list
    end
    if UI.mode=='players'then
      UI.players=session.roster and session.roster()or{}
      local list={};for _,p in ipairs(UI.players)do list[#list+1]=p.name or'TRAINER'end
      list[#list+1]='BACK';return list
    end
    if UI.mode=='peer'then
      local list={};local caps=adapter.capabilities and adapter.capabilities()or{}
      for _,c in ipairs({{'single','SINGLE BATTLE'},{'double','DOUBLE BATTLE'},{'trade','TRADE'}})do
        if caps[c[1]]and(session.peerCapabilities or{})[c[1]]then list[#list+1]=c[2]end
      end
      if session.host then list[#list+1]='KICK PLAYER'end
      list[#list+1]='BACK';return list
    end
    if UI.mode=='server'then return {'CONNECT','REMOVE SAVED','BACK'}end
    if session.activity and session.activity.status=='incoming'then return {'ACCEPT INVITATION','DECLINE INVITATION'}end
    if session.connected then
      return {'PLAYERS ('..#(session.roster and session.roster()or{})..')','CHAT','DISCONNECT','CLOSE'}
    end
    if session.status then return {'DISCONNECT','CLOSE'}end
    return {'HOST','JOIN'}
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
    local list=rows();UI.selection=math.min(UI.selection,#list);local row=list[UI.selection]
    if UI.mode=='players'then
      local peer=UI.players[UI.selection]
      if peer then local ok,why=session.selectPeer(peer.id);if ok then UI.show('peer')else UI.error=why end
      else UI.show()end;return
    end
    if UI.mode=='peer'and row=='BACK'then UI.show('players');return end
    if UI.mode=='server'then
      if row=='CONNECT'then local ok,why=session.joinLan(UI.server);if ok then UI.close()else UI.error=why end
      elseif row=='REMOVE SAVED'then table.remove(saved,UI.serverIndex);local ok,why=saveServers();UI.show('join-list');if not ok then UI.error=why end
      else UI.show('join-list')end
      return
    end
    if UI.mode=='join-list'then
      local host=UI.games[UI.selection]
      if host then local ok,why=session.joinLan(host.address);if ok then UI.close()else UI.error=why end
      elseif saved[UI.selection-UI.lanCount]then UI.serverIndex=UI.selection-UI.lanCount;UI.server=saved[UI.serverIndex];UI.show('server')
      elseif row=='DIRECT ADDRESS'then UI.show('join-lan')
      elseif row=='REFRESH'then UI.show('join-list')else UI.show()end
      return
    end
    UI.error=nil
    if row=='ACCEPT INVITATION'then UI.close();session.respond(true)
    elseif row=='DECLINE INVITATION'then UI.close();session.respond(false)
    elseif row=='SINGLE BATTLE'or row=='DOUBLE BATTLE'or row=='TRADE'then
      UI.close();local ok,why=session.invite(row=='SINGLE BATTLE'and'single'or row=='DOUBLE BATTLE'and'double'or'trade')
      if not ok then UI.show();UI.error=why end
    elseif row=='HOST ONLINE ROOM'then local ok,why=session.hostOnline();if not ok then UI.error=why end
    elseif row=='JOIN ONLINE ROOM'then UI.show('join-online')
    elseif row=='HOST'then local ok,why=session.hostLan();if not ok then UI.error=why end
    elseif row=='JOIN'then UI.show('join-list')
    elseif row and row:sub(1,8)=='PLAYERS 'then UI.show('players')
    elseif row=='CHAT'then UI.show('chat')
    elseif row and row:sub(1,5)=='KICK 'then local ok,why=session.kick(session.selectedPeer);if ok then UI.show('players')else UI.error=why end
    elseif row=='DISCONNECT'then session.disconnect();UI.close()
    else UI.close()end
  end
  function UI.textinput(text)
    if not UI.open or menuMode() or type(text)~='string'then return false end
    local clean=text:gsub('[%z\1-\31\127]','')
    local limit=UI.mode=='chat' and 240 or 128
    if #UI.text+#clean<=limit then UI.text=UI.text..clean end
    return true
  end
  local function action(button)
    if button=='b'then if UI.mode=='menu'then UI.close()else UI.show(UI.mode=='server'and'join-list'or UI.mode=='peer'and'players'or'menu')end
    elseif menuMode()then
      if button=='a'or button=='start'then choose()
      elseif button=='up'then UI.selection=(UI.selection-2)%#rows()+1
      elseif button=='down'then UI.selection=UI.selection%#rows()+1 end
    elseif button=='start'then submit()
    elseif button=='left'then UI.key=(UI.key-2)%#keys+1
    elseif button=='right'then UI.key=UI.key%#keys+1
    elseif button=='up'then UI.key=(UI.key-12)%#keys+1
    elseif button=='down'then UI.key=(UI.key+10)%#keys+1
    elseif button=='a'then if keys:sub(UI.key,UI.key)=='<'then UI.text=UI.text:gsub('[%z\1-\127\194-\244][\128-\191]*$','')else UI.textinput(keys:sub(UI.key,UI.key))end
    elseif button=='select'and UI.mode=='join-lan'then
      local address=UI.text:match('^%s*(.-)%s*$')
      local host,port=address:match('^([%w%.%-]+):(%d+)$')
      if not host and address:match('^[%w%.%-]+$')then host=address end
      if not host or(port and(tonumber(port)<1 or tonumber(port)>65535))then UI.error='Enter host name or IP:port';return end
      for _,v in ipairs(saved)do if v==address then UI.error='Already saved';return end end
      if #saved>=32 then UI.error='Server list full';return end
      saved[#saved+1]=address;local ok,why=saveServers();UI.error=ok and'Server saved'or why
    end
  end
  local boundGame
  local function bind(g)
    if not g or boundGame==g then return end
    boundGame=g
    -- The engine polls controllers after input.step; clearing tables alone
    -- cannot prevent held buttons from leaking into walking/interactions.
    local input=g.input
    if input then for _,name in ipairs({'isDown','wasPressed'})do
      local original=input[name]
      if original then input[name]=function(self,...)
        if UI.open or UI.blockFrame then return false end
        return original(self,...)
      end end
    end end
    local previous=g.textinput
    g.textinput=function(self,text,...)
      if UI.textinput(text)then return end
      if previous then return previous(self,text,...)end
    end
  end
  mod.events:on('game.ready',function(ev)bind(ev and ev.game or game())end)
  mod.hooks:wrap('input.step',function(nextFn,g,dt)
    bind(g);UI.blockFrame=false
    if session.activity and session.activity.status=='incoming' and not UI.open then UI.show()end
    local result=nextFn(g,dt)
    if UI.open then
      local input=g.input
      if input and input.pollPads then input:pollPads()end
      local button=input and input.pressQueue and input.pressQueue[1]
      if button then action(button)end
      quietInput()
    end
    return result
  end)
  mod.hooks:wrap('input.key',function(nextFn,g,ev)
    local key=ev and ev.key
    if ev and ev.phase=='pressed' then
      if key=='f8'then if UI.open then UI.close()else UI.show()end;return end
      if key=='f9'and session.connected then UI.show('chat');return end
      if UI.open then
        if key=='escape'then UI.close()
        elseif key=='return' or key=='kpenter'then if menuMode()then choose()else submit()end
        elseif menuMode()then
          if key=='up'then UI.selection=(UI.selection-2)%#rows()+1
          elseif key=='down'then UI.selection=UI.selection%#rows()+1 end
        elseif key=='tab'then action('select')
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
      local R=art.lib.require('Voxel3D');local x,y=R.project(p.px+8,38+(tonumber(p.height)or 0),p.py+16)
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
    -- Room menus use the native screen scale. Overworld bubbles are compact
    -- annotations: integer font scaling keeps pixels sharp without covering
    -- several trainers at modern resolutions (including the 3D camera).
    if not UI.open then
      scale=math.max(1,math.floor(scale/2))
      width,height=math.floor(v.width/scale),math.floor(v.height/scale)
    end
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
        text(UI.mode=='menu'and(session.host and session.status and'HOSTING'or'MULTIPLAYER')or UI.mode=='players'and'CONNECTED PLAYERS'or UI.mode=='peer'and tostring((session.peers.remote or{}).name or'TRAINER')or UI.mode=='join-list'and'JOIN GAME'or UI.mode=='chat'and'CHAT'or UI.mode=='join-online'and'ROOM CODE'or'HOST ADDRESS',16,16,width-32)
        if menuMode()then
          local list=rows();UI.selection=math.min(UI.selection,#list);local count=math.max(1,math.floor((height-76)/pitch))
          local first=math.max(1,UI.selection-count+1)
          for i=first,math.min(#list,first+count-1)do
            local y=34+(i-first)*pitch
            if i==UI.selection then
              if gen3 then Window.cursorPx(16,y)else Font.drawCode(require('src.ui.Theme').cursor,16,y)end
            end
            local label=({['HOST ONLINE ROOM']='HOST ONLINE',['JOIN ONLINE ROOM']='JOIN ONLINE',['ACCEPT INVITATION']='ACCEPT',['DECLINE INVITATION']='DECLINE'})[list[i]]or list[i]
            block(label,26,y,width-42,1)
          end
          block(UI.mode=='server'and UI.server or UI.mode=='join-list'and(#UI.games==0 and'Scanning LAN...'or'Select a host')or session.code and('Room: '..session.code)or session.address and('Address: '..session.address)or session.status or'F8/F9: chat',16,height-40,width-32,1)
        else
          block(UI.text..'-',16,34,width-32,2,true)
          for i=1,#keys do
            local x,y=20+((i-1)%11)*12,56+math.floor((i-1)/11)*12
            if i==UI.key then gfx.setColor(.7,.7,.7,1);gfx.rectangle('fill',x-2,y-1,11,11);gfx.setColor(1,1,1,1)end
            local ch=keys:sub(i,i)
            -- GB fonts omit ASCII backspace/underscore glyphs.
            if ch=='<' or ch==' 'then
              gfx.setColor(0,0,0,1)
              gfx.rectangle('fill',x,y+5,7,1)
              if ch=='<'then
                gfx.rectangle('fill',x+1,y+4,1,3);gfx.rectangle('fill',x+2,y+3,1,5)
              else gfx.rectangle('fill',x,y+3,1,2);gfx.rectangle('fill',x+6,y+3,1,2)end
              gfx.setColor(1,1,1,1)
            else text(ch,x,y,12)end
          end
          text(UI.mode=='chat'and'START SEND'or'START JOIN',16,height-40,width-32)
          if UI.mode=='join-lan'then text('SELECT/TAB SAVE',16,height-30,width-32)end
        end
        block(UI.error or session.notice or'A OK  B BACK',16,height-18,width-32,1)
      else
        local shown,placed={},{}
        for i=#session.chat,1,-1 do
          local msg=session.chat[i];local who=msg.localSender and'local'or msg.peerId or'remote'
          if msg.age<7 and not shown[who]then
            shown[who]=true
            local p=msg.localSender and adapter.position()or session.peers[msg.peerId or'remote']
            local x,y=bubblePoint(p,v)
            if x and y and x>=0 and x<=v.width and y>=0 and y<=v.height then
              x,y=(x-ox)/scale,(y-oy)/scale
              local w=math.min(width-16,gen3 and 160 or 128,math.max(64,math.ceil((measure(msg.text)+16)/8)*8))
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
    local p=adapter.position()
    local peers=session.roster and session.roster()or{session.peers.remote}
    if not p then return false end
    for _,q in ipairs(peers)do
    if session.activity or not session.connected or p.busy then return false end
    local d=({up={0,-1},down={0,1},left={-1,0},right={1,0}})[p.facing]
    if q and p.map==q.map and d and q.x==p.x+d[1]and q.y==p.y+d[2]then
      if session.selectPeer then session.selectPeer(q.id)end;UI.show('peer');return true end
    end
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
