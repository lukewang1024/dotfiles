-- Explicit image transfer. Timers refresh node metadata, never clipboard contents.
local t = require('private/modules/hyper-i18n').t
local M = { targets = {}, jobs = {}, refreshing = false, busy = false }
local settingsKey = 'machine-fabric.clipboard.target'
local home = os.getenv('HOME')
local binary = hs.settings.get('machine-fabric.clipboard.binary') or
  hs.settings.get('workbench.clipboard.binary') or os.getenv('MACHINE_FABRIC_CLIPBOARD_BIN') or
  os.getenv('WORKBENCH_CLIPBOARD_BIN') or (home .. '/.local/bin/machine-fabric')
local selected = hs.settings.get(settingsKey) or hs.settings.get('workbench.clipboard.target')
local errorText, lastResult, lastError
local progress = require('private/modules/clipboard-progress').new()

local function toast(message, failed)
  hs.alert.show(message, failed and 5 or 3)
end
local errorKeys = {
  {'CLIPBOARD_UNSUPPORTED','clipboard.error.unsupported'},
  {'NO_IMAGE','clipboard.error.noImage'},
  {'CLIPBOARD_TOO_LARGE','clipboard.error.tooLarge'},
  {'CLIPBOARD_UNAVAILABLE','clipboard.error.unavailable'},
  {'TARGET_UNAVAILABLE','clipboard.error.targetUnavailable'},
  {'TARGET_CHECK_TIMEOUT','clipboard.error.checkTimeout'},
  {'CLIPBOARD_UNCONFIRMED','clipboard.error.unconfirmed'},
  {'RPC_TIMEOUT','clipboard.error.timeout'},
  {'EXECUTOR_UNAVAILABLE','clipboard.error.executorUnavailable'},
  {'unrecognized subcommand','clipboard.error.outdated'},
}
local function reason(message)
  message = tostring(message or '')
  for _,entry in ipairs(errorKeys) do
    if message:find(entry[1],1,true) then return t(entry[2]),entry[1] end
  end
  -- Preserve unknown external diagnostics, without guessing their language.
  return (message:gsub('[\r\n]+', ' ')):sub(1, 240)
end
local function findTarget(id)
  for _, target in ipairs(M.targets) do
    if target.nodeId == id then return target end
  end
end
-- A metadata timeout says nothing about clipboard availability. On an explicit
-- send, let the CLI snapshot the image and check this same target again.
local function canAttempt(target)
  return target and (target.ready or tostring(target.reason):find('RPC_TIMEOUT', 1, true) ~= nil)
end
local function targetReason(target)
  if canAttempt(target) and not target.ready then return t('clipboard.retryCheck') end
  return reason(target.reason)
end
local function updateTitle()
  if M.menu then
    M.menu:setTitle(t('clipboard.badge') .. (M.busy and '…' or ''))
    M.menu:setTooltip(t('clipboard.tooltip') .. (selected and (' → ' .. selected) or ''))
  end
  if M.onChange then M.onChange() end
end
local function run(args, timeout, callback, onProgress)
  local job = {}
  local pending = ''
  local streamedOut = ''
  local streamedErr = ''
  M.jobs[job] = true
  local function finish(code, out, err)
    if not M.jobs[job] then return end
    M.jobs[job] = nil
    if job.timer then job.timer:stop() end
    if job.completionTimer then job.completionTimer:stop() end
    local raw = streamedOut~='' and (streamedOut .. (out or '')) or out
    local ok, value = false, nil
    if raw and raw~='' then ok,value=pcall(hs.json.decode,raw) end
    if code == 0 and ok and type(value) == 'table' and value.ok then
      callback(value.result, nil)
    else
      local message = ok and type(value) == 'table' and value.error and value.error.message
      local diagnostic = err and err~='' and err or streamedErr
      local text,code = reason(message or (diagnostic~='' and diagnostic) or t('clipboard.error.invalidResult'))
      callback(nil, text, code)
    end
  end
  local function stream(_, out, err)
    streamedOut=streamedOut .. (out or '')
    pending = pending .. (err or '')
    while true do
      local newline = pending:find('\n',1,true)
      if not newline then break end
      local line=pending:sub(1,newline-1)
      pending=pending:sub(newline+1)
      local ok,event=false,nil
      if line:sub(1,1)=='{' then ok,event=pcall(hs.json.decode,line) end
      if ok and type(event)=='table' and event.event=='clipboard.progress' and M.jobs[job] then
        job.stage=event.stage
        onProgress(event)
      elseif not (ok and type(event)=='table' and event.event=='clipboard.progress') then
        streamedErr=streamedErr .. line .. '\n'
      end
    end
    return true
  end
  local function terminated(code,out,err)
    if job.timer then job.timer:stop() end
    -- hs.task may deliver its final stream chunk AFTER termination. Consume it
    -- before parsing the result; progress records are never error messages.
    job.completionTimer=hs.timer.doAfter(0,function()finish(code,out,err)end)
  end
  job.task = onProgress and hs.task.new(binary, terminated, stream, args) or hs.task.new(binary, finish, args)
  if not job.task then finish(1, '', t('clipboard.error.start')); return end
  -- GUI apps do not inherit the shell's XDG exports.
  local env = job.task:environment()
  env.XDG_CONFIG_HOME = env.XDG_CONFIG_HOME or (home .. '/.config')
  env.XDG_STATE_HOME = env.XDG_STATE_HOME or (home .. '/.local/state')
  env.XDG_DATA_HOME = env.XDG_DATA_HOME or (home .. '/.local/share')
  if onProgress then env.WORKBENCH_CLIPBOARD_PROGRESS='1' end
  job.task:setEnvironment(env)
  if not job.task:start() then finish(1, '', t('clipboard.error.start')); return end
  job.timer = hs.timer.doAfter(timeout, function()
    job.task:terminate()
    local sent=job.stage=='transferring' or job.stage=='confirmed'
    finish(1, '', sent and 'RPC_TIMEOUT' or 'TARGET_CHECK_TIMEOUT')
  end)
end
function M.refresh()
  if M.refreshing or M.busy then return end
  M.refreshing = true
  run({'clipboard', 'targets', '--json'}, 15, function(result, err)
    M.refreshing = false
    errorText = err
    M.targets = result and result.targets or {}
    updateTitle()
  end)
end
local function selectReadyTarget(id, silent)
  if M.busy then toast(t('clipboard.busy')); return false end
  local target = findTarget(id)
  if not canAttempt(target) then
    if not silent then toast(target and reason(target.reason) or t('clipboard.selectFirst'), true) end
    M.refresh()
    return false
  end
  selected = id
  hs.settings.set(settingsKey, id)
  return true
end
local function sendImage(id)
  M.busy = true
  updateTitle()
  run({'clipboard', 'push', '--target', id, '--image-only', '--json'}, 100, function(result, err, code)
    M.busy = false
    lastError = err
    progress:finish(result,err,code)
    if result then
      lastResult = id .. ' · ' .. os.date('%H:%M:%S') .. ' · ' .. t('clipboard.success')
    else
      lastResult = id .. ' · ' .. t('clipboard.failed')
    end
    updateTitle()
    M.refresh()
  end, function(event)progress:update(event)end)
end
M.reason = reason
function M.status()
  return {targets=M.targets, selected=selected, lastResult=lastResult,
    lastError=lastError, error=errorText, refreshing=M.refreshing, busy=M.busy}
end
function M.selectTarget(id)
  if not selectReadyTarget(id) then return false end
  updateTitle()
  return true
end
function M.push(id)
  if M.busy then return end
  progress:start(id)
  if selectReadyTarget(id, true) then sendImage(id)
  else
    local target=findTarget(id)
    progress:finish(nil,target and reason(target.reason) or t('clipboard.selectFirst'))
  end
end
function M.pushSelected()
  M.push(selected)
end
local function menuItems()
  local target = findTarget(selected)
  local items = {
    {title = M.busy and t('clipboard.busy') or t('clipboard.sendTo',{name=selected or t('clipboard.noSelection')}),
      disabled = M.busy or not canAttempt(target), fn = function() M.push(selected) end},
    {title = '-'},
    {title = t('clipboard.chooseTarget'), disabled = true},
  }
  for _, entry in ipairs(M.targets) do
    local id = entry.nodeId
    table.insert(items, {title = id .. (entry.ready and '' or (' — ' .. targetReason(entry))),
      checked = id == selected, disabled = M.busy or not canAttempt(entry),
      fn = function() selected = id; hs.settings.set(settingsKey, id); updateTitle() end})
  end
  if #M.targets == 0 then table.insert(items, {title = errorText or t('clipboard.noTargets'), disabled = true}) end
  if selected and not target then table.insert(items, {title = selected .. ' — ' .. t('clipboard.disconnected'), disabled = true}) end
  table.insert(items, {title = '-'})
  table.insert(items, {title = M.refreshing and t('clipboard.refreshing') or t('clipboard.refresh'), disabled = M.refreshing, fn = M.refresh})
  if lastResult then table.insert(items, {title = t('clipboard.lastResult',{name=lastResult}), disabled = true}) end
  return items
end
function M.stop()
  progress:close()
  for job in pairs(M.jobs) do
    M.jobs[job] = nil
    if job.timer then job.timer:stop() end
    if job.completionTimer then job.completionTimer:stop() end
    if job.task then job.task:terminate() end
  end
  if M.timer then M.timer:stop() end
  if M.hotkey then M.hotkey:delete() end
  if M.menu then M.menu:delete() end
end
if not workbenchClipboardOptions or workbenchClipboardOptions.menu ~= false then
  M.menu = hs.menubar.new()
end
if M.menu then M.menu:setMenu(menuItems) end
-- Deliberately excludes Command: neither Hyper nor HyperAlt matches this chord.
if hs.hotkey.assignable({'ctrl', 'alt'}, 'v') then
  -- Send the existing clipboard image once on release; never synthesize Cmd-C.
  M.hotkey = hs.hotkey.bind({'ctrl', 'alt'}, 'v', function() end, M.pushSelected)
else
  toast(t('clipboard.hotkeyBusy'), true)
end
updateTitle()
M.refresh()
M.timer = hs.timer.doEvery(30, M.refresh)
return M
