-- Unified launcher; intentionally does not load the legacy modal supervisor.
hyper = {'ctrl', 'alt', 'cmd'}
hyperAlt = {'ctrl', 'alt', 'cmd', 'shift'}
local remote = require 'private/modules/karabiner-profile-switcher'

local toolbox = require 'private/modules/toolbox'
local clipboard
if toolbox.features().workbench then
  workbenchClipboardOptions = {menu = false}
  clipboard = require 'private/modules/workbench-clipboard'
end
workbenchToolbox = toolbox.new({clipboard = clipboard})
local awayGuard = require('private/modules/away-guard')
workbenchAwayGuard = awayGuard.new({
  remoteWindows=function()return remote.remote_desktop_window_filter:getWindows()end,
})
workbenchRemoteStack = require('private/modules/remote-window-stack').new({
  suspended=function()return awayGuard.suspendsWindowLayout(workbenchAwayGuard.state) end,
})
workbenchToolbox.options.remoteStack=workbenchRemoteStack
workbenchHyper = require('private/modules/hyper').new({toolbox=workbenchToolbox, clipboard=clipboard, remote=remote, remoteStack=workbenchRemoteStack, awayGuard=workbenchAwayGuard})
hs.shutdownCallback = function()
  workbenchRemoteStack:stop()
  workbenchAwayGuard:stop()
  workbenchHyper:stop()
  workbenchToolbox:stop()
  if clipboard then clipboard.stop() end
end
