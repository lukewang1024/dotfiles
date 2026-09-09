-- Explicit image transfer. Timers refresh node metadata, never clipboard contents.
local M = { targets = {}, jobs = {}, refreshing = false, busy = false }
local settingsKey = 'workbench.clipboard.target'
local home = os.getenv('HOME')
local binary = hs.settings.get('workbench.clipboard.binary') or os.getenv('WORKBENCH_CLIPBOARD_BIN') or (home .. '/.local/bin/workbench')
local selected = hs.settings.get(settingsKey)
local errorText, lastResult, lastError

local function toast(message, failed)
  hs.alert.show(message, failed and 5 or 3)
end
local function reason(message)
  message = tostring(message or '')
  if message:find('CLIPBOARD_UNSUPPORTED', 1, true) then return '节点尚未安装图片剪贴板支持' end
  if message:find('NO_IMAGE', 1, true) then return '剪贴板中没有图片' end
  if message:find('CLIPBOARD_TOO_LARGE', 1, true) then return '图片过大（像素数据上限 16 MiB）' end
  if message:find('CLIPBOARD_UNAVAILABLE', 1, true) then return '远端剪贴板未就绪' end
  if message:find('TARGET_UNAVAILABLE', 1, true) then return '目标设备未连接，请重新选择' end
  if message:find('RPC_TIMEOUT', 1, true) then return '等待超时，结果未确认；不会自动重试' end
  if message:find('EXECUTOR_UNAVAILABLE', 1, true) then return '远端执行服务不可用' end
  if message:find('unrecognized subcommand', 1, true) then return '本机 workbench 尚未安装图片同步版本' end
  return (message:gsub('[\r\n]+', ' ')):sub(1, 240)
end
local function findTarget(id)
  for _, target in ipairs(M.targets) do
    if target.nodeId == id then return target end
  end
end
local function updateTitle()
  if M.menu then
    M.menu:setTitle(M.busy and '图↑…' or '图↑')
    M.menu:setTooltip('Workbench 图片同步' .. (selected and (' → ' .. selected) or ''))
  end
  if M.onChange then M.onChange() end
end
local function run(args, timeout, callback)
  local job = {}
  M.jobs[job] = true
  local function finish(code, out, err)
    if not M.jobs[job] then return end
    M.jobs[job] = nil
    if job.timer then job.timer:stop() end
    local ok, value = pcall(hs.json.decode, out or '')
    if code == 0 and ok and type(value) == 'table' and value.ok then
      callback(value.result, nil)
    else
      local message = ok and type(value) == 'table' and value.error and value.error.message
      callback(nil, reason(message or err or 'CLI 返回了无效结果'))
    end
  end
  job.task = hs.task.new(binary, finish, args)
  if not job.task then finish(1, '', '无法启动 workbench CLI'); return end
  -- GUI apps do not inherit the shell's XDG exports.
  local env = job.task:environment()
  env.XDG_CONFIG_HOME = env.XDG_CONFIG_HOME or (home .. '/.config')
  env.XDG_STATE_HOME = env.XDG_STATE_HOME or (home .. '/.local/state')
  env.XDG_DATA_HOME = env.XDG_DATA_HOME or (home .. '/.local/share')
  job.task:setEnvironment(env)
  if not job.task:start() then finish(1, '', '无法启动 workbench CLI'); return end
  job.timer = hs.timer.doAfter(timeout, function()
    job.task:terminate()
    finish(1, '', 'RPC_TIMEOUT')
  end)
end
function M.refresh()
  if M.refreshing then return end
  M.refreshing = true
  run({'clipboard', 'targets', '--json'}, 15, function(result, err)
    M.refreshing = false
    errorText = err
    M.targets = result and result.targets or {}
    updateTitle()
  end)
end
local function selectReadyTarget(id)
  if M.busy then toast('正在同步图片，请稍候'); return false end
  local target = findTarget(id)
  if not target or not target.ready then
    toast(target and reason(target.reason) or '请按 Ctrl+Alt+Shift+V 选择已连接的同步目标', true)
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
  run({'clipboard', 'push', '--target', id, '--image-only', '--json'}, 30, function(result, err)
    M.busy = false
    lastError = err
    if result then
      lastResult = id .. ' · ' .. os.date('%H:%M:%S') .. ' · 成功'
      toast('图片已同步到 ' .. id .. '，可在 Codex 按 Ctrl-V')
    else
      lastResult = id .. ' · 同步失败'
      toast('同步到 ' .. id .. ' 失败：' .. err, true)
    end
    updateTitle()
    M.refresh()
  end)
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
  if selectReadyTarget(id) then sendImage(id) end
end
function M.pushSelected()
  M.push(selected)
end
local function menuItems()
  local target = findTarget(selected)
  local items = {
    {title = M.busy and '正在同步图片…' or ('同步图片到 ' .. (selected or '（未选择）')),
      disabled = M.busy or not target or not target.ready, fn = function() M.push(selected) end},
    {title = '-'},
    {title = '选择目标设备', disabled = true},
  }
  for _, entry in ipairs(M.targets) do
    local id = entry.nodeId
    table.insert(items, {title = id .. (entry.ready and '' or (' — ' .. reason(entry.reason))),
      checked = id == selected, disabled = M.busy or not entry.ready,
      fn = function() selected = id; hs.settings.set(settingsKey, id); updateTitle() end})
  end
  if #M.targets == 0 then table.insert(items, {title = errorText or '没有已连接的目标设备', disabled = true}) end
  if selected and not target then table.insert(items, {title = selected .. ' — 已断开，不会改发其他设备', disabled = true}) end
  table.insert(items, {title = '-'})
  table.insert(items, {title = M.refreshing and '正在刷新设备…' or '刷新设备', disabled = M.refreshing, fn = M.refresh})
  if lastResult then table.insert(items, {title = '上次同步：' .. lastResult, disabled = true}) end
  return items
end
function M.stop()
  for job in pairs(M.jobs) do
    M.jobs[job] = nil
    if job.timer then job.timer:stop() end
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
  toast('图片同步快捷键已占用，请使用菜单', true)
end
updateTitle()
M.refresh()
M.timer = hs.timer.doEvery(30, M.refresh)
return M
