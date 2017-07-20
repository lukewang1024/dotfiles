hyper = {'ctrl', 'alt', 'cmd'}
hyperShift = {'ctrl', 'alt', 'cmd', 'shift'}

local hotkey = require 'hs.hotkey'
local application = require 'hs.application'

-- {{{ switch to application
-- hs.keycodes.map(http://www.hammerspoon.org/docs/hs.keycodes.html#map)
local key2app = {
    a = 'AppCleaner',
    b = 'Notes',
    c = 'Calendar',
    -- d, (system hotkey) Ctrl + Cmd + d => define word
    e = 'Evernote',
    f = 'Finder',
    -- g = '',
    -- h = '',
    i = 'iTunes',
    j = 'Google Chrome',
    k = 'Preview',
    l = 'Dictionary',
    m = 'MacDown',
    n = 'NeteaseMusic',
    -- o = '',
    -- p = '',
    q = 'App Store',
    -- r = '',
    s = 'Sublime Text',
    -- t = '',
    -- u = '',
    -- v = '',
    -- w = '',
    -- x = '',
    y = 'Messages',
    --z = '',
}

for key, app in pairs(key2app) do
    hotkey.bind(hyper, key, function()
        toggle_application(app)
    end)
end
-- {{{ hyperShift hotkey
local key2app = {
    a = 'Activity Monitor',
    --b = '',
    c = 'Google Chrome',
    d = 'Day One',
    --e = '',
    f = 'Finder',
    --g = '',
    --h = '',
    --i = '',
    j = 'Safari',
    k = 'Skim',
    --l = '',
    m = 'Spotify',
    n = 'Microsoft OneNote',
    p = 'Pocket',
    q = 'PDF Expert',
    --r = '',
    s = 'Skype',
    t = 'iTerm',
    --u = '',
    v = 'Visual Studio Code',
    w = 'WeChat',
    --x = '',
    --y = '',
    --z = '',
}

for key, app in pairs(key2app) do
    hotkey.bind(hyperShift, key, function()
        toggle_application(app)
    end)
end

-- }}}

-- iTerm2 console
hotkey.bind(hyper, ';', function()
    toggle_application("iTerm")
end)

hotkey.bind(hyper, ',', function()
    toggle_application("System Preferences")
end)

hotkey.bind(hyper, '3', function()
    toggle_application("licecap")
end)

-- reload
hotkey.bind(hyper, 'escape', function() hs.reload() end)

-- {{{ toggle_application
-- Toggle an application between being the frontmost app, and being hidden
function toggle_application(_app)
    -- Finds running applications
    local app = application.find(_app)

    if not app then
        --application.launchOrFocus(_app)
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
-- }}}
