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

local function setAppToggles(mod, mapping)
  for key, app in pairs(mapping) do
    hotkey.bind(mod, key, function() toggle_application(app) end)
  end
end

setAppToggles(hyper, {
  a = 'Activity Monitor',
  b = 'Safari',
  c = 'Google Chrome',
  d = 'Dictionary',
  e = 'Pocket',
  f = 'Firefox',
  g = 'Lepton',
  -- h: for arrows
  i = 'iTunes',
  -- j: for arrows
  -- k: for arrows
  -- l: for arrows
  m = 'MWeb',
  n = 'nvALT',
  o = 'Microsoft OneNote',
  p = 'PDF Expert',
  q = 'qutebrowser',
  r = 'Reeder',
  s = 'Sublime Text',
  t = 'Telegram',
  u = 'QQ音乐',
  v = 'Code',
  w = 'WeChat',
  x = 'Spark',
  y = 'Skype',
  z = 'ForkLift',
  [','] = 'System Preferences',
  [';'] = 'iTerm',
  ['.'] = 'SourceTree',
  ['['] = 'Caprine',
  [']'] = 'LINE',
  ['/'] = 'Finder',
  ['\''] = 'Sublime Text',
  ['\\'] = 'MacPass',
  ['`'] = 'iTerm',
  ['0'] = 'Charles',
  ['1'] = 'Fantastical',
  ['2'] = 'Trello',
  -- ['3'] = '',
  ['4'] = 'licecap',
  ['5'] = 'Sequel Pro',
  ['6'] = 'Robo 3T',
  ['7'] = 'Medis',
  -- ['8'] = '',
  ['9'] = 'Proxifier',
  ['space'] = 'Feishu',
})

-- hyperAlt application shortcuts
setAppToggles(hyperAlt, {
  a = 'Atom',
  b = 'Bilibili',
  c = 'Chromium',
  -- d = '',
  e = 'Evernote',
  f = '富途牛牛',
  -- g = '',
  -- h = '',
  i = 'IINA',
  -- j = '',
  k = 'Kitematic (Beta)',
  -- l = '',
  -- m = '',
  n = 'Knotes',
  -- o = '',
  p = 'Postman',
  q = 'Commander One',
  -- r = '',
  s = 'Spotify',
  -- t = '',
  u = 'QQMusic',
  v = 'Visual Studio Code',
  w = 'WhatsApp',
  x = 'Todoist',
  y = 'Slack',
  z = 'Zeplin',
  -- [','] = '',
  [';'] = 'Terminal',
  -- ['.'] = '',
  ['['] = 'Flume',
  [']'] = 'Tweeten',
  -- ['/'] = '',
  ['\''] = 'VNC Viewer',
  ['\\'] = 'Maipo',
  -- ['`'] = '',
  ['0'] = 'WireShark',
  ['1'] = 'Fantastical 2',
  -- ['2'] = '',
  -- ['3'] = '',
  -- ['4'] = '',
  ['5'] = 'SQLPro for Postgres',
  ['6'] = 'MongoDB Compass',
  -- ['7'] = '',
  -- ['8'] = '',
  ['9'] = 'ShadowsocksX-NG',
  ['space'] = 'Lark',
})

-- reload
hotkey.bind(hyper, 'escape', function() hs.reload() end)

-- vim-like j,k,h,l-navigations
hotkey.bind(hyper, 'j', pressFn('down'))
hotkey.bind(hyper, 'k', pressFn('up'))
hotkey.bind(hyper, 'h', pressFn('left'))
hotkey.bind(hyper, 'l', pressFn('right'))

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
