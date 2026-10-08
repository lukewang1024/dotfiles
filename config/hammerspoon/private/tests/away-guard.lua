local stored, locks, brightness, now = nil, 0, 0.4, 100
local count, allowStart, allowDarken, pending = 3, true, true, nil
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
hs={configdir='/config',
  settings={get=function()return stored end,set=function(_,v)stored=v end,clear=function()stored=nil end},
  alert={show=function()end},printf=function()end,
  json={decode=function()return pending end},
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
now=now+21;recovered:check();assert(recovered.state=='locking');unlock(recovered)
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
print('Away guard: async setup, persistence, exact positive brightness, display events, topology changes, watchdogs, lock retry, unlock restore, reload recovery and restore failure passed')
