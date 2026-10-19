-- Machine-local unattended desktop permission. Notifications are hints; the
-- short-lived atomic snapshot is the authority and expires if Hammerspoon stops.
local M = {}
M.notification = 'dev.machine-fabric.desktop-availability-changed'
function M.new(options)
  options = options or {}
  local root = (os.getenv('XDG_STATE_HOME') or os.getenv('HOME') .. '/.local/state') .. '/machine-fabric'
  local path = options.path or root .. '/desktop-availability.json'
  local generation = options.generation or hs.host.uuid()
  local sequence, lastAvailable, lastState = 0, nil, nil
  local notifyTask
  local function wakeWorker()
    -- NSDistributedNotificationCenter delivers on the main runloop; a headless
    -- worker needs Darwin descriptor delivery instead. Keep the poster async so
    -- notification IPC can never block the guard's lock/check loop.
    if notifyTask and notifyTask:isRunning() then return end
    local task
    task = hs.task.new('/usr/bin/notifyutil', function(code)
      if notifyTask == task then notifyTask = nil end
      if code ~= 0 then hs.printf('[away-guard] Worker wake failed: %s', tostring(code)) end
    end, {'-p', M.notification})
    if task and task:start() then notifyTask = task
    else hs.printf('[away-guard] Worker wake could not start; snapshot expiry remains authoritative') end
  end
  local function write(snapshot)
    if options.sink then return options.sink(snapshot) end
    local directory = ''
    for part in path:match('^(.*)/[^/]+$'):gmatch('[^/]+') do
      directory = directory .. '/' .. part
      if not hs.fs.attributes(directory) then assert(hs.fs.mkdir(directory)) end
    end
    local temporary = path .. '.' .. generation .. '.tmp'
    local file = assert(io.open(temporary, 'w'))
    local ok, error = file:write(hs.json.encode(snapshot), '\n')
    local closed, closeError = file:close()
    assert(ok, error); assert(closed, closeError)
    assert(os.rename(temporary, path))
  end
  return {path=path, publish=function(_, guard)
    local now = hs.timer.secondsSinceEpoch()
    local session = hs.caffeinate.sessionProperties()
    local age = guard.lastHeartbeat and now - guard.lastHeartbeat
    local available = guard.state == 'armed' and not guard.stopped
      and session ~= nil and session.CGSSessionScreenIsLocked ~= true
      and age ~= nil and age >= 0 and age <= 1.5
      and guard.monitor ~= nil and guard.monitor:isRunning()
      and guard.keepAwake ~= nil and guard.keepAwake:isRunning()
    sequence = sequence + 1
    local snapshot = {schemaVersion=1,provider='away-guard',generation=generation,
      sequence=sequence,state=guard.state,available=available,
      observedAtMs=math.floor(now*1000),expiresAtMs=math.floor((now+1.5)*1000)}
    -- Always refresh the lease; broadcast only transitions, never every heartbeat.
    write(snapshot)
    if lastAvailable ~= available or lastState ~= guard.state then
      lastAvailable, lastState = available, guard.state
      if options.broadcast then options.broadcast(snapshot)
      else
        wakeWorker()
        hs.distributednotifications.post(M.notification, 'dev.machine-fabric.away-guard',
        {generation=generation,sequence=sequence,available=available,state=guard.state}) end
    end
    return snapshot
  end}
end
return M
