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
  e = 'Microsoft Edge',
  f = 'Firefox',
  -- g = '',
  -- h: for arrows
  i = 'iTerm',
  -- j: for arrows
  -- k: for arrows
  -- l: for arrows
  m = 'Music',
  n = 'nvALT',
  -- o = '',
  p = 'PDF Expert',
  q = 'qutebrowser',
  r = 'Reeder',
  s = 'Sublime Text',
  t = 'Telegram',
  u = 'Pocket',
  v = 'Code',
  w = 'WeChat',
  x = 'Seal',
  -- y = '',
  z = 'Finder',
  [','] = 'System Preferences',
  [';'] = 'Alacritty',
  ['.'] = 'Sublime Merge',
  ['['] = 'Skype',
  [']'] = 'Slack',
  ['/'] = 'ForkLift',
  ['\''] = 'kitty',
  ['\\'] = 'MacPass',
  ['`'] = 'iTerm',
  ['0'] = 'Proxifier',
  -- ['1'] = '',
  ['2'] = 'Trello',
  ['3'] = 'Spark',
  ['4'] = 'licecap',
  ['5'] = 'Sequel Pro',
  ['6'] = 'Robo 3T',
  ['7'] = 'Medis',
  -- ['8'] = '',
  ['9'] = 'Charles',
  ['space'] = 'Feishu',
})

-- hyperAlt application shortcuts
setAppToggles(hyperAlt, {
  a = 'Atom',
  -- b = '',
  c = 'Google Chrome Canary',
  d = 'DevDocs',
  -- e = '',
  f = 'Figma',
  g = 'Lepton',
  h = 'Hoppscotch',
  i = 'IINA',
  j = 'Joplin',
  k = 'Personal Kanban',
  -- l = '',
  m = 'Spotify',
  n = 'Mark Text',
  o = 'Microsoft OneNote',
  -- p = '',
  -- q = '',
  r = 'Microsoft Remote Desktop',
  -- s = '',
  -- t = '',
  -- u = '',
  v = 'VNC Viewer',
  w = 'WeCom',
  -- x = '',
  -- y = '',
  z = 'Zeplin',
  -- [','] = '',
  [';'] = 'Terminal',
  -- ['.'] = '',
  -- ['['] = '',
  [']'] = 'WhatsApp',
  ['/'] = 'Commander One',
  -- ['\''] = '',
  ['\\'] = '富途牛牛',
  -- ['`'] = '',
  ['0'] = 'V2rayU',
  -- ['1'] = '',
  -- ['2'] = '',
  -- ['3'] = '',
  -- ['4'] = '',
  -- ['5'] = '',
  -- ['6'] = '',
  -- ['7'] = '',
  -- ['8'] = '',
  ['9'] = 'WireShark',
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
