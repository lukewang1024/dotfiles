package.path='config/hammerspoon/?.lua;'..package.path
local m=dofile('config/hammerspoon/private/modules/remote-window-stack.lua')
assert(m.isSession('com.nomachine.nxdock','Test Session - NoMachine'))
assert(not m.isSession('com.nomachine.nxdock','NoMachine'))
assert(not m.isSession('com.nomachine.nxdock',''))
assert(m.isSession('com.microsoft.rdc.macos','[RDP] Test Session'))
assert(not m.isSession('com.microsoft.rdc.macos','Windows App'))
assert(not m.isSession('com.microsoft.rdc.macos','Settings'))
local full={x=0,y=0,w=1728,h=1117}
local usable={x=0,y=34,w=1728,h=1083}
local bottom=m.bounds(usable,full,{autohide=true})
assert(bottom.x==0 and bottom.w==1728 and bottom.y==34 and bottom.h==1081)
local f=m.frames(bottom,2)
assert(f[1].w==f[2].w and f[1].h==f[2].h)
assert(f[2].y-f[1].y==28 and f[2].y+f[2].h==1115)
local left=m.bounds(usable,full,{autohide=true,orientation='left'})
assert(left.x==2 and left.w==1726 and left.h==1083)
local right=m.bounds(usable,full,{autohide=true,orientation='right'})
assert(right.x==0 and right.w==1726 and right.h==1083)
local visible={x=70,y=34,w=1658,h=1083}
local v=m.bounds(visible,full,{autohide=false,orientation='left'})
assert(v.x==70 and v.w==1658 and v.h==1083)
-- Do not double-reserve when macOS has already excluded a revealed hidden Dock.
local revealed=m.bounds(visible,full,{autohide=true,orientation='left'})
assert(revealed.x==70)
local external=m.bounds({x=-2560,y=-292,w=2560,h=1409},
  {x=-2560,y=-323,w=2560,h=1440},{autohide=true,orientation='right'})
assert(external.x==-2560 and external.w==2558)
assert(#m.frames({x=0,y=0,w=300,h=200},2)==0)
print('Remote stack: Dock modes/edges, no double reserve, equal sizes and titlebar spacing passed')

local area=m.bounds(usable,full,{autohide=true})
local two=m.frames(area,2)
local three=m.frames(area,3)
assert(three[1].h==two[1].h-28)
assert(three[3].y-three[1].y==56)
assert(three[3].y+three[3].h==1115)
local half=m.region(area,{0,0,.5,1})
assert(half.x==0 and half.w==864)
local thirds=m.region(area,{2/3,0,1/3,1})
assert(thirds.x==1152 and thirds.w==576)
local ext=m.region({x=-2560,y=-292,w=2560,h=1409},{0,0,2/3,1})
assert(ext.x==-2560 and ext.w==1706)
print('Remote group: three-window height and fractional monitor regions passed')

-- Regression: minimized remote clients may temporarily vanish from allWindows.
local pending,raised,focused={},{},nil
local suspended=true
local moves=0
hs={
  settings={get=function()return nil end},
  plist={read=function()return {autohide=false}end},
  window={list=function()return {{kCGWindowNumber=2},{kCGWindowNumber=1}}end},
  timer={doEvery=function()return {stop=function()end}end,
    doAfter=function(_,fn)pending[#pending+1]=fn;return {stop=function()end}end},
  screen={watcher={new=function()return {start=function(self)return self end,stop=function()end}end}},
  eventtap={checkMouseButtons=function()return {}end},
  printf=function()end,
}
hs.window.filter={windowFocused='focused',new=function()
  return {setAppFilter=function()end,subscribe=function()end,unsubscribeAll=function()end}
end}
local app={pid=function()return 100 end,unhide=function()end,bundleID=function()return 'com.microsoft.rdc.macos' end}
local groupScreen
local function window(id,y)
  local w={f={x=0,y=y,w=1200,h=800},minimized=false}
  function w:id()return id end
  function w:application()return app end
  function w:title()return '[RDP] '..id end
  function w:frame()return self.f end
  function w:isMinimized()return self.minimized end
  function w:minimize()self.minimized=true end
  function w:unminimize()self.minimized=false;self.f={x=99,y=99,w=400,h=300}end
  function w:setFrame(f)moves=moves+1;self.f={x=f.x,y=f.y,w=f.w,h=f.h}end
  function w:isVisible()return not self.minimized end
  function w:isFullScreen()return false end
  function w:screen()return groupScreen end
  function w:setTopLeft(p)moves=moves+1;self.f.x=p.x;self.f.y=p.y end
  function w:raise()raised[#raised+1]=id end
  function w:focus()focused=id end
  return w
end
local a,b=window(1,34),window(2,62)
local group=m.new({suspended=function()return suspended end})
groupScreen={frame=function()return {x=0,y=34,w=1200,h=900}end,fullFrame=function()return {x=0,y=0,w=1200,h=934}end,getUUID=function()return 'test-screen' end}
group.screen=function()return groupScreen end
group.members=function()return {a,b}end
group.focusedWindow=function()return b end
assert(group:toggle() and group.hidden and a.minimized and b.minimized)
group.members=function()return {}end
assert(group:toggle() and group.restoring)
for i=1,12 do
  if #pending==0 then break end
  local fn=table.remove(pending,1);fn()
end
assert(not group.restoring and group.restoreReport.complete)
assert(group.restoredPlacement==nil)
assert(a.f.y==34 and b.f.y==62 and a.f.w==1200 and b.f.h==872)
assert(not a.minimized and not b.minimized)
assert(raised[1]==1 and raised[2]==2 and focused==2)
print('Remote group restore: retained members, asynchronous frame settling, rule targets and stacking passed')

-- An active group must sit together above unrelated normal windows.
raised={}
group:raiseActiveGroup({a,b},{
  {kCGWindowNumber=2,kCGWindowLayer=0},
  {kCGWindowNumber=99,kCGWindowLayer=0},
  {kCGWindowNumber=1,kCGWindowLayer=0},
})
assert(#raised==2 and raised[1]==1 and raised[2]==2)
raised={}
group:raiseActiveGroup({a,b},{
  {kCGWindowNumber=2,kCGWindowLayer=0},
  {kCGWindowNumber=99,kCGWindowLayer=3},
  {kCGWindowNumber=1,kCGWindowLayer=0},
  {kCGWindowNumber=98,kCGWindowLayer=0},
})
assert(#raised==0) -- already contiguous; floating panels do not count
group.focusedWindow=function()return nil end
group:raiseActiveGroup({a,b},{{kCGWindowNumber=99,kCGWindowLayer=0},{kCGWindowNumber=1,kCGWindowLayer=0}})
assert(#raised==0) -- another application is active
print('Remote group activation: raises obscured peers in order, preserves inactive groups and floating panels')

-- Restore targets are the same rule-derived frames used by every later poll.
-- A cached constrained client size must not be treated as a new group region.
group.members=function()return {a,b}end
group.focusedWindow=function()return b end
group.sizes={}
group.aspectRatios[1]=.9
suspended=false
group:apply()
local expectedA={x=a.f.x,y=a.f.y,w=a.f.w,h=a.f.h}
local expectedB={x=b.f.x,y=b.f.y,w=b.f.w,h=b.f.h}
local function same(actual,expected)
  for _,key in ipairs({'x','y','w','h'}) do assert(actual[key]==expected[key],key) end
end
for cycle=1,5 do
  assert(group:toggle() and group.hidden)
  -- A stale saved frame must never become an intermediate visible target.
  for _,item in ipairs(group.savedHidden.windows) do item.frame={x=99,y=99,w=400,h=300} end
  assert(group:toggle() and group.restoring)
  for i=1,12 do
    if #pending==0 then break end
    group:apply() -- focus/screen callbacks during restoration must not relayout
    table.remove(pending,1)()
  end
  assert(group.restoreReport.complete and not group.restoring)
  same(a.f,expectedA);same(b.f,expectedB)
  local settledMoves=moves
  for poll=1,6 do
    -- Temporary CG order and losing group focus must not change slot order.
    hs.window.list=function()return {{kCGWindowNumber=poll%2+1},{kCGWindowNumber=(poll+1)%2+1}}end
    group.focusedWindow=function()return poll%2==0 and b or nil end
    group:apply()
    same(a.f,expectedA);same(b.f,expectedB)
  end
  assert(moves==settledMoves,'layout moved after restoration')
  group.focusedWindow=function()return b end
end
print('Remote restore stability: repeated show/hide, constrained dimensions, stale snapshots and shuffled CG order passed without post-restore frame writes')
