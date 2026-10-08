local now, tick, frames, moves, report = 100, nil, {}, 0, nil
local function frame(x) return {x=x,y=30,w=600,h=400} end
local screen = {getUUID=function()return 'external'end,fullFrame=function()return frames.external end}
local internal = {getUUID=function()return 'internal'end,fullFrame=function()return frame(0)end}
frames.external=frame(-2000)
local app={pid=function()return 42 end,bundleID=function()return 'test.app'end}
local currentScreen,currentFrame,fullscreen,reject=screen,frame(-1900),false,0
local window={id=function()return 9 end,application=function()return app end,
  screen=function()return currentScreen end,frame=function()return currentFrame end,
  isStandard=function()return true end,isFullScreen=function()return fullscreen end,
  moveToScreen=function(_,value)currentScreen=value;moves=moves+1 end,
  setFrame=function(_,value)
    moves=moves+1
    if reject>0 then reject=reject-1 else currentFrame=value;currentScreen=screen end
  end}
local windows,online={window},{internal,screen}
hs={geometry={rect=function(value)return value end},screen={allScreens=function()return online end},
  timer={secondsSinceEpoch=function()return now end,doEvery=function(interval,callback)
    assert(interval==0.3);tick=callback;return {stop=function()tick=nil end}
  end}}
local layout=dofile('config/hammerspoon/private/modules/away-guard-windows.lua').new({windows=function()return windows end})
local snapshot=layout:capture()
assert(#snapshot.windows==1 and snapshot.windows[1].screen=='external')
local function run()
  report=nil;layout:restore(snapshot,function(value)report=value end)
  for _=1,40 do if not tick then break end;now=now+0.3;tick()end
  assert(report)
end
-- A transient AX rejection is retried; geometry and original monitor are verified.
currentFrame=frame(0);currentScreen=internal;reject=1
run();assert(report.restored==1 and #report.failed==0 and moves>=2 and currentFrame.x==-1900)
online={internal};run();assert(report.failed[1].reason=='display_missing')
online={internal,screen};frames.external=frame(-1500)
run();assert(report.failed[1].reason=='display_layout_changed')
frames.external=frame(-2000);currentFrame=frame(0);reject=10
run();assert(report.failed[1].reason=='frame_not_applied')
fullscreen=true;run();assert(report.failed[1].reason=='window_now_fullscreen');fullscreen=false
windows={};run();assert(report.closed==1 and #report.failed==0)
windows={window};app.pid=function()return 43 end
run();assert(report.closed==1 and #report.failed==0)
app.pid=function()return 42 end;fullscreen=true
assert(#layout:capture().windows==0)
fullscreen=false;window.id=function()return 0 end
assert(#layout:capture().windows==0)
print('Away guard window restore: monitor/geometry verification, retries, missing/changed displays, fullscreen and recycled IDs passed')
