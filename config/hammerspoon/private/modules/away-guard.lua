-- Opt-in guard for unattended GUI automation. Never consumes mouse/key events.
local M = {}
-- Failed recovery retains its retry snapshot but has no active display/window
-- operation. Let the user arrange windows while keeping that recovery available.
function M.suspendsWindowLayout(state)
  return state ~= 'idle' and state ~= 'restoreFailed'
end
local i18n = require('private/modules/away-guard-i18n')
local timing = require('private/modules/away-guard-timing')
function M.new(options)
  options = options or {}
  local self = {state = 'idle', external = {}}
  local availability = options.availability or require('private/modules/away-guard-availability').new(options.availabilityOptions)
  local layout = options.layout or require('private/modules/away-guard-windows').new(options)
  local audit = options.audit or require('private/modules/away-guard-log').new()
  local function diagnostic(error) pcall(hs.printf, '[away-guard] %s', tostring(error)) end
  local function publishAvailability()
    local ok, error = pcall(availability.publish, availability, self)
    if not ok then diagnostic(error) end -- Never prevent the guard's lock action.
  end
  local function write(event, fields)
    publishAvailability()
    fields = fields or {}
    fields.monotonic = timing.now()
    fields.health = {helperSequence=self.helperSequence,helperCheckUptime=self.lastHeartbeat,
      helperHeartbeatAge=self.lastHeartbeat and timing.now()-self.lastHeartbeat,
      parentSequence=self.parentSequence,parentSentUptime=self.parentSentUptime,
      helperMaxGap=self.helperMaxGap,helperGapBuckets=self.helperGapBuckets,
      native=self.nativeHealth,snapshotLifetimeMs=timing.snapshotLifetimeMs,
      helperHeartbeatSeconds=timing.helperHeartbeatSeconds}
    local ok, record = pcall(audit.write, event, fields)
    if ok then return record end
    diagnostic(record)
    fields = fields or {}; fields.event = event
    return fields
  end
  local function requestLock()
    local ok, error = pcall(hs.caffeinate.lockScreen)
    if not ok then diagnostic(error) end
  end
  self.logPath = audit.path
  local marker = 'awayGuard.session'
  local saved = hs.settings.get(marker)
  local helper = hs.configdir .. '/private/helpers/away-guard-display'
  local function notify(key, values) hs.alert.show(i18n.t(key, values), 4) end
  local function persist()
    hs.settings.set(marker, {screen = self.screen, brightness = self.originalBrightness, external = self.external, remoteWindows = self.remoteWindows, windowLayout = self.windowLayout, trigger = self.trigger, autoBrightness = self.autoBrightness})
  end
  local function release()
    local task = self.keepAwake; self.keepAwake = nil
    if task then task:terminate() end
  end
  local function stopMonitor(authenticated)
    local task = self.monitor; self.monitor = nil
    if task then
      if authenticated then task:setInput('disarm\n')
      else task:terminate() end
    end
  end
  local function displaySignature()
    local result = {}
    for _,screen in ipairs(hs.screen.allScreens()) do
      local frame = screen:fullFrame()
      local mode = screen:currentMode() or {}
      result[#result+1] = string.format('%s:%g:%g:%g:%g:%s:%s:%s:%s', screen:getUUID(),
        frame.x,frame.y,frame.w,frame.h,tostring(mode.w),tostring(mode.h),tostring(mode.scale),tostring(mode.freq))
    end
    table.sort(result)
    return table.concat(result, ';')
  end
  local function trip(reason)
    if self.state == 'idle' or self.state == 'locked' or self.state == 'restoring' then return end
    local previous = self.state
    self.state = 'locking'
    requestLock() -- Safety action precedes every fallible diagnostic operation.
    if previous ~= 'locking' then
      self.trigger = {reason=reason,state=previous}
      local ok, error = pcall(function()
        local screens = {}
        for _,screen in ipairs(hs.screen.allScreens()) do
          screens[#screens+1] = {uuid=screen:getUUID(),brightness=screen:getBrightness()}
        end
        self.trigger = write('lock_requested', {reason=reason,state=previous,screens=screens,
          heartbeatAge=self.lastHeartbeat and timing.now()-self.lastHeartbeat,
          intentSource=reason=='manual return' and 'away_guard_return' or nil})
        hs.settings.set('awayGuard.lastTrigger', self.trigger)
        persist()
      end)
      if not ok then diagnostic(error) end
    end
  end
  local function protect(callback)
    return function(...)
      local ok, result = pcall(callback, ...)
      if not ok then
        if self.state ~= 'idle' and self.state ~= 'restoreFailed' then
          self.state = 'locking'; requestLock()
        end
        publishAvailability()
        diagnostic(result)
        return false
      end
      publishAvailability()
      return result
    end
  end
  local function remoteWindowsFor(application)
    -- application:allWindows()/window.get() omit inactive/fullscreen Spaces.
    -- Read AXWindows directly, preserving references to the session itself.
    local windows, seen = {}, {}
    local function add(window)
      if window and window:application():bundleID() == application:bundleID() and not seen[window:id()] then
        seen[window:id()] = true; windows[#windows+1] = window
      end
    end
    -- The existing remote-window filter retains AX references across inactive
    -- Spaces, where even a fresh AXWindows query can temporarily omit a session.
    if options.remoteWindows then
      for _,window in ipairs(options.remoteWindows()) do add(window) end
    end
    local ax = hs.axuielement.applicationElement(application)
    for _,element in ipairs(ax:attributeValue('AXWindows') or {}) do
      local window = element:asHSWindow()
      add(window)
    end
    return windows
  end
  local function remoteWindow(savedWindow, requireFrame)
    local application = hs.application.get(savedWindow.bundle)
    if not application then return nil end
    local match
    for _,candidate in ipairs(remoteWindowsFor(application)) do
      local frame = requireFrame and candidate:frame()
      -- Windows App can recreate the session window; cached AX references then have a zero frame.
      if not requireFrame or (frame and frame.w > 0 and frame.h > 0) then
        if candidate:id() == savedWindow.id and (not savedWindow.title or candidate:title() == savedWindow.title) then return candidate end
        if savedWindow.title and candidate:title() == savedWindow.title then
          if match then return nil end -- Never select an ambiguous session.
          match = candidate
        end
      end
    end
    return match -- Windows App may recreate its AX window during Space changes.
  end
  local function remoteScreen(window)
    -- An inactive fullscreen AX frame can be stale; Space ownership is authoritative.
    if hs.spaces then
      local spaces = hs.spaces.windowSpaces(window) or {}
      for uuid,list in pairs(hs.spaces.allSpaces() or {}) do
        for _,space in ipairs(spaces) do
          for _,candidate in ipairs(list) do if candidate == space then return uuid end end
        end
      end
    end
    local screen = window:screen()
    return screen and screen:getUUID()
  end
  local function restoreRemoteWindows()
    for _,savedWindow in ipairs(self.remoteWindows or {}) do
      local window = remoteWindow(savedWindow, true)
      if window then
        local screen = savedWindow.screen and hs.screen.find(savedWindow.screen)
        if not screen then error('RDP original display missing: ' .. tostring(savedWindow.screen)) end
        window:moveToScreen(screen)
        window:setFullScreen(true)
      elseif hs.application.get(savedWindow.bundle) then
        error('RDP session window unavailable during restore')
      end
    end
    self.remoteWindows = {}
  end
  local function restore()
    if self.state == 'restoring' then return end
    local retry = self.state == 'restoreFailed'
    self.state = 'restoring'
    self.restoreGeneration = (self.restoreGeneration or 0) + 1
    local generation = self.restoreGeneration
    local function current() return not self.stopped and self.state == 'restoring' and generation == self.restoreGeneration end
    write('restore_started')
    stopMonitor(true)
    if self.screen and self.originalBrightness ~= nil then
      local screen = hs.screen.find(self.screen)
      if screen then screen:setBrightness(self.originalBrightness) end
    end
    release()
    local args = {helper, 'restore'}
    for _,identity in ipairs(self.external) do args[#args+1] = identity end
    if self.autoBrightness ~= nil then args[#args+1] = '--auto-brightness=' .. (self.autoBrightness and 'on' or 'off') end
    self.restorer = hs.task.new('/bin/sh', protect(function(code, stdout, stderr)
      if not current() then return end
      self.restorer = nil
      if code == 0 then
        local function complete(report)
          if not current() then return end
          write('windows_restored', report)
          local ok, error = pcall(restoreRemoteWindows)
          if not ok or #report.failed > 0 then
            -- Window geometry is best effort; never retain an active guard for it.
            local retained, error = pcall(hs.settings.set, 'awayGuard.lastWindowRecovery', {snapshot=self.windowLayout,
              remoteWindows=self.remoteWindows,report=report,rdpError=not ok and tostring(error) or nil})
            if not retained then diagnostic(error) end
            write('window_recovery_incomplete', {report=report,rdpError=not ok and tostring(error) or nil})
          end
          hs.settings.clear(marker)
          self.state = 'idle'
          self.nextRestoreRetry = nil
          write('restore_complete', {reason=self.trigger and self.trigger.reason})
          if not ok or #report.failed > 0 then notify('windowsRestoreIncomplete')
          else notify('restored', {reason=i18n.reason(self.trigger and self.trigger.reason)}) end
        end
        local ok, error = pcall(function() layout:restore(self.windowLayout, protect(complete)) end)
        if not ok then complete({restored=0,closed=0,failed={{reason=tostring(error)}}}) end
      else
        self.state = 'restoreFailed'
        self.nextRestoreRetry = hs.timer.secondsSinceEpoch() + 15
        write('restore_failed', {stage='displays',code=code,stdout=stdout,stderr=stderr})
        if not retry then notify('displaysRestoreFailed') end
      end
    end), args)
    if not self.restorer or not self.restorer:start() then
      self.restorer = nil; self.state = 'restoreFailed'
      self.nextRestoreRetry = hs.timer.secondsSinceEpoch() + 15
      if not retry then notify('restoreStartFailed') end
    end
  end
  function self:retryRestore()
    if self.stopped or self.state ~= 'restoreFailed' then return false end
    local session = hs.caffeinate.sessionProperties and hs.caffeinate.sessionProperties()
    if session and session.CGSSessionScreenIsLocked then return false end
    write('restore_retry')
    restore()
    return true
  end
  function self:check()
    -- Disabled displays can stay absent from hs.screen, even after reconnection.
    -- Retry the native hardware enumeration without relying on a screen event.
    if self.state == 'restoreFailed' then
      if hs.timer.secondsSinceEpoch() >= (self.nextRestoreRetry or 0) then self:retryRestore() end
      return
    end
    if self.state == 'locking' then requestLock(); return end
    if self.state ~= 'armed' and self.state ~= 'preparing' then return end
    if self.monitor and self.monitorAuthorized then
      self.parentSequence = (self.parentSequence or 0) + 1
      self.parentSentUptime = timing.now()
      self.monitor:setInput(string.format('heartbeat %d %.9f\n', self.parentSequence, self.parentSentUptime))
    end
    if not self.keepAwake or not self.keepAwake:isRunning() then trip('keep-awake process stopped'); return end
    if self.state == 'preparing' and self.remotePreparing then
      if hs.timer.secondsSinceEpoch() > self.deadline then trip('RDP fullscreen exit timed out'); return end
      for _,savedWindow in ipairs(self.remoteWindows) do
        local window = remoteWindow(savedWindow)
        if not window then self.remoteSettled = 0; return end
        if window:isFullScreen() then self.remoteSettled = 0; return end
      end
      self.remoteSettled = self.remoteSettled + 1
      if self.remoteSettled >= 3 then
        self.remotePreparing = false
        hs.printf('[away-guard] RDP fullscreen settled; disabling external displays')
        self:beginDisplays()
      end
      return
    end
    if not self.monitor or not self.monitor:isRunning() then trip('display monitor stopped'); return end
    if self.state == 'preparing' then
      if hs.timer.secondsSinceEpoch() > self.deadline then trip('display setup timed out') end
      return
    end
    if timing.now() - self.lastHeartbeat > timing.helperHeartbeatSeconds then trip('display monitor heartbeat timed out'); return end
    local screens = hs.screen.allScreens()
    if #screens ~= 1 or screens[1]:getUUID() ~= self.screen then trip('display changed'); return end
    local brightness = screens[1]:getBrightness()
    if brightness == nil or brightness > 0 then trip('brightness increased or unreadable: ' .. tostring(brightness)) end
  end
  function self:beginDisplays()
    self.deadline = hs.timer.secondsSinceEpoch() + 25
    self.monitorAuthorized = false
    self.awaitingArm = false
    self.helperSequence, self.lastHeartbeat, self.helperMaxGap, self.nativeHealth = nil, nil, 0, nil
    self.helperGapBuckets = {underHalfSecond=0,underTwoSeconds=0,underTenSeconds=0,overTenSeconds=0}
    self.parentSequence, self.parentSentUptime = 0, nil
    local function heartbeat(event)
      local sequence, checked = event.sequence, event.checkedAtUptime
      if type(sequence)~='number' or sequence<0 or sequence%1~=0 or type(checked)~='number'
        or checked~=checked or checked<0 or checked>timing.now() then
        trip('invalid display monitor heartbeat'); return false
      end
      -- Native send time, not pipe delivery time, is the freshness authority.
      -- Old/reordered frames cannot revive the lease after a stalled Lua loop.
      if self.helperSequence and sequence<=self.helperSequence then return false end
      if self.lastHeartbeat and checked<self.lastHeartbeat then return false end
      if self.lastHeartbeat then
        local gap=checked-self.lastHeartbeat
        self.helperMaxGap=math.max(self.helperMaxGap,gap)
        local bucket=gap<=0.5 and 'underHalfSecond' or gap<=2 and 'underTwoSeconds'
          or gap<=10 and 'underTenSeconds' or 'overTenSeconds'
        self.helperGapBuckets[bucket]=self.helperGapBuckets[bucket]+1
      end
      self.helperSequence, self.lastHeartbeat = sequence, checked
      self.nativeHealth = event.health
      return true
    end
    local buffer = ''
    local monitor
    monitor = hs.task.new('/bin/sh', protect(function(code, stdout, stderr)
      if self.monitor ~= monitor or self.stopped then return end
      if self.state == 'armed' or self.state == 'preparing' then
        trip('display monitor exited')
        hs.printf('[away-guard] Monitor exited (%s): %s', code, stderr or '')
      end
    end), protect(function(task, stdout, stderr)
      if self.stopped or self.monitor ~= task then return false end
      buffer = buffer .. (stdout or '')
      while buffer:find('\n', 1, true) do
        local line, remaining = buffer:match('^(.-)\n(.*)$')
        buffer = remaining
        local ok, event = pcall(hs.json.decode, line)
        if not ok or type(event) ~= 'table' then trip('invalid display monitor message'); return false end
        if event.event == 'snapshot' and self.state == 'preparing' then
          if event.internal ~= self.screen or type(event.external) ~= 'table' then trip('display snapshot mismatch'); return false end
          self.external, self.autoBrightness = event.external, event.autoBrightness
          persist() -- Persist before the helper can turn off any external display.
          task:setInput('disable\n')
          self.monitorAuthorized = true
        elseif event.event == 'ready' and self.state == 'preparing' then
          local internal = hs.screen.find(self.screen)
          if not internal then trip('internal screen disappeared'); return false end
          internal:setBrightness(0)
          if internal:getBrightness() ~= 0 then trip('cannot darken internal screen'); return false end
          self.displayBaseline = displaySignature()
          self.awaitingArm = true
          task:setInput('arm\n')
        elseif event.event == 'armed' and self.state == 'preparing' and self.awaitingArm then
          self.awaitingArm = false
          if not heartbeat(event) then return false end
          self.state = 'armed'
          write('armed', {screen=self.screen,external=self.external})
          self:check()
          if self.state == 'armed' then notify('armed') end
        elseif event.event == 'watchdog_lock' then
          self.nativeHealth=event.health
          local incident=write('native_watchdog_lock', {reason=event.reason,state=self.state,
            incidentId=event.incidentId,requestedAtUptime=event.requestedAtUptime})
          if self.state=='locked' then
            -- The independent helper can lock before Lua receives its message.
            if not self.trigger or self.trigger.reason=='system_or_external_lock' then
              self.trigger=incident
              hs.settings.set('awayGuard.lastTrigger',incident)
              persist()
            end
          else trip(event.reason or 'native watchdog requested lock') end
        elseif event.event == 'auto_brightness_disabled' then
          write('auto_brightness_disabled', {previous=event.previous})
        elseif event.event == 'progress' then
          hs.printf('[away-guard] Display setup: online=%s %s', hs.json.encode(event.online or {}), event.reason or '')
        elseif event.event == 'heartbeat' and self.state == 'armed' then
          heartbeat(event)
        elseif event.event == 'changed' or event.event == 'error' then
          trip(event.reason or 'display changed')
          if not self.nativeIncident then write('native_display_event', {details=event});self.nativeIncident=true end
        end
      end
      return true
    end), {helper, 'watch', '--arm-handshake'})
    self.monitor = monitor
    if not self.monitor or not self.monitor:start() then
      self.monitor = nil; restore(); notify('monitorFailed'); return false
    end
    return true
  end
  function self:arm()
    if self.state ~= 'idle' then
      write('arm_rejected', {state=self.state})
      if self.state == 'restoreFailed' then notify('recoveryPending')
      elseif self.state == 'restoring' then notify('restorePending')
      else notify('alreadyArmed') end
      return false
    end
    local screen
    for _,candidate in ipairs(hs.screen.allScreens()) do
      if candidate:name():find('Built%-in') then screen = candidate; break end
    end
    if not screen then notify('openLid'); return false end
    local brightness = screen:getBrightness()
    if brightness == nil then notify('brightnessUnavailable'); return false end
    local ok, snapshot = pcall(function() return layout:capture() end)
    if not ok then write('capture_failed', {reason=tostring(snapshot)});notify('captureFailed');return false end
    self.windowLayout, self.trigger, self.autoBrightness, self.nativeIncident = snapshot, nil, nil, false
    self.unchangedDisplayLogged = false
    self.screen, self.originalBrightness, self.external = screen:getUUID(), brightness, {}
    self.remoteWindows, self.remotePreparing, self.remoteSettled = {}, false, 0
    for _,application in ipairs(hs.application.runningApplications()) do
      if application:bundleID() == 'com.microsoft.rdc.macos' then
        for _,window in ipairs(remoteWindowsFor(application)) do
          if window:isFullScreen() then
            self.remoteWindows[#self.remoteWindows+1] = {id=window:id(), bundle=application:bundleID(), screen=remoteScreen(window), title=window:title()}
          end
        end
      end
    end
    self.remotePreparing = #self.remoteWindows > 0
    local keepAwake
    keepAwake = hs.task.new('/usr/bin/caffeinate', function()
      if self.keepAwake ~= keepAwake or self.stopped then return end
      if self.state == 'armed' or self.state == 'preparing' then trip('keep-awake process exited') end
    end, {'-d', '-i'})
    self.keepAwake = keepAwake
    if not self.keepAwake or not self.keepAwake:start() then release(); notify('keepAwakeFailed'); return false end
    self.state = 'preparing'
    write('preparing', {windows=#self.windowLayout.windows,rdpWindows=#self.remoteWindows})
    self.deadline = hs.timer.secondsSinceEpoch() + 20
    persist()
    if self.remotePreparing then
      hs.printf('[away-guard] Leaving %d RDP fullscreen window(s) before display changes', #self.remoteWindows)
      notify('preparingRdp')
      for _,savedWindow in ipairs(self.remoteWindows) do
        local window = remoteWindow(savedWindow)
        if window then window:setFullScreen(false) end
      end
    else
      return self:beginDisplays()
    end
    return true -- Setup completes asynchronously; the ready message confirms arming.
  end
  self.arm = protect(self.arm)
  self.poll = hs.timer.doEvery(timing.pollSeconds, protect(function() self:check() end))
  self.displays = hs.screen.watcher.new(protect(function()
    if self.state == 'restoreFailed' then self:retryRestore(); return end
    -- Our own initial disable emits configuration changes; helper verifies physical topology during setup.
    if self.state == 'armed' then
      local signature = displaySignature()
      if signature ~= self.displayBaseline then
        trip('display configuration changed')
        write('display_configuration_changed', {before=self.displayBaseline,after=signature})
      elseif not self.unchangedDisplayLogged then
        self.unchangedDisplayLogged = true
        write('display_notification_unchanged', {signature=signature})
      end
    end
  end)):start()
  local events = hs.caffeinate.watcher
  self.power = events.new(protect(function(event)
    if event == events.screensDidLock and self.state == 'restoring' then
      self.restoreGeneration = (self.restoreGeneration or 0) + 1
      self.state = 'locked'
      layout:stop()
      local task = self.restorer; self.restorer = nil
      if task then task:terminate() end
      write('restore_interrupted', {reason='screen locked during recovery'})
      return
    end
    if event == events.screensDidLock and self.state ~= 'idle' and self.state ~= 'restoring' and self.state ~= 'locked' then
      local previous = self.state
      self.state = 'locked'
      local observed = write('lock_observed', {reason=previous == 'locking' and 'guard_requested' or 'system_or_external_lock',
        state=previous,request=self.trigger,source=previous=='locking' and 'away_guard' or 'unknown'})
      if previous ~= 'locking' then
        self.trigger = observed
        hs.settings.set('awayGuard.lastTrigger', self.trigger)
        persist()
      end
    elseif event == events.screensDidUnlock and self.state == 'locked' then
      restore()
    elseif event == events.screensDidUnlock and self.state ~= 'idle' and self.state ~= 'restoring' then
      trip('unlock without observed lock')
    elseif event == events.systemWillSleep then trip('system sleep')
    elseif event == events.systemDidWake then trip('system wake') end
  end)):start()
  function self:lastTrigger() return hs.settings.get('awayGuard.lastTrigger') end
  function self:returnAndLock()
    if self.state == 'idle' then notify('inactive'); return end
    if self.state == 'restoring' then requestLock(); return end
    trip('manual return')
  end
  function self:stop()
    self.stopped = true
    if self.state ~= 'idle' then requestLock() end
    write('stopped', {state=self.state})
    layout:stop()
    self.poll:stop(); self.displays:stop(); self.power:stop()
    stopMonitor(); release()
    if self.restorer then self.restorer:terminate(); self.restorer = nil end
  end
  if saved then
    self.screen, self.originalBrightness, self.external = saved.screen, saved.brightness, saved.external or {}
    self.remoteWindows = saved.remoteWindows or {}
    self.windowLayout, self.trigger, self.autoBrightness = saved.windowLayout, saved.trigger, saved.autoBrightness
    local session = hs.caffeinate.sessionProperties and hs.caffeinate.sessionProperties()
    if options.resumeFailedRecovery and session and not session.CGSSessionScreenIsLocked then
      -- Explicit live handover of an already-unlocked failed recovery. Ordinary
      -- startup/reload still locks before recovering a persisted session.
      self.state = 'restoreFailed'
      self.nextRestoreRetry = 0
    else
      self.state = 'locking'
      requestLock()
    end
    write(self.state == 'restoreFailed' and 'recovery_resumed' or 'recovery_lock', {reason=self.trigger and self.trigger.reason})
  end
  publishAvailability()
  return self
end
return M
