module_list = {
  'modes/basicmode',
  'modes/cheatsheet',
  'modes/clipshow',
  'modes/hsearch',
  'modes/indicator',
  'widgets/aria2',
  'misc/bingdaily'
}

applist = {
  {shortcut = 'a', appname = 'Atom'},
  {shortcut = 'c', appname = 'Google Chrome'},
  {shortcut = 'e', appname = 'Visual Studio Code'},
  {shortcut = 'f', appname = 'Finder'},
  {shortcut = 'i', appname = 'WeChat'},
  {shortcut = 'k', appname = 'Skype'},
  {shortcut = 'n', appname = 'Microsoft OneNote'},
  {shortcut = 'o', appname = 'Spotify'},
  {shortcut = 'p', appname = 'Pocket'},
  {shortcut = 'q', appname = 'PDF Expert'},
  {shortcut = 's', appname = 'Safari'},
  {shortcut = 't', appname = 'iTerm'},
  {shortcut = 'v', appname = 'Activity Monitor'},
  {shortcut = 'y', appname = 'System Preferences'},
}

resizeextra_lefthalf_keys = {{}, ''}
resizeextra_righthalf_keys = {{}, ''}
resizeextra_fullscreen_keys = {{}, ''}
resizeextra_fcenter_keys = {{}, ''}
resizeextra_center_keys = {{}, ''}

hyper = {'ctrl', 'alt', 'shift'}
hyperCmd = {'ctrl', 'alt', 'cmd', 'shift'}

require 'private/modules/app-launch-toggle'
require 'private/modules/karabiner-profile-switcher'
require 'private/modules/quick-screen-recording'
