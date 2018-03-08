function startScreenRecording()
  hs.osascript.applescript([[
    tell application "QuickTime Player" to activate
    tell application "System Events"
      activate -- set UI elements enabled to true
      tell process "QuickTime Player"
        click menu item "New Screen Recording" of menu "File" of menu bar 1
      end tell
    end tell

    tell application "QuickTime Player"
      activate
      tell application "System Events" to key code 49
    end tell
  ]])
end

local hotkey = require 'hs.hotkey'

hotkey.bind(hyperAlt, '4', function() startScreenRecording() end)
