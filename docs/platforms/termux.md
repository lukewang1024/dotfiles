# Termux setup

Run the normal core flow for the Termux shell environment:

```sh
./init core
```

This installs/configures the Termux packages, zsh, tmux plugins, Vim plugins,
SSH, and the shared agent configuration. It also installs `agent-team` through
the common core flow.

The Termux shell setup downloads the pinned MesloLGS Nerd Font Regular file to
`$XDG_CACHE_HOME/termux/fonts/`, verifies its SHA256, and links it to
`~/.termux/font.ttf`. The font binary stays outside the repository. The upstream
font has an [Apache-2.0 license](https://raw.githubusercontent.com/romkatv/powerlevel10k-media/145eb9fbc2f42ee408dacd9b22d8e6e0e553f83d/MesloLGS%20NF%20License.txt)
and comes from [`romkatv/powerlevel10k-media`](https://github.com/romkatv/powerlevel10k-media).
The core flow also installs the configured Tmux plugins through TPM, including
`tmux-adaptive-theme`.

Generate this phone's SSH client keys separately in a Termux terminal:

```sh
./init ssh-keys
```

This creates missing Ed25519 and RSA 3072-bit pairs with interactive passphrase
prompts and keeps existing keys. Core enables the SSH services but no longer
generates an unencrypted client key automatically. Copy the `.pub` keys to the
devices you want to access.

Machine Fabric v0.1.33 publishes an Android aarch64 runtime. To install it from
the pinned release, provide the release CDN root explicitly:

```sh
MACHINE_FABRIC_VERSION=0.1.33 \
MACHINE_FABRIC_RELEASE_BASE_URL=https://<release-cdn-root> \
./init core
```

The same variables can be used with `./init machine-fabric`. The installer
configures the local Controller/Executor through `termux-services`; peer
topology remains owned by Machine Fabric's release/bootstrap tools. The old
distributed-workbench peer bootstrap is no longer part of dotfiles.

## Kerberos SSH

Termux 和 iSH 共用 `ssh-connect`。在已有 Kerberos/KDC 配置基础上，为需要
Kerberos 的 **SSH 别名**配置 Principal。也会通过 `ssh -G` 识别开启 GSSAPI 的主机；
未显式映射时，从设备的 `kinit-auto-login/kinit.env` 或现有缓存读取 Principal。
没有 GSSAPI、也没有映射的主机继续使用原来的 SSH 认证方式。
以下均为占位值，请只在自己的设备上替换：

```sh
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/ssh"
umask 077
# 用编辑器添加一行，保留已有主机；格式为 HOST PRINCIPAL [TMUX_SESSION]
vi "${XDG_CONFIG_HOME:-$HOME/.config}/ssh/kerberos"
```

```text
devbox yourname@YOUR.REALM dev
```

SSH HostName/User/Port 仍在 `~/.ssh/config` 中配置。若使用 Termux 软键盘的 SSH
按钮（`ssh-connect --workbench`），在 dotfiles Include **之前**为该别名添加以下
设置。workbench 会自己启动 SSH，因此共享入口会验证这些设置；不安全时会停止并提示。
普通 `ssh-connect` 和 `--tmux` 则直接在命令行强制同样的认证策略。

```sshconfig
Host devbox
  HostName dev.your-domain.example
  User your-linux-user
  Port 22
  GSSAPIAuthentication yes
  GSSAPIDelegateCredentials no
  PreferredAuthentications gssapi-with-mic
  PubkeyAuthentication no
  PasswordAuthentication no
  KbdInteractiveAuthentication no
  HostbasedAuthentication no
  ControlMaster no
  ControlPath none
  StrictHostKeyChecking ask
  ConnectTimeout 10
  TCPKeepAlive no
  ServerAliveInterval 5
  ServerAliveCountMax 3
```

```sh
ssh-connect hosts edit --discover  # 把 devbox 加入选择列表（已有清单时需要）
ssh-connect                        # 选择主机并连接
ssh-connect --tmux                 # 选择主机，进入/恢复远端 tmux
ssh-connect --workbench            # Termux 的原有工作台入口，现包含票据检查
ssh-connect connect devbox --tmux  # 直接连接指定别名
ssh-connect connect devbox --check # 不取票、不提示指纹，认证后执行 whoami
ssh-connect --workbench --no-reconnect # 只连接一次，不自动重连
```

有有效且 Principal 匹配的 TGT 时直接连接；无票据、过期或身份不匹配时，交互执行
刷新：先调用已有的 `kinit-auto-login renew --principal ...`（复用 keytab/keychain），
再尝试同一身份的 `kinit -R`；仍失败才提示输入密码执行 `kinit`。每一步都再次校验
身份和 TGT，成功后继续原来的 SSH/tmux/workbench 连接。密码只输入给 kinit，
不写入参数、配置或环境变量。非交互环境
直接报错；`hosts` 和 `--print` 不会取票。使用 Termux 现有 `krb5.conf` 和凭证缓存，
不会改成 iSH 的路径。首次连接仍须通过可信渠道核对主机指纹。

交互式 `--tmux` 和 `--workbench` 遇到连接错误会重连同一主机。首次断线后，
本次调用最多自动重试 5 次，每次连接失败后分别等待 1、2、4、8、16 秒；
连接尝试和票据检查耗时不会扣减重试次数，也不会截短退避等待，因此网络超时较长时
总重连时间会相应延长。
达到次数上限后，保留终端，只等待手动重连，不再循环自动尝试。

退避等待期间按回车会提前执行下一次重连，并计入这轮 5 次预算；达到上限后，
每按一次回车只尝试一次，失败后继续等回车。回车不会重置自动重试次数预算。
等待时按 Ctrl-C 退出；终端输入设置会恢复。已经建立的连接不会被重试次数上限
中断。远端 tmux 中的进程继续运行；workbench 会沿用当前终端身份恢复
工作位置，并重建通知通道。正常退出或 detach 结束连接，`--no-reconnect` 可禁用。
普通 SSH、`--check` 和非交互调用不会自动重连。workbench 将各种连接/协议错误
统一返回为 1，因此配置或远端程序错误也可能进入重试；检查错误信息，按 Ctrl-C
后修复配置。

`--tmux` 自动重连模式使用 5 秒心跳、3 次未响应判定和 10 秒连接超时。
workbench 自己启动 SSH，需要在上面的 Host 配置中设置这些参数；黑洞连接通常
约 15 秒被发现，显式断开可能更快。Wi-Fi/蜂窝切换改变 IP 或 NAT 映射时，原 TCP
连接可能无法继续，自动重连期间会短暂停顿。Mosh 支持跨 IP 漫游，但需要客户端
和服务端安装并允许 UDP；当前 workbench 的 SSH 控制/通知通道仍需单独处理。

这是连接和重连时按需取票，不是后台续票服务。自动刷新失败时才需要输入密码；
已建立的 SSH 不会因为本地 TGT 到期而由本脚本主动重连。Termux 切网实机验收
仍需在设备上完成。

## Follow Android light/dark mode

`util/termux/termux-system-theme` checks Android's resolved `am get-config`
night mode every 10 seconds and switches `~/.termux/colors.properties` between
`config/termux/theme-light.properties` (Catppuccin Latte) and
`theme-dark.properties` (Catppuccin Mocha), copied from the default iTerm2 profile.
It retries the Termux reload every check, including when the palette link is
already correct: Termux unregisters its reload receiver in the background, so a
one-shot broadcast can be lost. A transient reload failure does not stop the
service. It needs no root.
`./init basic` applies the current palette once. `./init core` also installs and
enables the background service through `termux-services`. On first installation,
the service daemon starts in a new Termux shell; bootstrap records the service
as enabled and reports when it cannot start in the current shell. Re-running
initialization selects the current Android palette again without pushing theme
changes to SSH hosts.
Use `sv-disable termux-system-theme` to stop following the system. Running
`termux-system-theme --once` applies the palette and synchronizes attached
terminals; `termux-system-theme --local-once` applies only the local palette.
Android may suspend the service in the background; it catches up after resuming.
Applications drawing their own backgrounds may require a restart to adapt.
The service also calls `theme-push-remotes` to synchronize attached SSH devboxes.
The relay discovers live SSH/workbench connections even when forwards are
cleared; forwarded tmux sockets remain an optional fast path. Successful
mode/connection pairs are cached under `$XDG_STATE_HOME/appearance-remotes`;
new connections synchronize immediately and failures retry at the next check.
The remote must already have `~/.local/bin/theme-sync`. Fresh SSH relay commands
clear forwards so desktop-specific `LocalForward` paths do not break mobile sync.

### Agent refresh after a theme change

Normal `codex` and `traex` launches through the zsh
resume-history wrapper now monitor the
effective terminal colors from `config/zsh/agent_theme_restart.py`. It queries
the displayed foreground/background using OSC 10/11. Terminal-only refreshes
follow background changes: tmux's foreground dimming on pane focus changes
must not trigger a restart or reset the theme debounce. Foreground replies
still verify delivery of Termux palette-file changes. Inside Linux tmux, when
the host has published `${XDG_STATE_HOME:-~/.local/state}/appearance`, it watches
atomic file replacements with inotify: one startup query, then queries only
after the mode changes. Identical publications do not trigger queries. A
two-second debounce and bounded confirmation retries cover asynchronous tmux
repainting. An unavailable/lost watch falls back to five-second queries, as do
ordinary terminals, macOS and Termux's palette-reload path. Idle supervisors
block on input, output and theme events instead of waking four times a second.
On Linux tmux, unavailable watches are retried every 30 seconds. Each outage
prints one diagnostic to stderr, and successful recovery prints one notice.
Recovery confirms the displayed palette before returning to event-only queries;
unsupported hosts keep their normal polling without watch retries.
The Termux palette file is also checked. A delayed reload therefore triggers refresh even
when the file was already correct, and a supported color query prevents
restarting before the new palette is actually displayed. Query replies do not
count as typing or postpone the idle guard. The PTY
supervisor reads the agent's own OSC terminal title (`Working`, `Thinking`, `Ready`),
waits for `Ready`, an attached thread ID and two seconds without input, then requests a graceful Ctrl+D
exit. It resumes only when that exit succeeds and prints an exact session ID;
manual exits, errors and missing IDs never trigger an automatic relaunch.
The exit hint must also match the attached thread ID shown in the title.
After a three-second exit wait, input is accepted again without discarding the
pending exit identity: a slow successful shutdown still resumes, while real
user input cancels that identity and prevents a later manual exit from resuming.
The supervisor does not issue a stop command to a separate shared app-server.
Launch arguments and proxy environment are preserved, while the original prompt is not sent again.

Pasted input and unconfirmed submissions defer the refresh. The Codex adapter
can make one guarded Ctrl+D attempt even with a stale draft flag: Codex itself
accepts this only with an empty composer and no active modal/popup. A refusal
blocks further attempts until actual input changes. TraeX retains the conservative
draft guard pending validation of its native empty-composer behavior. A subsequent
submission confirmed by `Working`/`Thinking` clears the conservative draft guard.
For restored drafts or popups, the native empty-composer check can refuse the
exit; no timeout kills the UI. The supervised frontend reserves Ctrl+D for
quitting and leaves Delete/Shift+Delete for deleting forward, so a refused quit
cannot remove draft text. These keymap and title overrides affect this launch
only. Unknown options, embedded (`--no-daemon`) servers, image inputs, worktrees
and noninteractive commands use the original launch path without auto-refresh.
Automatic reconnects also skip the startup update prompt and select the saved
session directory through temporary overrides; permanent settings are unchanged.

An already-running wrapper needs one normal exit/resume to load the new helper.
Run `AGENT_THEME_RESTART=0 codex` (or `traex`) to disable automatic refresh.
The individual `CODEX_THEME_RESTART=0` and `TRAEX_THEME_RESTART=0` switches
are also supported.

This supervisor also runs on macOS/Linux POSIX terminals; it has no Android
requirement. There, OSC 10/11 replies are the sole color source, so it follows
the actual terminal palette, including over SSH, rather than guessing from the
local OS. Termux adds its palette file as a reload-delivery check. The terminal
must answer the color queries and the CLI must emit a supported Ready title
with a thread ID. Unsupported states never authorize a restart.

TraeX 0.209.1 release inspection confirmed the terminal-title/keymap configuration
fields. TraeX title/exit/resume behavior is covered by PTY contract tests; an
actual installed TraeX session still needs validation on a supported machine.

Desktop terminal palette switching is independent: iTerm2 uses separate
light/dark profile colors, Kitty uses its native `*-theme.auto.conf` files, and
Alacritty uses the macOS `appearance-daemon` / `dark-notify` callback to rewrite
its imported theme. These switches do not themselves refresh cached agent UI
colors. The shared supervisor handles that subsequent step.
