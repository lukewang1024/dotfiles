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
workbenchAwayGuard = require('private/modules/away-guard').new()
workbenchHyper = require('private/modules/hyper').new({toolbox=workbenchToolbox, clipboard=clipboard, remote=remote, awayGuard=workbenchAwayGuard})
hs.shutdownCallback = function()
  workbenchAwayGuard:stop()
  workbenchHyper:stop()
  workbenchToolbox:stop()
  if clipboard then clipboard.stop() end
end
