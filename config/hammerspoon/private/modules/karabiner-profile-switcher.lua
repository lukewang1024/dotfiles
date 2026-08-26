local hotkey = require 'hs.hotkey'
local eventtap = require 'hs.eventtap'
local task = require 'hs.task'
local timer = require 'hs.timer'
local window = require 'hs.window'
local window_filter = require 'hs.window.filter'
local module = {}

local nomachine_f18_workaround = hs.settings.get('nomachine_f18_workaround') or false
local remote_desktop_window_focused = nil
local nomachine_player_pids = {}

local function set_karabiner_variables(variables)
  local json = hs.json.encode(variables)
  local _, status = hs.execute('/opt/homebrew/bin/karabiner_cli --set-variables ' .. string.format('%q', json), false)
  return status
end

local function is_nomachine_player(application)
  if not application or application:bundleID() ~= 'com.nomachine.nxdock' then
    return false
  end

  local pid = application:pid()
  if nomachine_player_pids[pid] ~= nil then
    return nomachine_player_pids[pid]
  end

  local command = string.format('/bin/ps -p %d -o comm=', pid)
  local executable = hs.execute(command, false) or ''
  nomachine_player_pids[pid] = executable:match('/nxplayer%s*$') ~= nil
  return nomachine_player_pids[pid]
end

local function frontmost_cg_window_title(application)
  -- Windows App's remote desktop surface is a CoreGraphics window but is not
  -- exposed through Accessibility, so hs.window.focusedWindow() sees only the
  -- main library window. hs.window.list() preserves front-to-back CG ordering.
  for _, cg_window in ipairs(window.list()) do
    if cg_window.kCGWindowOwnerPID == application:pid()
        and cg_window.kCGWindowLayer == 0
        and cg_window.kCGWindowName
        and cg_window.kCGWindowName ~= '' then
      return cg_window.kCGWindowName
    end
  end

  return ''
end

local function is_remote_desktop_window_focused()
  local application = hs.application.frontmostApplication()
  if not application then
    return false
  end

  if is_nomachine_player(application) then
    return true
  end

  if application:bundleID() == 'com.microsoft.rdc.macos' then
    return frontmost_cg_window_title(application):match('^%[RDP%]') ~= nil
  end

  return false
end


local update_remote_desktop_state
module.update_remote_desktop_timer = timer.delayed.new(0.1, function()
  local focused = is_remote_desktop_window_focused()
  if focused == remote_desktop_window_focused then
    return
  end

  remote_desktop_window_focused = focused
  if not set_karabiner_variables({remote_desktop_window_focused = focused and 1 or 0}) then
    hs.alert.show('Failed to update remote desktop keyboard mapping')
  end
end)

update_remote_desktop_state = function()
  module.update_remote_desktop_timer:start()
end

module.remote_desktop_window_filter = window_filter.new(false)
module.remote_desktop_window_filter:setAppFilter('Windows App', {})
module.remote_desktop_window_filter:setAppFilter('NoMachine', {})
module.remote_desktop_window_filter:subscribe({
  window_filter.windowCreated,
  window_filter.windowDestroyed,
  window_filter.windowFocused,
  window_filter.windowTitleChanged,
  window_filter.windowUnfocused,
}, update_remote_desktop_state)

module.remote_desktop_application_watcher = hs.application.watcher.new(function(_, event)
  if event == hs.application.watcher.activated or event == hs.application.watcher.deactivated then
    update_remote_desktop_state()
  end
end)
module.remote_desktop_application_watcher:start()

module.remote_desktop_space_watcher = hs.spaces.watcher.new(update_remote_desktop_state)
module.remote_desktop_space_watcher:start()

-- Windows App's remote surface emits no Accessibility focus event. A click is
-- the remaining same-app activation path; defer until macOS has raised it.
module.remote_desktop_mouse_watcher = eventtap.new({
  eventtap.event.types.leftMouseDown,
  eventtap.event.types.rightMouseDown,
  eventtap.event.types.otherMouseDown,
}, function()
  update_remote_desktop_state()
  return false
end)
module.remote_desktop_mouse_watcher:start()

update_remote_desktop_state()

local function toggle_nomachine_f18_workaround()
  nomachine_f18_workaround = not nomachine_f18_workaround
  hs.settings.set('nomachine_f18_workaround', nomachine_f18_workaround)
  local value = nomachine_f18_workaround and 1 or 0
  local variables = string.format('{"nomachine_f18_workaround":%d}', value)

  task.new('/opt/homebrew/bin/karabiner_cli', function(exit_code)
    if exit_code == 0 then
      hs.alert.show('NoMachine F18 workaround: ' .. (nomachine_f18_workaround and 'ON' or 'OFF'))
    else
      hs.alert.show('Failed to update NoMachine F18 workaround')
    end
  end, {'--set-variables', variables}):start()
end

hotkey.bind(hyper, 'f12', toggle_nomachine_f18_workaround)

return module
