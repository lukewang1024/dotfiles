-- Dotfiles-owned entry point. The legacy awesome-hammerspoon init is not loaded.
local configHome = os.getenv('XDG_CONFIG_HOME') or (os.getenv('HOME') .. '/.config')
local root = configHome .. '/hammerspoon'
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
hs.hotkey.alertDuration = 0
hs.window.animationDuration = 0
require 'hs.ipc'
require 'private/workbench'
