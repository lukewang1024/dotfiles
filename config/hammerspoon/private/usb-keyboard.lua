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

function usbDeviceCallback(data)
  if (isExternalKeyboard(data)) then
    if (data.eventType == "added") then
      hs.alert.show("External keyboard added")
    elseif (data.eventType == "removed") then
      hs.alert.show("External keyboard removed")
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
hs.alert.show("External keyboard "..(hasExternal and "available" or "unavailable"))

local usbWatcher = hs.usb.watcher.new(usbDeviceCallback)
usbWatcher:start()
