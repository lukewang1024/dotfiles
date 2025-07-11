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
  a = 'Microsoft Edge',
  -- b = '',
  c = 'Google Chrome',
  d = 'Dictionary',
  e = 'Sublime Text',
  f = 'Firefox',
  -- g = '',
  -- h: for arrows
  i = 'Cursor',
  -- j: for arrows
  -- k: for arrows
  -- l: for arrows
  m = 'Music',
  n = 'MarkEdit',
  -- o = '',
  p = 'Preview',
  -- q = '',
  r = 'Reeder',
  s = 'Safari',
  t = 'com.trae.app',                             -- Trae
  -- u = '',
  v = 'com.microsoft.VSCode',                     -- Visual Studio Code
  w = 'WeChat',
  x = 'com.volcengine.corplink',                  -- CorpLink
  y = 'scrcpy',
  z = 'Finder',
  [','] = 'com.apple.systempreferences',          -- CFBundleName changed in macOS 13 Ventura, use CFBundleIdentifier for compatibility
  [';'] = 'Alacritty',
  ['.'] = 'Sublime Merge',
  ['['] = 'Telegram',
  [']'] = 'Slack',
  ['/'] = 'Marta',
  ['\''] = 'kitty',
  ['\\'] = 'MacPass',
  ['`'] = 'Screen Sharing',
  ['1'] = 'Reminders',
  ['2'] = 'Calendar',
  -- ['3'] = '',
  -- ['4'] = '',
  ['5'] = 'Clock',
  -- ['6'] = '',
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
  -- c = '',
  d = 'DevDocs',
  -- e = '',
  f = 'Figma',
  -- g = '',
  -- h: for mouse move
  i = 'Cloud IDE',
  -- j: for mouse move
  -- k: for mouse move
  -- l: for mouse move
  m = 'com.tencent.QQMusicMac',                   -- QQ Music
  n = 'MarkText',
  -- o = '',
  p = 'Pocket',
  -- q = '',
  -- r = '',
  -- s = '',
  t = 'cn.trae.app',                              -- Trae CN
  -- u = '',
  v = 'VNC Viewer',
  -- w = '',
  -- x = '',
  -- y = '',
  -- z = '',
  -- [','] = '',
  [';'] = 'iTerm',
  -- ['.'] = '',
  -- ['['] = '',
  -- [']'] = '',
  ['/'] = 'Commander One',
  ['\''] = 'Terminal',
  ['\\'] = 'cn.futu.Niuniu',                      -- Futubull
  ['`'] = 'Microsoft Remote Desktop',
  -- ['1'] = '',
  -- ['2'] = '',
  -- ['3'] = '',
  -- ['4'] = '',
  -- ['5'] = '',
  -- ['6'] = '',
  -- ['7'] = '',
  -- ['8'] = '',
  ['9'] = 'WireShark',
  ['0'] = 'V2rayU',
  ['space'] = 'Feishu Meetings',
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
