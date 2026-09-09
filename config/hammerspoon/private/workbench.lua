-- Unified launcher; intentionally does not load the legacy modal supervisor.
hyper = {'ctrl', 'alt', 'cmd'}
hyperAlt = {'ctrl', 'alt', 'cmd', 'shift'}
require 'private/modules/app-launch-toggle'
require 'private/modules/karabiner-profile-switcher'
require 'private/modules/quick-screen-recording'

local toolbox = require 'private/modules/toolbox'
local clipboard
if toolbox.features().workbench then
  workbenchClipboardOptions = {menu = false}
  clipboard = require 'private/modules/workbench-clipboard'
end
workbenchToolbox = toolbox.new({clipboard = clipboard})
if toolbox.features().windows then
  workbenchWindowShortcuts = require('private/modules/window-shortcuts').new(workbenchToolbox)
end
hs.shutdownCallback = function()
  if workbenchWindowShortcuts then workbenchWindowShortcuts:stop() end
  workbenchToolbox:stop()
  if clipboard then clipboard.stop() end
end
