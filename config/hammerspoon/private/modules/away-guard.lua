-- Opt-in guard for unattended GUI automation. Never consumes mouse/key events.
local M = {}
function M.new()
  local self = {state = 'idle', external = {}}
  local marker = 'awayGuard.session'
  local saved = hs.settings.get(marker)
  local helper = hs.configdir .. '/private/helpers/away-guard-display'
  local function notify(message) hs.alert.show(message, 4) end
  local function persist()
    hs.settings.set(marker, {screen = self.screen, brightness = self.originalBrightness, external = self.external})
  end
  local function release()
    local task = self.keepAwake; self.keepAwake = nil
    if task then task:terminate() end
  end
  local function stopMonitor()
    local task = self.monitor; self.monitor = nil
    if task then task:terminate() end
  end
  local function trip(reason)
    if self.state == 'idle' or self.state == 'locked' or self.state == 'restoring' then return end
    if self.state ~= 'locking' then
      self.state = 'locking'
      hs.printf('[away-guard] Lock requested: %s', reason)
    end
    hs.caffeinate.lockScreen()
  end
  local function restore()
    if self.state == 'restoring' then return end
    self.state = 'restoring'
    stopMonitor()
    if self.screen and self.originalBrightness ~= nil then
      local screen = hs.screen.find(self.screen)
      if screen then screen:setBrightness(self.originalBrightness) end
    end
    release()
    local args = {helper, 'restore'}
    for _,identity in ipairs(self.external) do args[#args+1] = identity end
    self.restorer = hs.task.new('/bin/sh', function(code, stdout, stderr)
      self.restorer = nil
      if self.stopped then return end
      if code == 0 then
        hs.settings.clear(marker)
        self.state = 'idle'
        notify('已退出离开守护，恢复内屏亮度和原外接屏。')
      else
        self.state = 'restoreFailed'
        hs.printf('[away-guard] Restore failed: %s %s', stdout or '', stderr or '')
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
    if not self.monitor or not self.monitor:isRunning() then trip('display monitor stopped'); return end
    if self.state == 'preparing' then
      if hs.timer.secondsSinceEpoch() > self.deadline then trip('display setup timed out') end
      return
    end
    if hs.timer.secondsSinceEpoch() - self.lastHeartbeat > 1.5 then trip('display monitor unresponsive'); return end
    local screens = hs.screen.allScreens()
    if #screens ~= 1 or screens[1]:getUUID() ~= self.screen then trip('display changed'); return end
    local brightness = screens[1]:getBrightness()
    if brightness == nil or brightness > 0 then trip('brightness increased or unreadable') end
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
    self.screen, self.originalBrightness, self.external = screen:getUUID(), brightness, {}
    local keepAwake
    keepAwake = hs.task.new('/usr/bin/caffeinate', function()
      if self.keepAwake ~= keepAwake or self.stopped then return end
      if self.state == 'armed' or self.state == 'preparing' then trip('keep-awake process exited') end
    end, {'-d', '-i'})
    self.keepAwake = keepAwake
    if not self.keepAwake or not self.keepAwake:start() then release(); notify('无法阻止休眠，未开启守护。'); return false end
    self.state = 'preparing'
    self.deadline = hs.timer.secondsSinceEpoch() + 20
    persist()
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
          self.external = event.external
          persist() -- Persist before the helper can turn off any external display.
          task:setInput('disable\n')
        elseif event.event == 'ready' and self.state == 'preparing' then
          local internal = hs.screen.find(self.screen)
          if not internal then trip('internal screen disappeared'); return false end
          internal:setBrightness(0)
          if internal:getBrightness() ~= 0 then trip('cannot darken internal screen'); return false end
          self.lastHeartbeat = hs.timer.secondsSinceEpoch()
          self.state = 'armed'
          self:check()
          if self.state == 'armed' then notify('离开守护已开启：外屏已禁用，内屏亮度为 0。') end
        elseif event.event == 'heartbeat' then
          self.lastHeartbeat = hs.timer.secondsSinceEpoch()
        elseif event.event == 'changed' or event.event == 'error' then
          trip(event.reason or 'display changed')
        end
      end
      return true
    end, {helper, 'watch'})
    self.monitor = monitor
    if not self.monitor or not self.monitor:start() then
      self.monitor = nil; restore(); notify('无法启动外屏控制，未开启守护。'); return false
    end
    return true -- Setup completes asynchronously; the ready message confirms arming.
  end
  self.poll = hs.timer.doEvery(0.3, function() self:check() end)
  self.displays = hs.screen.watcher.new(function()
    -- Our own initial disable emits configuration changes; helper verifies physical topology during setup.
    if self.state ~= 'preparing' then trip('display configuration changed') end
  end):start()
  local events = hs.caffeinate.watcher
  self.power = events.new(function(event)
    if event == events.screensDidLock and self.state ~= 'idle' and self.state ~= 'restoring' then
      self.state = 'locked'
    elseif event == events.screensDidUnlock and self.state ~= 'idle' then
      restore()
    elseif event == events.systemWillSleep then trip('system sleep')
    elseif event == events.systemDidWake then trip('system wake') end
  end):start()
  function self:returnAndLock()
    if self.state == 'idle' then notify('离开守护尚未开启。'); return end
    trip('manual return')
  end
  function self:stop()
    self.stopped = true
    if self.state ~= 'idle' then hs.caffeinate.lockScreen() end
    self.poll:stop(); self.displays:stop(); self.power:stop()
    stopMonitor(); release()
    if self.restorer then self.restorer:terminate(); self.restorer = nil end
  end
  if saved then
    self.screen, self.originalBrightness, self.external = saved.screen, saved.brightness, saved.external or {}
    self.state = 'locking'
    hs.caffeinate.lockScreen()
  end
  return self
end
return M
