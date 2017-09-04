function selectKarabinerProfile(idx)
  hs.osascript.applescript([[
    tell application "System Events" to tell process "Karabiner-Menu"
      ignoring application responses
        click menu bar item 1 of menu bar 1
      end ignoring
    end tell
    do shell script "killall System\\ Events"
    delay 0.1
    tell application "System Events" to tell process "Karabiner-Menu"
      click menu item ]] .. (idx + 1) .. [[ of menu 1 of menu bar item 1 of menu bar 1
    end tell
  ]])
end

local hotkey = require 'hs.hotkey'

hotkey.bind(hyper, '-', function() selectKarabinerProfile(0) end)
hotkey.bind(hyper, '=', function() selectKarabinerProfile(1) end)
hotkey.bind(hyper, 'delete', function() selectKarabinerProfile(2) end)
