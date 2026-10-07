-- Opt-in guard for unattended GUI automation. Never consumes mouse/key events.
local M = {}
function M.new()
  local self = {state = 'idle'}
  local marker = 'awayGuard.session'
  local saved = hs.settings.get(marker)
  local function notify(message) hs.alert.show(message, 4) end
  local function release()
    if self.keepAwake then self.keepAwake:terminate(); self.keepAwake = nil end
  end
  local function restore()
    if self.screen and self.originalBrightness then
      local screen = hs.screen.find(self.screen)
      if screen then screen:setBrightness(self.originalBrightness) end
    end
    release()
    hs.settings.clear(marker)
    self.state = 'idle'
  end
  local function trip(reason)
    if self.state == 'idle' or self.state == 'locked' then return end
    if self.state ~= 'locking' then
      self.state = 'locking'
      hs.printf('[away-guard] Lock requested: %s', reason)
    end
    hs.caffeinate.lockScreen()
  end
  function self:check()
    if self.state == 'locking' then hs.caffeinate.lockScreen(); return end
    if self.state ~= 'armed' then return end
    local screens = hs.screen.allScreens()
    if #screens ~= 1 or screens[1]:getUUID() ~= self.screen then
      trip('display changed'); return
    end
    local brightness = screens[1]:getBrightness()
    if brightness == nil or brightness > 0.001 then trip('brightness increased or unreadable') end
    if not self.keepAwake or not self.keepAwake:isRunning() then trip('keep-awake process stopped') end
  end
  function self:arm()
    if self.state ~= 'idle' then notify('离开守护已开启；调亮屏幕并认证解锁后退出。'); return false end
    local screens = hs.screen.allScreens()
    if #screens ~= 1 or not screens[1]:name():find('Built%-in') then
      notify('请拔掉所有外接显示器，并打开 MacBook 内屏后再开启守护。'); return false
    end
    local screen = screens[1]
    local brightness = screen:getBrightness()
    if brightness == nil then notify('无法读取内屏亮度，未开启守护。'); return false end
    self.screen, self.originalBrightness = screen:getUUID(), brightness
    self.keepAwake = hs.task.new('/usr/bin/caffeinate', function()
      if self.state == 'armed' then trip('keep-awake process exited') end
    end, {'-d', '-i'})
    if not self.keepAwake:start() then release(); notify('无法阻止休眠，未开启守护。'); return false end
    hs.settings.set(marker, {screen = self.screen, brightness = brightness})
    screen:setBrightness(0)
    local result = screen:getBrightness()
    if result == nil or result > 0.001 then
      restore(); notify('内屏未能降到最低亮度，未开启守护。'); return false
    end
    self.state = 'armed'
    self:check()
    return self.state == 'armed'
  end
  self.poll = hs.timer.doEvery(1, function() self:check() end)
  self.displays = hs.screen.watcher.new(function() trip('display configuration changed') end):start()
  local events = hs.caffeinate.watcher
  self.power = events.new(function(event)
    if event == events.screensDidLock and self.state ~= 'idle' then
      self.state = 'locked'
    elseif event == events.screensDidUnlock and self.state ~= 'idle' then
      restore(); notify('已退出离开守护，恢复原亮度。')
    elseif event == events.systemWillSleep then
      trip('system sleep')
    elseif event == events.systemDidWake then
      trip('system wake')
    end
  end):start()
  function self:returnAndLock()
    if self.state == 'idle' then notify('离开守护尚未开启。'); return end
    trip('manual return')
  end
  function self:stop()
    -- Reload/quit must not leave a previously guarded session exposed.
    if self.state ~= 'idle' then hs.caffeinate.lockScreen() end
    self.poll:stop(); self.displays:stop(); self.power:stop()
    release()
  end
  if saved then
    self.screen, self.originalBrightness = saved.screen, saved.brightness
    self.state = 'locking'
    hs.caffeinate.lockScreen()
  end
  return self
end
return M
