for _,gen in ipairs({1,2,3})do
 local hooks,drawn,frames={},{},0;local depth=0;local scales={}
 local function noop()end
 local gfx={push=function()depth=depth+1 end,pop=function()depth=depth-1 end,origin=noop,setShader=noop,translate=noop,scale=function(s)scales[#scales+1]=s end,setColor=noop}
 love={graphics=gfx}
 local F={COLOR={NORMAL={}},width=function(s)return #s*8 end,measure=function(s)return #s*6 end,
 draw=function(s,x,y)drawn[#drawn+1]={s=s,x=x,y=y}end,drawCode=noop,drawBox=function()frames=frames+1 end}
 package.loaded['src.ui.Theme']={cursor=0xED};package.loaded['src.render.Font']=F;package.loaded['src.ui.game3.font']=F
 package.loaded['src.ui.game3.window']={template=function()return{}end,fill=noop,cursorPx=noop,stdFrame=function()frames=frames+1 end}
 package.loaded['src.world.OverworldController']={interact=noop};package.loaded['src.core.game3.field']={interact=noop}
 local mod={world={game={input={}}},events={on=noop},hooks={wrap=function(_,key,fn)hooks[key]=fn end}}
 local point={map='town',px=0,py=0,height=40};local projected
 local art={gen3={camera={active=true}},lib={require=function(name)assert(name=='Voxel3D');return{project=function(x,y,z)projected={x,y,z};return 640,360 end,size=function()return 1280,720 end}end}}
 mod.find=function(name)if name=='BATTLE_ART_VOXEL_FORK'then return{exports=art}end end
 package.loaded['src.render.Pipelines']={level=function()return 3 end}
 local S={chat={},peers={},status=nil};local adapter={generation=gen,position=function()return point end}
 local ui=dofile('lib/crossgen/ui.lua')(mod,S,adapter)
 local function render()hooks['render.hud'](noop,{}, {width=1280,height=720,scale=4})end
 render();assert(frames==0 and depth==0,'inactive room changed native UI')
 ui.show();render();assert(frames==1 and depth==0);local menuScale=scales[#scales]
 local found=false;for _,d in ipairs(drawn)do found=found or d.s=='HOST ONLINE';assert(d.y>=0 and d.y<160)end;assert(found)
 ui.show('chat');ui.text=string.rep('hello ',40);local original=ui.text;render();assert(ui.text==original,'render mutated outgoing chat')
 ui.close();S.chat={{text='Hello!',age=0,localSender=true}};render();assert(frames==3 and depth==0);assert(scales[#scales]==math.max(1,math.floor(menuScale/2)),'bubble reused full screen menu scale');assert(projected and projected[2]==78,'bubble ignored mount altitude')
 F.draw=function()error('draw failed')end;ui.show();assert(not pcall(render)and depth==0,'draw failure leaked graphics state')
end
print('PASS native room frames/fonts, menu fitting, untouched chat payload and graphics cleanup across 3 generations')
