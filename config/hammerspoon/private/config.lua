-- Specify Spoons which will be loaded
hspoon_list = {
  "AClock",
  -- "BingDaily",
  -- "Calendar",
  -- "CircleClock",
  "ClipShow",
  "CountDown",
  "FnMate",
  -- "HCalendar",
  "HSaria2",
  "HSearch",
  "KSheet",
  -- "SpeedMenu",
  -- "TimeFlow",
  -- "UnsplashZ",
  "WinWin",
}

-- appM environment keybindings. Bundle `id` is prefered, but application `name` will be ok.
hsapp_list = {
    {key = 'a', name = 'Atom'},
    {key = 'c', id = 'com.google.Chrome'},
    {key = 'd', name = 'ShadowsocksX'},
    {key = 'e', name = 'Visual Studio Code'},
    {key = 'f', name = 'Finder'},
    {key = 'i', name = 'iTerm'},
    {key = 'k', name = 'KeyCastr'},
    {key = 'l', name = 'Sublime Text'},
    {key = 's', name = 'Safari'},
    {key = 't', name = 'Terminal'},
    {key = 'v', id = 'com.apple.ActivityMonitor'},
    {key = 'y', id = 'com.apple.systempreferences'},
}

-- Modal supervisor keybinding, which can be used to temporarily disable ALL modal environments.
hsupervisor_keys = {{"cmd", "shift", "ctrl"}, "Q"}

-- Reload Hammerspoon configuration
hsreload_keys = {{"cmd", "shift", "ctrl"}, "R"}

-- Toggle help panel of this configuration.
hshelp_keys = {{"ctrl", "alt"}, "/"}

-- aria2 RPC host address
hsaria2_host = "http://localhost:6800/jsonrpc"
-- aria2 RPC host secret
hsaria2_secret = "token"

--------------------------------------------------------------------------------
-- Those keybindings below could be disabled by setting to {"", ""} or {{}, ""}
--------------------------------------------------------------------------------

-- Window hints keybinding: Focuse to any window you want
hswhints_keys = {{"ctrl", "alt"}, "J"}

-- appM environment keybinding: Application Launcher
hsappM_keys = {{"ctrl", "alt"}, "A"}

-- clipshowM environment keybinding: System clipboard reader
hsclipsM_keys = {{"ctrl", "alt"}, "C"}

-- Toggle the display of aria2 frontend
hsaria2_keys = {{"ctrl", "alt"}, "D"}

-- Launch Hammerspoon Search
hsearch_keys = {{"ctrl", "alt"}, "G"}

-- Read Hammerspoon and Spoons API manual in default browser
hsman_keys = {{"ctrl", "alt"}, "H"}

-- countdownM environment keybinding: Visual countdown
hscountdM_keys = {{"ctrl", "alt"}, "I"}

-- Lock computer's screen
hslock_keys = {{"ctrl", "alt"}, "L"}

-- resizeM environment keybinding: Windows manipulation
hsresizeM_keys = {{"ctrl", "alt"}, "R"}

-- cheatsheetM environment keybinding: Cheatsheet copycat
hscheats_keys = {{"ctrl", "alt"}, "S"}

-- Show digital clock above all windows
hsaclock_keys = {{"ctrl", "alt"}, "T"}

-- Type the URL and title of the frontmost web page open in Google Chrome or Safari.
hstype_keys = {{"ctrl", "alt"}, "V"}

-- Toggle Hammerspoon console
hsconsole_keys = {{"ctrl", "alt"}, "Z"}

--------------------------
--- Hyper key bindings ---
--------------------------
hyper = {'ctrl', 'alt', 'cmd'}
hyperAlt = {'ctrl', 'alt', 'cmd', 'shift'}

require 'private/modules/app-launch-toggle'
require 'private/modules/karabiner-profile-switcher'
require 'private/modules/quick-screen-recording'
