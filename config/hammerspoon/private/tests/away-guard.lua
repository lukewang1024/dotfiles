local stored, locks, brightness, now = nil, 0, 0.4, 100
local count, allowStart, allowDarken, pending = 3, true, true, nil
local remoteFullscreen, remoteVisible, remoteMoves = true, false, 0
local remoteApp = {bundleID=function()return 'com.microsoft.rdc.macos' end}
local remoteWindow = {title=function()return 'Test RDP session' end,id=function()return 77 end, application=function()return remoteApp end, screen=function()return {getUUID=function()return 'external-screen' end}end,
  isFullScreen=function()return remoteFullscreen end,setFullScreen=function(_,value)remoteFullscreen=value end,moveToScreen=function()remoteMoves=remoteMoves+1 end}
remoteApp.allWindows=function()return {remoteWindow} end
local display = {}
function display:name() return 'Built-in Retina Display' end
function display:getUUID() return 'internal' end
function display:getBrightness() return brightness end
function display:setBrightness(value) if value ~= 0 or allowDarken then brightness = value end end
local external = {name=function()return 'External' end,getUUID=function()return 'external' end}
local function watcher(callback)
  return {callback=callback,start=function(self)return self end,stop=function()end}
end
local events={screensDidLock=1,screensDidUnlock=2,systemWillSleep=3,systemDidWake=4,new=watcher}
hs={spaces={windowSpaces=function()return {42}end,allSpaces=function()return {['space-screen']={42}}end},axuielement={applicationElement=function()return {attributeValue=function()return {{asHSWindow=function()return remoteWindow end}} end}end},configdir='/config',
  settings={get=function()return stored end,set=function(_,v)stored=v end,clear=function()stored=nil end},
  alert={show=function()end},printf=function()end,
  json={decode=function()return pending end,encode=function()return '[]' end},
  window={get=function(id)if remoteVisible and id==77 then return remoteWindow end end},
  application={get=function()return remoteVisible and remoteApp end,runningApplications=function()return remoteVisible and {remoteApp} or {} end},
  screen={allScreens=function()return count==0 and {external} or count==1 and {display} or {display,external} end,
    find=function()return display end,watcher={new=watcher}},
  task={new=function(path,callback,stream,args)
    if type(stream)=='table' then args,stream=stream,nil end
    return {path=path,args=args,callback=callback,stream=stream,running=false,
      start=function(self)self.running=allowStart;return allowStart and self or false end,
      terminate=function(self)self.running=false;callback(15,'','')end,
      isRunning=function(self)return self.running end,
      setInput=function(self,value)assert(stored.external[1]=='external');self.input=value end}
  end},
  timer={secondsSinceEpoch=function()return now end,doEvery=function(interval,callback)assert(interval==0.3);return watcher(callback)end},
  caffeinate={lockScreen=function()locks=locks+1 end,watcher=events},
}
local module=dofile('config/hammerspoon/private/modules/away-guard.lua')
local function send(guard,event,fields)
  pending=fields or {};pending.event=event
  guard.monitor.stream(guard.monitor,'message\n','')
end
local function setup(guard)
  assert(guard:arm() and guard.state=='preparing' and brightness==0.4)
  send(guard,'snapshot',{internal='internal',external={'external'}})
  assert(stored.external[1]=='external' and guard.monitor.input=='disable\n')
  guard.displays.callback();assert(guard.state=='preparing') -- own disable is expected
  count=1;send(guard,'ready');assert(guard.state=='armed' and brightness==0)
end
local function unlock(guard,code)
  guard.power.callback(events.screensDidLock)
  guard.power.callback(events.screensDidUnlock)
  assert(guard.state=='restoring' and brightness==0.4 and not guard.keepAwake and not guard.monitor)
  assert(guard.restorer.args[3]=='external')
  guard.restorer.callback(code or 0,'','')
end
local guard=module.new()
count=0;assert(not guard:arm() and not stored);count=3
setup(guard);guard:check();assert(locks==0)
brightness=0.00001;guard:check();assert(guard.state=='locking' and locks==1)
guard:check();assert(locks==2)
guard.power.callback(events.screensDidLock);guard:check();assert(locks==2)
unlock(guard);assert(guard.state=='idle' and not stored)
setup(guard);guard.displays.callback();assert(guard.state=='locking');unlock(guard)
setup(guard);send(guard,'changed',{reason='disabled screen unplugged'});assert(guard.state=='locking');unlock(guard)
setup(guard);guard.keepAwake.running=false;guard:check();assert(guard.state=='locking');unlock(guard)
setup(guard);guard.monitor.callback(1,'','');assert(guard.state=='locking');unlock(guard)
setup(guard);now=now+2;guard:check();assert(guard.state=='locking');unlock(guard)
setup(guard);brightness=nil;guard:check();assert(guard.state=='locking');unlock(guard)
setup(guard);count=2;guard:check();assert(guard.state=='locking');unlock(guard);count=1
setup(guard);guard:stop();assert(stored and not guard.keepAwake and not guard.monitor)
local recovered=module.new();assert(recovered.state=='locking' and recovered.external[1]=='external')
unlock(recovered,1);assert(recovered.state=='restoreFailed' and stored)
recovered:returnAndLock();assert(recovered.state=='locking');unlock(recovered);assert(not stored)
assert(recovered:arm());send(recovered,'snapshot',{internal='internal',external={'external'}})
now=now+26;recovered:check();assert(recovered.state=='locking');unlock(recovered)
assert(recovered:arm());send(recovered,'snapshot',{internal='wrong',external={}})
assert(recovered.state=='locking');recovered:stop()
-- A late setup completion cannot arm after another event requested a lock.
stored=nil;brightness=0.4
local late=module.new();assert(late:arm())
send(late,'snapshot',{internal='internal',external={'external'}})
late.power.callback(events.systemWillSleep);send(late,'ready');assert(late.state=='locking' and brightness==0.4)
unlock(late);late:stop()
-- Failed darkening fails closed and keeps the external restore snapshot.
local dark=module.new();assert(dark:arm());send(dark,'snapshot',{internal='internal',external={'external'}})
allowDarken=false;send(dark,'ready');assert(dark.state=='locking' and stored.external[1]=='external')
allowDarken=true;unlock(dark);dark:stop()
assert(not stored)
-- RDP native fullscreen is left BEFORE disabling displays and restored only after unlock.
remoteVisible=true;remoteFullscreen=true
local rdp=module.new({remoteWindows=function()return {remoteWindow}end});assert(rdp:arm() and rdp.remotePreparing and not rdp.monitor)
assert(not remoteFullscreen and stored.remoteWindows[1].id==77 and stored.remoteWindows[1].screen=='space-screen')
local originalGet=hs.window.get
hs.window.get=function()return nil end
remoteApp.allWindows=function()return {} end
hs.axuielement.applicationElement=function()return {attributeValue=function()return {}end}end -- Only the window-filter cache sees the inactive Space.
rdp:check();rdp:check();assert(not rdp.monitor)
rdp:check();assert(rdp.monitor and not rdp.remotePreparing)
send(rdp,'snapshot',{internal='internal',external={'external'}})
send(rdp,'progress',{online={1}})
count=1;send(rdp,'ready');assert(rdp.state=='armed' and brightness==0)
brightness=0.01;rdp:check();assert(rdp.state=='locking')
rdp.power.callback(events.screensDidLock);rdp.power.callback(events.screensDidUnlock)
assert(not remoteFullscreen and rdp.state=='restoring')
rdp.restorer.callback(0,'','');assert(remoteFullscreen and remoteMoves==1 and not stored)
rdp:stop();hs.window.get=originalGet
hs.axuielement.applicationElement=function()return {attributeValue=function()return {{asHSWindow=function()return remoteWindow end}}end}end
-- A failed/slow fullscreen exit cannot disable screens prematurely.
remoteFullscreen=true
local stuck=module.new();assert(stuck:arm());remoteFullscreen=true
now=now+21;stuck:check();assert(stuck.state=='locking' and not stuck.monitor)
stuck:stop()
local restart=module.new();assert(restart.remoteWindows[1].id==77)
restart.power.callback(events.screensDidLock);restart.power.callback(events.screensDidUnlock)
restart.restorer.callback(0,'','');assert(remoteFullscreen and not stored)
restart:stop();remoteVisible=false
print('Away guard: async setup, persistence, exact positive brightness, display events, topology changes, watchdogs, lock retry, unlock restore, reload recovery and restore failure passed')
