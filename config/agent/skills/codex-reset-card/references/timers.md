# Linux 定时任务操作

生成器只写文件，所有命令均在实际运行任务的同一账号、同一机器执行。先确认 `systemctl --user` 可用。任务依赖机器开机、用户管理器运行及 Codex 登录有效；需要退出登录后仍运行时查看 `loginctl show-user "$USER" -p Linger`，不要未经授权修改系统级策略。不能保证机器条件时明确说明限制。

## 准备、校验、启用

从 `prepare_timer.py` 或 `prepare_watch.py` 输出中复制本次的 `task_name`、`config`、`service`、`timer`；以下变量是这些实际值，不要使用别的任务名或清理通配符：

```sh
TASK='本次 task_name'
CONFIG='本次 config 绝对路径'
SERVICE='本次 service 绝对路径'
TIMER='本次 timer 绝对路径'
SKILL='本 skill 的绝对路径'
# 指定时间任务：
python3 -B "$SKILL/scripts/reset_card.py" --config "$CONFIG" --check
# 额度耗尽轮询任务，使用此命令替代上一行：
python3 -B "$SKILL/scripts/watch_card.py" --config "$CONFIG" --check
systemd-analyze --user verify "$SERVICE" "$TIMER"
```

核对配置里的卡片、幂等键和到期时间。指定时间任务检查 `OnCalendar` 和执行窗口；日期被转换为 UTC，用 `systemd-analyze calendar '实际 OnCalendar 值'` 检查。轮询任务检查 `monitor_deadline_epoch`、`OnActiveSec=1s` 和 `OnUnitInactiveSec=60s`。环境文件属于私有文件，不输出其内容。

用户已授权安排且检查通过后：

```sh
systemctl --user daemon-reload
systemctl --user enable --now "$TASK.timer"
systemctl --user is-enabled "$TASK.timer"
systemctl --user show "$TASK.timer" -p ActiveState -p NextElapseUSecRealtime -p LastTriggerUSec
```

核对 `ActiveState=active` 和下一次触发时间正确，才报告已安排；轮询用 `systemctl --user list-timers "$TASK.timer" --all` 查看下一次触发。轮询首次检查几乎立即进行；若核验时 timer 已停用，先读取回执和 `watch-status.json`，按实际结果报告，不重复启用或提交。指定时间任务的 `Persistent=true` 允许重启后补触发；轮询任务在用户管理器启动后重新检查。执行器会拒绝在已结束的窗口发出请求，不保证关机错过的任务还能执行。超时、过期或失败均不会自动换卡或创建下一次任务。

配置在 `${XDG_CONFIG_HOME:-~/.config}/codex-reset-card/`，unit 在其 `systemd/user/` 同级配置根目录下；状态在 `${XDG_STATE_HOME:-~/.local/state}/codex-reset-card/<任务名>/`。配置和环境文件仅当前用户可读写。service 使用绝对 Python/Codex/执行器路径及原 PATH/CODEX_HOME/XDG 环境；执行环境中的代理变量包含大小写两份。

## 查状态

```sh
systemctl --user show "$TASK.timer" -p ActiveState -p NextElapseUSecRealtime -p LastTriggerUSec
systemctl --user show "$TASK.service" -p ActiveState -p Result -p ExecMainStatus
journalctl --user -u "$TASK.service" --no-pager -n 40
```

读取该任务 `state_dir` 中的 `attempt.json`、`receipt.json` 和 `events.jsonl`；轮询任务还读取 `watch-status.json` 和首次达到条件后生成的 `watch-execution.json`。只回报所需字段，保留原始 outcome。轮询在已知回执、监控截止、未知回执或执行恢复窗口结束时自动停用自身 timer；停用失败会保留状态并在下一次触发时重试停用。历史执行器可能将 `nothingToReset` 计为 service 失败，仍以回执解释实际结果；新执行器把四种已知结果都作为终态，不反复尝试。没有回执但有 attempt 时不能断言卡未使用。

## 取消、改期与清理

```sh
systemctl --user disable --now "$TASK.timer"
systemctl --user stop "$TASK.service"
systemctl --user is-enabled "$TASK.timer"
systemctl --user show "$TASK.timer" "$TASK.service" -p Id -p ActiveState
```

确认 timer 未启用且两者均未运行后，报告未来触发已取消。执行中取消时先读回执；停止本地进程不能撤销服务端已接受的请求。保留配置、幂等键、attempt、receipt 和日志供核查，除非用户要求清理这些证据。

改期先停用 timer 并停止 service，再检查回执。有已知终态回执的任务应报告原结果，不能直接清空回执重新用卡。无回执但有 attempt 的任务先确认未知结果，不能通过延期扩展原恢复窗口。尚未提交的指定时间任务可在同一配置、同一卡和同一幂等键下修改 `execute_at`、`not_before_epoch`、`deadline_epoch` 与 `OnCalendar`；截止时间取新开始时间加有限运行时长与卡片到期时间的较小值。轮询任务仅在没有 `watch-execution.json` 或 `attempt.json` 时可修改监控截止，且不得晚于卡片到期；否则保留原执行窗口。重新校验、daemon-reload、启用并核对实际时间。

用户明确要求删除一个已取消任务时，仅删除该任务 unit 与指定文件，再 daemon-reload；不要删除整个目录或其他任务的资料。日常使用不必移除独立且可审计的历史记录。
