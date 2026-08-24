local hotkey = require 'hs.hotkey'
local task = require 'hs.task'

local nomachine_f18_workaround = hs.settings.get('nomachine_f18_workaround') or false

local function toggle_nomachine_f18_workaround()
  nomachine_f18_workaround = not nomachine_f18_workaround
  hs.settings.set('nomachine_f18_workaround', nomachine_f18_workaround)
  local value = nomachine_f18_workaround and 1 or 0
  local variables = string.format('{"nomachine_f18_workaround":%d}', value)

  task.new('/opt/homebrew/bin/karabiner_cli', function(exit_code)
    if exit_code == 0 then
      hs.alert.show('NoMachine F18 workaround: ' .. (nomachine_f18_workaround and 'ON' or 'OFF'))
    else
      hs.alert.show('Failed to update NoMachine F18 workaround')
    end
  end, {'--set-variables', variables}):start()
end

hotkey.bind(hyper, 'f12', toggle_nomachine_f18_workaround)
