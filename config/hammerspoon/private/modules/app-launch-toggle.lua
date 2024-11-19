local hotkey = require 'hs.hotkey'
local application = require 'hs.application'

-- simulate a keystroke
local function pressFn(mods, key)
  if key == nil then
    key = mods
    mods = {}
  end

  return function() hs.eventtap.keyStroke(mods, key, 1000) end
end

local function mouseMove(distance, direction)
  return function()
    local point = hs.mouse.absolutePosition()
    local x = point.x
    local y = point.y
    if direction == 'x' then
      point.x = point.x + distance
    else
      point.y = point.y + distance
    end
    hs.mouse.absolutePosition(point)
  end
end

local function mouseClick(button)
  return function()
    local point = hs.mouse.absolutePosition()
    if button == 0 then
      hs.eventtap.leftClick(point)
    elseif button == 1 then
      hs.eventtap.middleClick(point)
    elseif button == 2 then
      hs.eventtap.rightClick(point)
    end
  end
end

local function setAppToggles(mod, mapping)
  for key, app in pairs(mapping) do
    hotkey.bind(mod, key, function() toggle_application(app) end)
  end
end

setAppToggles(hyper, {
  a = 'Arc',
  b = 'Safari',
  c = 'Google Chrome',
  d = 'Dictionary',
  e = 'Microsoft Edge',
  f = 'Firefox',
  -- g = '',
  -- h: for arrows
  i = 'Cursor',
  -- j: for arrows
  -- k: for arrows
  -- l: for arrows
  m = 'Music',
  n = 'nvALT',
  o = 'Microsoft OneNote',
  p = 'Preview',
  q = 'qutebrowser',
  r = 'Reeder',
  s = 'Sublime Text',
  t = 'Telegram',
  u = 'Screen Sharing',
  v = 'com.microsoft.VSCode',                     -- Visual Studio Code
  w = 'WeChat',
  x = 'com.volcengine.corplink',                  -- CorpLink
  y = 'scrcpy',
  z = 'Finder',
  [','] = 'com.apple.systempreferences',          -- CFBundleName changed in macOS 13 Ventura, use CFBundleIdentifier for compatibility
  [';'] = 'Alacritty',
  ['.'] = 'Sublime Merge',
  ['['] = 'Skype',
  [']'] = 'Slack',
  ['/'] = 'ForkLift',
  ['\''] = 'kitty',
  ['\\'] = 'MacPass',
  ['`'] = 'Meetings',
  ['1'] = 'Reminders',
  ['2'] = 'Calendar',
  ['3'] = 'Spark',
  -- ['4'] = '',
  ['5'] = 'Clock',
  ['6'] = 'Hoppscotch',
  -- ['7'] = '',
  ['8'] = 'Resilio Sync',
  ['9'] = 'Charles',
  ['0'] = 'Proxifier',
  ['space'] = 'Feishu',
})

-- hyperAlt application shortcuts
setAppToggles(hyperAlt, {
  a = 'Activity Monitor',
  -- b = '',
  c = 'Cloud IDE',
  d = 'DevDocs',
  -- e = '',
  f = 'Figma',
  g = 'Lepton',
  -- h: for mouse move
  i = 'IINA',
  -- j: for mouse move
  -- k: for mouse move
  -- l: for mouse move
  m = 'com.tencent.QQMusicMac',                   -- QQ Music
  n = 'Mark Text',
  o = 'Omnivore',
  p = 'Pocket',
  -- q = '',
  r = 'Microsoft Remote Desktop',
  s = 'Spotify',
  -- t = '',
  -- u = '',
  v = 'VNC Viewer',
  w = 'WeCom',
  -- x = '',
  -- y = '',
  z = 'Zeplin',
  -- [','] = '',
  [';'] = 'iTerm',
  -- ['.'] = '',
  ['['] = 'QQ',
  [']'] = 'WhatsApp',
  ['/'] = 'Commander One',
  ['\''] = 'Terminal',
  ['\\'] = '富途牛牛',
  -- ['`'] = '',
  ['1'] = 'workspace dev',
  ['2'] = 'docx dev',
  ['3'] = 'desktop dev',
  -- ['4'] = '',
  -- ['5'] = '',
  -- ['6'] = '',
  -- ['7'] = '',
  -- ['8'] = '',
  ['9'] = 'WireShark',
  ['0'] = 'V2rayU',
  ['space'] = 'Lark',
})

-- reload
hotkey.bind(hyper, 'escape', function() hs.reload() end)

-- vim-like j,k,h,l-navigations
hotkey.bind(hyper, 'j', pressFn('down'), nil, pressFn('down'))
hotkey.bind(hyper, 'k', pressFn('up'), nil, pressFn('up'))
hotkey.bind(hyper, 'h', pressFn('left'), nil, pressFn('left'))
hotkey.bind(hyper, 'l', pressFn('right'), nil, pressFn('right'))
hotkey.bind(hyperAlt, 'j', mouseMove(10, 'y'), nil, mouseMove(10, 'y'))
hotkey.bind(hyperAlt, 'k', mouseMove(-10, 'y'), nil, mouseMove(-10, 'y'))
hotkey.bind(hyperAlt, 'h', mouseMove(-10, 'x'), nil, mouseMove(-10, 'x'))
hotkey.bind(hyperAlt, 'l', mouseMove(10, 'x'), nil, mouseMove(10, 'x'))
hotkey.bind(hyperAlt, 'return', mouseClick(0), nil, mouseClick(0))
hotkey.bind(hyperAlt, 'forwarddelete', mouseClick(1), nil, mouseClick(1))
hotkey.bind(hyperAlt, 'delete', mouseClick(2), nil, mouseClick(2))

-- Toggle an application between being the frontmost app, and being hidden
function toggle_application(_app)
  -- Finds running applications
  local app = application.find(_app)

  if not app then
    application.open(_app)
    return
  end

  -- application is running, toggle hide/unhide
  local mainwin = app:mainWindow()
  if mainwin then
    if true == app:isFrontmost() then
      mainwin:application():hide()
    else
      mainwin:application():activate(true)
      mainwin:application():unhide()
      mainwin:focus()
    end
  else
    application.launchOrFocus(_app)
  end
end
