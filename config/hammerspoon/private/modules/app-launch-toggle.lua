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
  b = 'Sublime Text',
  c = 'Google Chrome',
  d = 'Dictionary',
  e = 'PDF Expert',
  f = 'Firefox',
  i = 'IINA',
  m = 'MWeb',
  n = 'Knotes',
  o = 'Microsoft OneNote',
  p = 'Pocket',
  r = 'Reeder',
  s = 'Safari',
  t = 'Telegram',
  v = 'Visual Studio Code',
  w = 'WeChat',
  y = 'Skype',
  z = 'Finder',
  [';'] = 'iTerm',
  [','] = 'System Preferences',
  ['/'] = 'Finder',
  ['`'] = 'iTerm',
  ['1'] = 'Spark',
  ['2'] = 'Todoist',
  ['3'] = 'Fantastical',
  ['4'] = 'licecap',
})

-- hyperCmd application shortcuts
setAppToggles(hyperCmd, {
  a = 'Atom',
  b = 'Notes',
  e = 'Evernote',
  g = 'SQLPro for Postgres',
  i = 'iTunes',
  l = 'Musixmatch',
  m = 'Medis',
  n = 'NeteaseMusic',
  r = 'Robo 3T',
  p = 'Postman',
  s = 'Spotify',
  t = 'SourceTree',
  v = 'MacVim',
  w = 'WhatsApp',
  y = 'Slack',
  z = 'Zeplin',
  [';'] = 'Terminal',
  [','] = 'App Store',
  ['2'] = 'Trello',
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
