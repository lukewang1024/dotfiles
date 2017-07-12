local KEYBOARD = {
  "USB Keyboard",
  "Mechanical Keyboard"
}

function isExternalKeyboard(data)
  local name = data.productName
  local isExternal = false
  for i, keyboard in ipairs(KEYBOARD) do
    isExternal = isExternal or data.productName == keyboard
  end
  return isExternal
end

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

function usbDeviceCallback(data)
  if (isExternalKeyboard(data)) then
    if (data.eventType == "added") then
      hs.alert.show("External keyboard added")
      selectKarabinerProfile(1)
    elseif (data.eventType == "removed") then
      hs.alert.show("External keyboard removed")
      selectKarabinerProfile(0)
    end
  end
end

local usbTable = hs.usb.attachedDevices()
local hasExternal = false
for i, usbDevice in pairs(usbTable) do
  if (isExternalKeyboard(usbDevice)) then
    hasExternal = true
  end
end
hs.alert.show("External keyboard "..(hasExternal and "connected" or "not exists"))
selectKarabinerProfile(hasExternal and 1 or 0)

local usbWatcher = hs.usb.watcher.new(usbDeviceCallback)
usbWatcher:start()
