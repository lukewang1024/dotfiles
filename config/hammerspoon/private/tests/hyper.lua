-- Behavioral tests: toggle, spatial placement, undo, selection, remote ownership.
package.path='config/hammerspoon/?.lua;'..package.path
package.loaded['private/modules/hyper-rust-palette']={new=function()
  return {visible=false,show=function()end,stop=function()end,close=function(self)self.visible=false end}
end}
local function clone(t)
  if type(t)~='table' then return t end
  local result={};for k,v in pairs(t) do result[k]=clone(v) end;return result
end
local function rect(x,y,w,h)return {x=x,y=y,w=w,h=h}end
local primary={frame=function()return rect(0,30,1200,870)end}
local left={frame=function()return rect(-1600,0,1600,900)end}
local currentFrame=rect(100,100,600,400)
local currentScreen=primary
local currentID=1
local fullscreen=false
local clampAcrossScreens=false
local stalePlacement=false
local pointer={x=100,y=100}
local minimized=0
local hidden=false
local app={front=true,hidden=false,bundleID=function()return 'test.app' end}
function app:isFrontmost()return self.front end
function app:hide()self.hidden=true;self.front=false end
function app:unhide()self.hidden=false end
function app:activate()self.front=true end
local win={id=function()return currentID end,isStandard=function()return true end,
  isFullScreen=function()return fullscreen end,setFullScreen=function(_,value)fullscreen=value end,
  screen=function()return currentScreen end,
  frame=function()return clone(currentFrame)end,setFrame=function(_,r)
    assert(not fullscreen,'Cannot move a native fullscreen window')
    if stalePlacement then stalePlacement=false;return end
    local source=currentScreen:frame()
    local destination=r.x<0 and left or primary
    currentFrame=clone(r)
    if clampAcrossScreens and destination~=currentScreen then
      currentFrame.w=math.min(currentFrame.w,source.w)
      currentFrame.h=math.min(currentFrame.h,source.h)
    end
    currentScreen=destination
  end,
  focus=function()end,application=function()return app end,
  minimize=function()minimized=minimized+1;hidden=true end,
  isMinimized=function()return hidden end,unminimize=function()hidden=false end,
  moveToScreen=function(_,screen)
    currentFrame=require('private/modules/hyper').rebaseFrame(currentFrame,currentScreen:frame(),screen:frame())
    currentScreen=screen
  end}
function win:setFrameWithWorkarounds(r)
  self:setFrame(r);self:setFrame(r)
end
function win:setTopLeft(point)
  if stalePlacement then return end
  currentFrame.x=point.x;currentFrame.y=point.y
  currentScreen=point.x<0 and left or primary
end
function app:mainWindow()return win end
local keys,timers,delayed={},{},{}
local function flushPlacement()
  while #delayed>0 do
    local pending=delayed;delayed={}
    for _,fn in ipairs(pending) do fn() end
  end
end
local stroke,remote=nil,false
hs={json={encode=function(v)return v end,decode=clone},settings={get=function()end},
  plist={read=function()return {}end},
  geometry={rect=rect},alert={show=function()end},
  mouse={absolutePosition=function(point)if point then pointer=point end;return clone(pointer)end},
  application={applicationsForBundleID=function()return {app}end,frontmostApplication=function()return app end},
  window={focusedWindow=function()return win end,orderedWindows=function()return {win}end},
  screen={allScreens=function()return {primary,left}end},
  pasteboard={changeCount=function()return 0 end},
  eventtap={keyStroke=function(mods,key)stroke={mods,key}end},
  timer={doAfter=function(delay,fn)
      if delay==0.2 or delay==0.1 then delayed[#delayed+1]=fn end
      return {stop=function()end}
    end,
    doEvery=function(_,fn)local t={fire=function()fn();flushPlacement()end,stop=function()end};timers[#timers+1]=t;return t end},
  hotkey={bind=function(mods,key,press,release,repeatfn)
    local obj={mods=mods,key=key,press=press,release=release,repeatfn=repeatfn,enabled=true,
      delete=function()end,disable=function(self)self.enabled=false end,enable=function(self)self.enabled=true end}
    keys[#keys+1]=obj;return obj
  end}}
hs.application.watcher={activated=1,deactivated=2,new=function(callback)
  return {fire=callback,start=function(self)return self end,stop=function()end}
end}
local instance=require('private/modules/hyper').new({remote={isFocused=function()return remote end}})
delayed={} -- App-index startup is outside this window-state test.
local run=instance.run
function instance:run(action)run(self,action);flushPlacement()end
for _,key in ipairs(keys) do
  if key.key=='h' then assert(key.press and not key.release and key.repeatfn) end
  assert(key.key~='`' and key.key~='return' and key.key~="'")
  if key.key=='up' and #key.mods==4 then assert(not key.press and key.release and not key.repeatfn) end
  if key.key=='w' then assert(#key.mods==3 or #key.mods==4) end -- Role and explicit WeChat coexist.
end
instance:run('app.browser');assert(app.hidden and not app.front)
instance:run('app.browser');assert(not app.hidden and app.front)
instance:run('window.twoThirds');assert(currentFrame.x==0 and math.abs(currentFrame.w-800)<.001)
instance:run('window.lastThird');assert(math.abs(currentFrame.x-800)<.001 and math.abs(currentFrame.w-400)<.001)
instance:run('window.undo');assert(math.abs(currentFrame.w-800)<.001)
instance:run('window.max');assert(currentFrame.w==1200)
instance:run('window.max');assert(math.abs(currentFrame.w-800)<.001)
instance:run('select.left');assert(stroke[1][1]=='shift' and stroke[2]=='left')
instance:run('edit.home');assert(stroke[1][1]=='cmd' and stroke[2]=='left')
instance:run('screen.left')
instance:run('screen.right') -- right edge wraps to the leftmost screen
instance:run('screen.up') -- no vertical peer: use the horizontal axis
currentScreen=primary;currentFrame=rect(100,100,600,400)
instance:run('window.max');instance:run('screen.left')
assert(require('private/modules/hyper').sameFrame(currentFrame,left:frame()))
instance:run('window.max')
assert(currentScreen==left and math.abs(currentFrame.x-(-1600+100/1200*1600))<.001)
assert(math.abs(currentFrame.w-800)<.001)
-- Real AX setters can clamp to the old screen before moving. Repeated
-- small/large display round trips must keep maximization and normal placement.
clampAcrossScreens=true
currentScreen=primary;currentFrame=rect(100,100,600,400)
instance.maximized={};instance.managed={};instance.snapped={}
instance:run('window.maximize')
stalePlacement=true -- iTerm can discard one position/size pair asynchronously.
for _=1,3 do
  instance:run('screen.left')
  assert(require('private/modules/hyper').sameFrame(currentFrame,left:frame()))
  instance:run('screen.right')
  assert(require('private/modules/hyper').sameFrame(currentFrame,primary:frame()))
end
-- A prior clamped managed frame still carries the maximize intent.
currentFrame.w=1100;instance.managed[currentID]=clone(currentFrame)
instance:run('screen.left');instance:run('screen.right')
assert(require('private/modules/hyper').sameFrame(currentFrame,primary:frame()))
instance:run('window.restoreDown')
assert(require('private/modules/hyper').sameFrame(currentFrame,rect(100,100,600,400)))
clampAcrossScreens=false
-- Native fullscreen is restored only after exit and destination placement.
currentScreen=primary;currentFrame=rect(100,100,600,400);fullscreen=true
instance:run('screen.left')
assert(not fullscreen and instance.screenMoves[currentID])
local transition=instance.screenMoves[currentID]
instance:run('screen.right');assert(instance.screenMoves[currentID]==transition)
for _=1,8 do transition.fire() end
assert(fullscreen and currentScreen==left and not instance.screenMoves[currentID])
assert(math.abs(currentFrame.w-800)<.001)
fullscreen=false
instance.maximized={};instance.managed={};instance.history={}
currentScreen=left;currentFrame=rect(-1600+100/1200*1600,100,800,400)
instance:run('window.max');instance:run('screen.right');instance:run('window.undo')
assert(currentScreen==primary and math.abs(currentFrame.x-100)<.001 and math.abs(currentFrame.w-600)<.001)
instance.maximized={};instance.snapped={};instance.managed={}
currentFrame=rect(100,100,600,400)
instance:run('window.maximize');instance:run('window.maximize')
assert(currentFrame.w==1200)
instance:run('window.restoreDown');assert(currentFrame.x==100 and currentFrame.w==600 and minimized==0)
instance:run('window.restoreDown');assert(minimized==1)
instance:run('window.left');instance:run('window.left')
instance:run('window.maximize');instance:run('window.restoreDown')
assert(currentFrame.x==0 and currentFrame.w==600 and currentFrame.h==870)
instance:run('window.restoreDown');assert(currentFrame.x==100 and currentFrame.h==400)
instance:run('window.maximize');instance:run('screen.left');instance:run('window.restoreDown')
assert(currentFrame.x<0 and math.abs(currentFrame.w-800)<.001)
instance:run('window.left');currentFrame=rect(-1200,200,500,500)
instance:run('window.restoreDown');assert(minimized==2)
instance:run('window.up');assert(not hidden and currentFrame.w==500)
currentScreen=primary;currentFrame=rect(100,100,600,400)
instance:run('window.left');instance:run('window.up')
assert(currentFrame.x==0 and currentFrame.w==600 and currentFrame.h==435)
instance:run('window.down');assert(currentFrame.h==870)
instance:run('window.down');assert(currentFrame.y==465 and currentFrame.h==435)
instance:run('window.down');assert(currentFrame.x==100 and currentFrame.h==400)
instance:run('window.right');instance:run('window.up')
assert(currentFrame.x==600 and currentFrame.y==30 and currentFrame.h==435)
instance:run('window.down');assert(currentFrame.x==600 and currentFrame.h==870)
instance:run('window.down');assert(currentFrame.y==465 and currentFrame.h==435)
instance:run('window.up');assert(currentFrame.y==30 and currentFrame.h==870)
-- Cycles follow each window's geometry, including after a screen move or undo.
instance.maximized={};instance.snapped={};instance.managed={}
currentScreen=primary;currentFrame=rect(100,100,600,400)
local model=require('private/modules/hyper-generated')
local geometry=require('private/modules/hyper')
assert(geometry.appTarget({title='ChatGPT',mac='expected.id'},{{title='ChatGPT',bundle='actual.id'}})=='actual.id')
assert(geometry.appTarget({title='ChatGPT',mac='expected.id'},{{title='ChatGPT',bundle='actual.id'},{title='Other name',bundle='expected.id'}})=='expected.id')
assert(geometry.appTarget({title='ChatGPT',mac='expected.id'}, {})=='expected.id')
local function isLayout(name)
  local a=currentScreen:frame();local r=model.layouts[name]
  return geometry.sameFrame(currentFrame,rect(a.x+a.w*r[1],a.y+a.h*r[2],a.w*r[3],a.h*r[4]))
end
instance:run('window.cycleTwoThirds');assert(isLayout('twoThirds'))
instance:run('window.cycleTwoThirds');assert(isLayout('lastTwoThirds'))
instance:run('window.cycleTwoThirds');assert(isLayout('twoThirds'))
instance:run('window.undo');assert(isLayout('lastTwoThirds'))
instance:run('window.cycleTwoThirds');assert(isLayout('twoThirds'))
local firstWindow=clone(currentFrame)
currentID=2;currentFrame=rect(200,200,500,500)
instance:run('window.cycleTwoThirds');assert(isLayout('twoThirds'))
currentID=1;currentFrame=firstWindow
instance:run('window.cycleTwoThirds');assert(isLayout('lastTwoThirds'))
for _,name in ipairs({'lastThird','middleThird','firstThird','lastThird'}) do
  instance:run('window.cycleThirds');assert(isLayout(name))
end
currentFrame=rect(100,100,600,400) -- External resize starts from the first slot.
instance:run('window.cycleThirds');assert(isLayout('lastThird'))
instance:run('screen.left');instance:run('window.cycleThirds');assert(isLayout('middleThird'))
instance:run('window.restoreDown')
assert(math.abs(currentFrame.w-800)<.001 and currentFrame.x<0)
instance:run('resize.right');assert(math.abs(currentFrame.w-810)<.001)
local oldHeight=currentFrame.h
instance:run('resize.down');assert(math.abs(currentFrame.h-oldHeight-10)<.001)
assert(not instance.palette.visible)
for _,area in ipairs({rect(0,30,1200,870),rect(-1729,-500,1729,971)}) do
  for name,cycle in pairs(model.layoutCycles) do
    assert(geometry.cycleLayout(model,name,rect(100,100,500,500),area)==cycle[1])
    for i,layout in ipairs(cycle) do
      local r=model.layouts[layout]
      local frame=rect(math.floor(area.x+area.w*r[1]+.5),area.y,math.floor(area.w*r[3]+.5),area.h)
      assert(geometry.cycleLayout(model,name,frame,area)==cycle[i % #cycle+1])
    end
  end
end
for _,key in ipairs(keys) do
  if key.key=='h' and #key.mods==4 then key.press();key.repeatfn() end
end
assert(pointer.x==80 and pointer.y==100 and not instance.palette.visible)
local navigate
instance.palette.visible=true
instance.palette.navigate=function(_,action)navigate=action end
stroke=nil
for _,key in ipairs(keys) do
  if key.key=='j' and #key.mods==3 then key.press() end
end
assert(navigate=='edit.down' and stroke==nil)
instance.palette.visible=false
remote=true;instance.remoteTimer.fire()
for _,key in ipairs(keys) do assert(key.enabled==(key.key=='escape')) end
remote=false;instance.remoteTimer.fire()
for _,key in ipairs(keys) do assert(key.enabled) end
local choices
instance.apps.apps={{title='Locally discovered editor',path='/Applications/Actual Editor.app'}}
instance.palette.show=function(_,rows)choices=rows end
instance:run('menu.all')
local discovered=0
for _,choice in ipairs(choices) do
  if choice.action:match('^installed%.') then
    assert(choice.text=='Locally discovered editor')
    assert(choice.action=='installed./Applications/Actual Editor.app')
    discovered=discovered+1
  end
  assert(not choice.action:match('^role%.') and choice.action~='launch.trae')
  assert(choice.action~='menu.window')
end
assert(discovered==1)
for role in pairs(model.roles) do
  local count=0
  for _,choice in ipairs(choices) do if choice.action=='app.'..role then count=count+1 end end
  assert(count==1,role..' must be searchable exactly once')
end
instance:run('menu.help')
for _,choice in ipairs(choices) do assert(choice.action~='app.workChat') end
instance:run('menu.roles')
local roleCount=0;for _ in pairs(model.roles) do roleCount=roleCount+1 end
assert(#choices==roleCount)
for _,choice in ipairs(choices) do assert(choice.navigate) end
instance:run('role.workChat')
local workChoice
for _,choice in ipairs(choices) do if choice.action=='setrole.workChat.feishu' then workChoice=true end end
assert(workChoice)
-- Number-row app search is apps-only, configuration retains nested navigation.
instance:run('menu.apps');assert(#choices==1 and choices[1].action:match('^installed%.'))
instance:run('menu.config');assert(#choices==10)
assert(choices[4].shortcut=='c' and choices[4].navigate)
assert(instance.roles:get('editor')=='sublime')
instance:run('menu.clipboard')
for _,choice in ipairs(choices) do
  if choice.action=='clipboard.history' or choice.action=='clipboard.targets' then assert(choice.navigate)
  elseif choice.action=='clipboard.send' then assert(not choice.navigate) end
end
instance:run('clipboard.history');assert(#choices==1 and choices[1].action=='clipboard.enableHistory' and choices[1].navigate)
local picked,deviceCallback,opened
local output={name=function()return 'Speakers' end,uid=function()return 'output.uid' end,
  setDefaultOutputDevice=function()picked='output';return true end}
local input={name=function()return 'Microphone' end,uid=function()return 'input.uid' end,
  setDefaultInputDevice=function()picked='input';return true end}
hs.audiodevice={allOutputDevices=function()return {output}end,allInputDevices=function()return {input}end,
  defaultOutputDevice=function()return output end,defaultInputDevice=function()return input end,
  findOutputByUID=function(uid)if uid=='output.uid' then return output end end,
  findInputByUID=function(uid)if uid=='input.uid' then return input end end}
instance.palette.show=function(_,rows,opts,callback)choices=rows;deviceCallback=callback end
instance:run('system.audioOutput');assert(choices[1].text=='Speakers');deviceCallback(choices[1]);assert(picked=='output')
instance:run('system.audioInput');assert(choices[1].text=='Microphone');deviceCallback(choices[1]);assert(picked=='input')
hs.urlevent={openURLWithBundle=function(url,bundle)assert(bundle=='com.apple.systempreferences');opened=url;return true end}
instance:run('system.displays');assert(opened=='x-apple.systempreferences:com.apple.Displays-Settings.extension')
instance:run('system.focus');assert(opened=='x-apple.systempreferences:com.apple.Focus-Settings.extension')
-- Portrait primary actions need no Fn/PageUp/PageDown. Physical supplementary
-- top/bottom layouts must not be rotated a second time.
local originalArea=primary.frame
primary.frame=function()return rect(0,30,900,1500)end
currentScreen=primary;currentFrame=rect(100,100,500,400)
instance.maximized={};instance.snapped={};instance.managed={};instance.minimized={}
instance:run('window.left');assert(geometry.sameFrame(currentFrame,rect(0,30,900,750)))
instance:run('window.up');assert(geometry.sameFrame(currentFrame,primary:frame()))
instance:run('window.down');assert(geometry.sameFrame(currentFrame,rect(0,30,900,750)))
instance:run('window.right');assert(geometry.sameFrame(currentFrame,rect(0,780,900,750)))
instance:run('window.top');assert(geometry.sameFrame(currentFrame,rect(0,30,900,750)))
instance:run('window.bottom');assert(geometry.sameFrame(currentFrame,rect(0,780,900,750)))
for _,case in ipairs({{'cycleTwoThirds',{'twoThirds','lastTwoThirds','twoThirds'}},
    {'cycleThirds',{'lastThird','middleThird','firstThird','lastThird'}}}) do
  currentFrame=rect(100,100,500,400)
  for _,name in ipairs(case[2]) do
    instance:run('window.'..case[1])
    local r=geometry.layout(model,name,primary:frame())
    assert(geometry.sameFrame(currentFrame,rect(900*r[1],30+1500*r[2],900*r[3],1500*r[4])))
    assert(currentFrame.w==900)
  end
end
primary.frame=originalArea
-- Excluded/sensitive copies are consumed without ever reading their text.
local clipCount,reads,types=0,0,{}
hs.settings.get=function(key)return key=='hyper.clipboardHistory' end
hs.pasteboard.changeCount=function()return clipCount end
hs.pasteboard.contentTypes=function()return types end
hs.pasteboard.getContents=function()reads=reads+1;return 'ordinary test text' end
local blocked={name=function()return 'MacPass'end,bundleID=function()return 'com.hicknhacksoftware.MacPass'end}
local safe={name=function()return 'Editor'end,bundleID=function()return 'test.editor'end}
hs.application.frontmostApplication=function()return safe end
clipCount=1;instance.clipWatcher.fire(nil,hs.application.watcher.deactivated,blocked)
instance.clipTimer.fire();assert(reads==0 and #instance.clips==0)
clipCount=2;types={'org.nspasteboard.ConcealedType'}
instance.clipTimer.fire();assert(reads==0 and #instance.clips==0)
clipCount=3;types={'public.utf8-plain-text'}
instance.clipTimer.fire();assert(reads==1 and #instance.clips==1)
instance:stop()
print('Hyper: toggle, ratios, undo/max restore, selection, directional screen and remote ownership passed')
