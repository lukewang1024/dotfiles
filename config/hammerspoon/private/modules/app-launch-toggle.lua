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
  c = 'Google Chrome',
  d = 'Dictionary',
  e = 'PDF Expert',
  f = 'Firefox',
  i = 'IINA',
  o = 'Microsoft OneNote',
  p = 'Pocket',
  r = 'Reeder',
  s = 'Safari',
  w = 'WeChat',
  x = 'Finder',
  [';'] = 'iTerm',
  [','] = 'System Preferences',
  ['/'] = 'Finder',
  ['\''] = 'Sublime Text',
  ['['] = 'Skype',
  [']'] = 'Telegram',
  ['\\'] = 'Slack',
  ['1'] = 'Todoist',
  ['2'] = 'Spark',
  ['3'] = 'Calendar',
  ['4'] = 'licecap',
})

-- hyperCmd application shortcuts
setAppToggles(hyperCmd, {
  b = 'Notes',
  e = 'Evernote',
  i = 'iTunes',
  l = 'Musixmatch',
  m = 'Medis',
  n = 'NeteaseMusic',
  r = 'Robo 3T',
  p = 'Postman',
  s = 'Spotify',
  t = 'SourceTree',
  w = 'WhatsApp',
  y = 'Messages',
  z = 'Zeplin',
  [';'] = 'Terminal',
  [','] = 'App Store',
  ['\''] = 'MacVim',
  ['['] = 'Atom',
  [']'] = 'Visual Studio Code',
  ['2'] = 'Thunderbird',
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
