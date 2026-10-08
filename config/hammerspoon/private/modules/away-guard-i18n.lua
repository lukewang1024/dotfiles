local language = require('private/modules/hyper-i18n')
local M = {}
local messages = {
  armed = {en='Away guard enabled: external displays disabled, internal brightness at 0.', zh='离开守护已开启：外屏已禁用，内屏亮度为 0。'},
  alreadyArmed = {en='Away guard is active. Increase brightness and authenticate to return.', zh='离开守护已开启；调亮屏幕并认证解锁后退出。'},
  inactive = {en='Away guard is not active.', zh='离开守护尚未开启。'},
  openLid = {en='Open the MacBook lid before enabling away guard.', zh='请打开 MacBook 内屏后再开启守护。'},
  brightnessUnavailable = {en='Cannot read internal display brightness. Away guard was not enabled.', zh='无法读取内屏亮度，未开启守护。'},
  captureFailed = {en='Cannot save window layout. Away guard was not enabled.', zh='无法保存窗口布局，未开启守护。'},
  keepAwakeFailed = {en='Cannot prevent sleep. Away guard was not enabled.', zh='无法阻止休眠，未开启守护。'},
  monitorFailed = {en='Cannot start display control. Away guard was not enabled.', zh='无法启动外屏控制，未开启守护。'},
  preparingRdp = {en='Preparing away guard: leaving RDP fullscreen before disabling external displays.', zh='正在准备离开守护：先退出 RDP 全屏，再禁用外屏。'},
  rdpRestoreFailed = {en='RDP fullscreen restore failed. Recovery data retained; lock and unlock again to retry.', zh='RDP 全屏恢复失败，已保留恢复信息；再次锁屏并解锁可重试。'},
  windowsRestoreFailed = {en='Some windows could not be restored. Details logged and snapshot retained; lock and unlock again to retry.', zh='部分窗口未能恢复，已记录原因并保留快照；再次锁屏并解锁可重试。'},
  displaysRestoreFailed = {en='Display restore failed. Recovery data retained; lock and unlock again to retry.', zh='外屏恢复失败，已保留恢复信息；再次锁屏并解锁可重试。'},
  restoreStartFailed = {en='Cannot start display restore. Recovery data retained.', zh='无法启动外屏恢复，已保留恢复信息。'},
  restored = {en='Brightness, displays and windows restored. Lock reason: {reason}', zh='已恢复亮度、外屏和窗口。锁屏原因：{reason}'},
  unknownReason = {en='Display monitor reported an error: {detail}', zh='显示监视进程报告异常：{detail}'},
  brightnessReason = {en='Internal brightness increased or could not be read ({value})', zh='内屏亮度升高或无法读取（{value}）'},
}
local reasons = {
  ['keep-awake process stopped'] = {en='Keep-awake process stopped', zh='保活进程停止'},
  ['keep-awake process exited'] = {en='Keep-awake process exited', zh='保活进程退出'},
  ['RDP fullscreen exit timed out'] = {en='RDP fullscreen exit timed out', zh='退出 RDP 全屏超时'},
  ['display monitor stopped'] = {en='Display monitor stopped', zh='显示监视进程停止'},
  ['display monitor exited'] = {en='Display monitor exited', zh='显示监视进程退出'},
  ['display setup timed out'] = {en='Display setup timed out', zh='显示器准备超时'},
  ['display monitor unresponsive'] = {en='Display monitor heartbeat timed out', zh='显示监视进程心跳超时'},
  ['display changed'] = {en='Connected displays changed', zh='连接的显示器发生变化'},
  ['display configuration changed'] = {en='Display configuration changed', zh='显示器配置发生变化'},
  ['display reconfiguration'] = {en='Display reconfiguration detected', zh='检测到显示器重新配置'},
  ['physical or online topology changed'] = {en='Physical or online displays changed', zh='物理连接或在线显示器发生变化'},
  ['invalid display monitor message'] = {en='Invalid display monitor message', zh='显示监视进程消息无效'},
  ['display snapshot mismatch'] = {en='Display snapshot mismatch', zh='显示器快照不一致'},
  ['internal screen disappeared'] = {en='Internal display disappeared', zh='内置屏幕消失'},
  ['cannot darken internal screen'] = {en='Cannot darken internal display', zh='无法将内屏亮度降到 0'},
  ['system sleep'] = {en='System sleep', zh='系统进入睡眠'},
  ['system wake'] = {en='System wake', zh='系统唤醒'},
  ['manual return'] = {en='Manual return requested', zh='手动请求锁屏并退出'},
  ['system_or_external_lock'] = {en='System or another application locked the screen', zh='系统或其他应用触发锁屏'},
}
local function render(entry, values, locale)
  local text = entry[language.normalize(locale or language.detect())] or entry.en
  return (text:gsub('{([%w_]+)}', function(key)
    if values and values[key] ~= nil then return tostring(values[key]) end
    return '{' .. key .. '}'
  end))
end
function M.t(key, values, locale)
  assert(messages[key], 'Unknown away guard message: ' .. tostring(key))
  return render(messages[key], values, locale)
end
function M.reason(reason, locale)
  reason = reason or 'system_or_external_lock'
  if reasons[reason] then return render(reasons[reason], nil, locale) end
  local value = reason:match('^brightness increased or unreadable: (.*)$')
  if value then return M.t('brightnessReason', {value=value}, locale) end
  -- Preserve unfamiliar native errors verbatim as diagnostic detail.
  return M.t('unknownReason', {detail=reason}, locale)
end
return M
