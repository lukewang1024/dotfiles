package.path='config/hammerspoon/?.lua;'..package.path
local now, locked, propertiesReadable = 100, nil, true
hs={timer={secondsSinceEpoch=function()return now end,absoluteTime=function()return now*1000000000 end},caffeinate={sessionProperties=function()if propertiesReadable then return {CGSSessionScreenIsLocked=locked} end end}}
local module=require('private/modules/away-guard-availability')
local snapshots, notifications = {}, {}
local publisher=module.new({generation='instance',sink=function(s)snapshots[#snapshots+1]=s end,
  broadcast=function(s)notifications[#notifications+1]=s end})
local live={isRunning=function()return true end}
local guard={state='idle',monitor=live,keepAwake=live,lastHeartbeat=100}
assert(not publisher:publish(guard).available)
guard.state='armed';assert(publisher:publish(guard).available)
assert(#notifications==2)
now=100.3;assert(publisher:publish(guard).available and #notifications==2)
locked=true;assert(not publisher:publish(guard).available and #notifications==3)
locked=nil;now=109.999;assert(publisher:publish(guard).available)
now=110.001;assert(not publisher:publish(guard).available)
now=102
guard.lastHeartbeat=102;assert(publisher:publish(guard).available)
propertiesReadable=false;assert(not publisher:publish(guard).available)
propertiesReadable=true;guard.stopped=true;assert(not publisher:publish(guard).available)
guard.stopped=false;guard.monitor=nil;assert(not publisher:publish(guard).available)
guard.monitor=live;guard.lastHeartbeat=103;assert(not publisher:publish(guard).available)
assert(snapshots[1].sequence==1 and snapshots[#snapshots].sequence==#snapshots)
assert(snapshots[1].expiresAtMs-snapshots[1].observedAtMs==10000)
-- A failed sink must never broadcast an uncommitted grant.
local bad=module.new({generation='bad',sink=function()error('disk full')end,broadcast=function()error('must not broadcast')end})
assert(not pcall(bad.publish,bad,guard))
print('Away Guard availability: transition broadcast, heartbeat expiry, lock and helper gating passed')

-- Transport expiry uses monotonic time even if the wall clock jumps.
guard={state='armed',monitor=live,keepAwake=live,lastHeartbeat=now}
hs.timer.secondsSinceEpoch=function()return now+500000 end
local shifted=publisher:publish(guard)
assert(shifted.available and shifted.expiresAtMs-shifted.observedAtMs==10000)
hs.timer.secondsSinceEpoch=function()return now end

-- Default transport retains one async poster and coalesces in-flight wakeups.
local tasks, distributed = {}, 0
hs.printf=function()end
hs.distributednotifications={post=function()distributed=distributed+1 end}
hs.task={new=function(path,callback,args)
  assert(path=='/usr/bin/notifyutil' and args[1]=='-p' and args[2]==module.notification)
  local task={running=false,callback=callback}
  function task:start()self.running=true;return self end
  function task:isRunning()return self.running end
  tasks[#tasks+1]=task;return task
end}
local livePublisher=module.new({generation='transport',sink=function()end})
guard={state='idle',lastHeartbeat=now,monitor=live,keepAwake=live}
livePublisher:publish(guard);assert(#tasks==1 and distributed==1)
guard.state='armed';livePublisher:publish(guard);assert(#tasks==1 and distributed==2)
tasks[1].running=false;tasks[1].callback(0)
guard.state='locked';livePublisher:publish(guard);assert(#tasks==2 and distributed==3)
print('Away Guard broadcast: async Darwin wake retention and coalescing passed')
