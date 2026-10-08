-- Opt-in guard for unattended GUI automation. Never consumes mouse/key events.
local M = {}
function M.new(options)
  options = options or {}
  local self = {state = 'idle', external = {}}
  local layout = options.layout or require('private/modules/away-guard-windows').new(options)
  local audit = options.audit or require('private/modules/away-guard-log').new()
  self.logPath = audit.path
  local marker = 'awayGuard.session'
  local saved = hs.settings.get(marker)
  local helper = hs.configdir .. '/private/helpers/away-guard-display'
  local function notify(message) hs.alert.show(message, 4) end
  local function persist()
    hs.settings.set(marker, {screen = self.screen, brightness = self.originalBrightness, external = self.external, remoteWindows = self.remoteWindows, windowLayout = self.windowLayout, trigger = self.trigger, autoBrightness = self.autoBrightness})
  end
  local function release()
    local task = self.keepAwake; self.keepAwake = nil
    if task then task:terminate() end
  end
  local function stopMonitor()
    local task = self.monitor; self.monitor = nil
    if task then task:terminate() end
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
    if self.state ~= 'locking' then
      local screens = {}
      for _,screen in ipairs(hs.screen.allScreens()) do
        screens[#screens+1] = {uuid=screen:getUUID(),brightness=screen:getBrightness()}
      end
      self.trigger = audit.write('lock_requested', {reason=reason,state=self.state,screens=screens,
        heartbeatAge=self.lastHeartbeat and hs.timer.secondsSinceEpoch()-self.lastHeartbeat})
      hs.settings.set('awayGuard.lastTrigger', self.trigger)
      persist()
      self.state = 'locking'
    end
    hs.caffeinate.lockScreen()
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
    self.state = 'restoring'
    audit.write('restore_started')
    stopMonitor()
    if self.screen and self.originalBrightness ~= nil then
      local screen = hs.screen.find(self.screen)
      if screen then screen:setBrightness(self.originalBrightness) end
    end
    release()
    local args = {helper, 'restore'}
    for _,identity in ipairs(self.external) do args[#args+1] = identity end
    if self.autoBrightness ~= nil then args[#args+1] = '--auto-brightness=' .. (self.autoBrightness and 'on' or 'off') end
    self.restorer = hs.task.new('/bin/sh', function(code, stdout, stderr)
      self.restorer = nil
      if self.stopped then return end
      if code == 0 then
        layout:restore(self.windowLayout, function(report)
          if self.stopped then return end
          audit.write('windows_restored', report)
          local ok, error = pcall(restoreRemoteWindows)
          if not ok then
            self.state = 'restoreFailed'
            audit.write('restore_failed', {reason=tostring(error),stage='rdp_fullscreen'})
            notify('RDP 全屏恢复失败，已保留恢复信息；再次锁屏并解锁可重试。')
            return
          end
          if #report.failed > 0 then
            self.state = 'restoreFailed'
            notify('部分窗口未能恢复，已记录原因并保留快照；再次锁屏并解锁可重试。')
            return
          end
          hs.settings.clear(marker)
          self.state = 'idle'
          audit.write('restore_complete', {reason=self.trigger and self.trigger.reason})
          notify('已恢复亮度、外屏和窗口。锁屏原因：' .. (self.trigger and self.trigger.reason or '系统锁屏'))
        end)
      else
        self.state = 'restoreFailed'
        audit.write('restore_failed', {stage='displays',code=code,stdout=stdout,stderr=stderr})
        notify('外屏恢复失败，已保留恢复信息；再次锁屏并解锁可重试。')
      end
    end, args)
    if not self.restorer or not self.restorer:start() then
      self.restorer = nil; self.state = 'restoreFailed'
      notify('无法启动外屏恢复，已保留恢复信息。')
    end
  end
  function self:check()
    if self.state == 'locking' then hs.caffeinate.lockScreen(); return end
    if self.state ~= 'armed' and self.state ~= 'preparing' then return end
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
    if hs.timer.secondsSinceEpoch() - self.lastHeartbeat > 1.5 then trip('display monitor unresponsive'); return end
    local screens = hs.screen.allScreens()
    if #screens ~= 1 or screens[1]:getUUID() ~= self.screen then trip('display changed'); return end
    local brightness = screens[1]:getBrightness()
    if brightness == nil or brightness > 0 then trip('brightness increased or unreadable: ' .. tostring(brightness)) end
  end
  function self:beginDisplays()
    self.deadline = hs.timer.secondsSinceEpoch() + 25
    local buffer = ''
    local monitor
    monitor = hs.task.new('/bin/sh', function(code, stdout, stderr)
      if self.monitor ~= monitor or self.stopped then return end
      if self.state == 'armed' or self.state == 'preparing' then
        hs.printf('[away-guard] Monitor exited (%s): %s', code, stderr or '')
        trip('display monitor exited')
      end
    end, function(task, stdout, stderr)
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
        elseif event.event == 'ready' and self.state == 'preparing' then
          local internal = hs.screen.find(self.screen)
          if not internal then trip('internal screen disappeared'); return false end
          internal:setBrightness(0)
          if internal:getBrightness() ~= 0 then trip('cannot darken internal screen'); return false end
          self.lastHeartbeat = hs.timer.secondsSinceEpoch()
          self.displayBaseline = displaySignature()
          self.state = 'armed'
          audit.write('armed', {screen=self.screen,external=self.external})
          self:check()
          if self.state == 'armed' then notify('离开守护已开启：外屏已禁用，内屏亮度为 0。') end
        elseif event.event == 'auto_brightness_disabled' then
          audit.write('auto_brightness_disabled', {previous=event.previous})
        elseif event.event == 'progress' then
          hs.printf('[away-guard] Display setup: online=%s %s', hs.json.encode(event.online or {}), event.reason or '')
        elseif event.event == 'heartbeat' then
          self.lastHeartbeat = hs.timer.secondsSinceEpoch()
        elseif event.event == 'changed' or event.event == 'error' then
          if not self.nativeIncident then audit.write('native_display_event', {details=event});self.nativeIncident=true end
          trip(event.reason or 'display changed')
        end
      end
      return true
    end, {helper, 'watch'})
    self.monitor = monitor
    if not self.monitor or not self.monitor:start() then
      self.monitor = nil; restore(); notify('无法启动外屏控制，未开启守护。'); return false
    end
    return true
  end
  function self:arm()
    if self.state ~= 'idle' then notify('离开守护已开启；调亮屏幕并认证解锁后退出。'); return false end
    local screen
    for _,candidate in ipairs(hs.screen.allScreens()) do
      if candidate:name():find('Built%-in') then screen = candidate; break end
    end
    if not screen then notify('请打开 MacBook 内屏后再开启守护。'); return false end
    local brightness = screen:getBrightness()
    if brightness == nil then notify('无法读取内屏亮度，未开启守护。'); return false end
    local ok, snapshot = pcall(function() return layout:capture() end)
    if not ok then audit.write('capture_failed', {reason=tostring(snapshot)});notify('无法保存窗口布局，未开启守护。');return false end
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
    if not self.keepAwake or not self.keepAwake:start() then release(); notify('无法阻止休眠，未开启守护。'); return false end
    self.state = 'preparing'
    audit.write('preparing', {windows=#self.windowLayout.windows,rdpWindows=#self.remoteWindows})
    self.deadline = hs.timer.secondsSinceEpoch() + 20
    persist()
    if self.remotePreparing then
      hs.printf('[away-guard] Leaving %d RDP fullscreen window(s) before display changes', #self.remoteWindows)
      notify('正在准备离开守护：先退出 RDP 全屏，再禁用外屏。')
      for _,savedWindow in ipairs(self.remoteWindows) do
        local window = remoteWindow(savedWindow)
        if window then window:setFullScreen(false) end
      end
    else
      return self:beginDisplays()
    end
    return true -- Setup completes asynchronously; the ready message confirms arming.
  end
  self.poll = hs.timer.doEvery(0.3, function() self:check() end)
  self.displays = hs.screen.watcher.new(function()
    -- Our own initial disable emits configuration changes; helper verifies physical topology during setup.
    if self.state == 'armed' then
      local signature = displaySignature()
      if signature ~= self.displayBaseline then
        audit.write('display_configuration_changed', {before=self.displayBaseline,after=signature})
        trip('display configuration changed')
      elseif not self.unchangedDisplayLogged then
        self.unchangedDisplayLogged = true
        audit.write('display_notification_unchanged', {signature=signature})
      end
    end
  end):start()
  local events = hs.caffeinate.watcher
  self.power = events.new(function(event)
    if event == events.screensDidLock and self.state ~= 'idle' and self.state ~= 'restoring' and self.state ~= 'locked' then
      local observed = audit.write('lock_observed', {reason=self.state == 'locking' and 'guard_requested' or 'system_or_external_lock',state=self.state})
      if self.state ~= 'locking' then
        self.trigger = observed
        hs.settings.set('awayGuard.lastTrigger', self.trigger)
        persist()
      end
      self.state = 'locked'
    elseif event == events.screensDidUnlock and self.state ~= 'idle' then
      restore()
    elseif event == events.systemWillSleep then trip('system sleep')
    elseif event == events.systemDidWake then trip('system wake') end
  end):start()
  function self:lastTrigger() return hs.settings.get('awayGuard.lastTrigger') end
  function self:returnAndLock()
    if self.state == 'idle' then notify('离开守护尚未开启。'); return end
    trip('manual return')
  end
  function self:stop()
    self.stopped = true
    if self.state ~= 'idle' then hs.caffeinate.lockScreen() end
    audit.write('stopped', {state=self.state})
    layout:stop()
    self.poll:stop(); self.displays:stop(); self.power:stop()
    stopMonitor(); release()
    if self.restorer then self.restorer:terminate(); self.restorer = nil end
  end
  if saved then
    self.screen, self.originalBrightness, self.external = saved.screen, saved.brightness, saved.external or {}
    self.remoteWindows = saved.remoteWindows or {}
    self.windowLayout, self.trigger, self.autoBrightness = saved.windowLayout, saved.trigger, saved.autoBrightness
    audit.write('recovery_lock', {reason=self.trigger and self.trigger.reason})
    self.state = 'locking'
    hs.caffeinate.lockScreen()
  end
  return self
end
return M
