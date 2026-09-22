local hooks={}
local native=0
local Class={interact=function()native=native+1 end}
package.loaded['src.world.OverworldController']=Class
local game={input={}}
local mod={world={game=game},events={on=function()end},hooks={wrap=function(_,name,fn)hooks[name]=fn end}}
local session={connected=true,peers={remote={map='town',x=1,y=0}},activity={status='active'}}
local adapter={generation=2,position=function()return {map='town',x=0,y=0,facing='right'}end}
local ui=dofile('lib/crossgen/ui.lua')(mod,session,adapter)
Class.interact({});assert(not ui.open and native==1,'room menu interrupted an active battle')
session.activity={status='waiting'};Class.interact({});assert(not ui.open,'room menu interrupted handshake')
session.activity=nil;Class.interact({});assert(ui.open and adapter.menuBusy,'walk-up interaction missing')
ui.close();assert(not adapter.menuBusy)
print('PASS room menu stays closed during activity and handshake; walk-up interaction preserved')
