local stored, locks, brightness, count, alive = nil, 0, 0.4, 1, false
local display = {}
function display:name() return 'Built-in Retina Display' end
function display:getUUID() return 'internal' end
function display:getBrightness() return brightness end
function display:setBrightness(value) brightness = value end
local function watcher(callback)
  return {callback=callback,start=function(self)return self end,stop=function()end}
end
local events={screensDidLock=1,screensDidUnlock=2,systemWillSleep=3,systemDidWake=4,new=watcher}
hs={
  settings={get=function()return stored end,set=function(_,v)stored=v end,clear=function()stored=nil end},
  alert={show=function()end},printf=function()end,
  screen={allScreens=function()return count==1 and {display} or {display,display} end,
    find=function()return display end,watcher={new=watcher}},
  task={new=function(_,callback)return {
    start=function(self)alive=true;return self end,
    terminate=function()alive=false;callback()end,isRunning=function()return alive end}end},
  timer={doEvery=function(_,callback)return watcher(callback)end},
  caffeinate={lockScreen=function()locks=locks+1 end,watcher=events},
  menubar={new=function()return {setTitle=function()end,setMenu=function()end,delete=function()end}end},
}
local module=dofile('config/hammerspoon/private/modules/away-guard.lua')
local guard=module.new()
count=2;assert(not guard:arm() and brightness==0.4 and not alive)
count=1;assert(guard:arm() and brightness==0 and alive and stored)
guard:check();assert(locks==0)
brightness=0.1;guard:check();assert(locks==1 and guard.state=='locking')
guard:check();assert(locks==2)
guard.power.callback(events.screensDidLock);guard:check();assert(locks==2)
guard.power.callback(events.screensDidUnlock)
assert(guard.state=='idle' and brightness==0.4 and not alive and not stored)
assert(guard:arm());guard.displays.callback();assert(guard.state=='locking')
guard:stop();assert(stored and not alive)
local recovered=module.new();assert(recovered.state=='locking')
recovered.power.callback(events.screensDidLock);recovered.power.callback(events.screensDidUnlock)
assert(brightness==0.4 and stored==nil)
assert(recovered:arm());alive=false;recovered:check();assert(recovered.state=='locking')
recovered.power.callback(events.screensDidUnlock)
assert(recovered:arm());brightness=nil;recovered:check();assert(recovered.state=='locking')
recovered.power.callback(events.screensDidUnlock);recovered:stop()
print('Away guard: preflight, brightness, display events, lock retry, unlock restore, reload recovery and process failure passed')
