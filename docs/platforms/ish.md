# iSH on iPad

iSH 和 Termux 使用同一个 dotfiles 初始化入口、任务执行器、日志格式和公共配置。
完整初始化目前以 Alpine 3.24 x86 为实测基线。iSH 自带的 3.14.3 不满足公共
初始化器的 Python 3.10+ 要求；先按下方步骤导入新的独立文件系统，保留旧系统。
已启动合适的 Alpine x86 后，直接 clone：

```sh
apk add --no-cache ca-certificates git
mkdir -p ~/.config
git -c http.version=HTTP/1.1 clone --depth 1 \
  https://github.com/lukewang1024/dotfiles.git ~/.config/dotfiles
cd ~/.config/dotfiles
./init core
. ~/.profile
./init kerberos
exec zsh -l
```

`init` 自动识别 iSH，缺少 Python 时用 Alpine 的 `apk` 安装 Python 3，随后进入公共
初始化器。无需另找安装脚本，也不需要安装 Docker 或编译模拟器。

大型 Rime 资源已迁入 Git LFS，仓库默认跳过资源下载。iSH 不需要安装 git-lfs，
不需要稀疏检出，也不会在初始化时获取桌面词库、字体或语言模型。
旧 checkout 请先执行 [一键历史迁移](../LFS_MIGRATION.md)，再恢复正常 pull；
脚本会检查本地工作、保留完整备份并在原路径建立新 checkout。

`curl 56`、`early EOF`、`invalid index-pack output` 表示这次接收未完整结束，
仅凭这些日志无法确定服务器、代理或网络中的具体原因。迁移减少了普通 Git 下载量；
如果仍中断，检查网络/VPN。失败留下的目录先改名保留，不要删除已有配置。

| 命令 | 与 Termux 一致的用途 |
| --- | --- |
| `./init core` | 安装本机可用的软件、zsh、Git、Vim、tmux 配置和适用插件 |
| `./init all` | iSH 和 Termux 都没有额外桌面软件组，等同 core |
| `./init basic` / `./init sync` | 仅更新配置与工具链接，不安装软件、不联网下载插件 |
| `./init kerberos` | 交互配置 Kerberos 和远程主机；不询问或保存密码 |
| `./init workbench` | 安装或修复 tmux-agent-workbench 的本机核心和命令 |
| `./init --list-tasks` | 查看公共任务 |
| `./init --dry-run --json --platform ish core` | 在其他机器预览，无安装和文件修改 |

日志沿用 `$XDG_STATE_HOME/dotfiles/bootstrap/` 的 `output.log` 和 `results.json`。
重复初始化保留 Kerberos 配置、SSH 本地内容和主机指纹。更新已有启动文件时保留原内容并备份。
`kerberos` 明确确认后才备份并替换配置；管理员配置可以直接导入。

### 系统 Python 能显示版本但无法执行代码

iPad mini 4、App Store iSH 1.3.2 (494)、Alpine 3.24.3 上实测：系统 Python 3.14.8
可以执行 `--version`，但初始化解释器时停在原子指令重试循环，简单 `-c` 也不能完成。
这与此前 Linux 主机上 iSH CLI 的测试环境不同。不要根据版本输出判断解释器可用。
`init` 在 iSH 上为运行时探测设置超时；已安装的 Python 仍不可执行时会明确报错。

可将 Alpine 3.22 的 Python 3.12 包单独解压到 XDG 数据目录，保留系统 Python 及
系统的 3.24 软件源。以下命令只下载、验证和解压，不安装跨分支系统包：

```sh
runtime=${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/ish-python
cache=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/ish-python
mkdir -p "$runtime" "$cache"
apk fetch --repositories-file /dev/null \
  --repository https://dl-cdn.alpinelinux.org/alpine/v3.22/main \
  --output "$cache" python3
apk verify "$cache"/python3-*.apk
tar -xzf "$cache"/python3-*.apk -C "$runtime"
sh util/ish/python3 -c 'import sys; print(sys.version)'
./init core
```

使用新的缓存目录，确保其中只有一个 Python APK。仍依赖当前系统提供兼容的
共享库；缺库时应从当前系统分支补齐依赖，不要混装旧分支软件包。
`init` 仅在 iSH 且检测到该独立运行时后优先使用它；其他平台的发现顺序不变。
初始化也会把 Python 包装命令链接到 `~/.local/bin/python3`，供之后的登录环境使用。
首次导入标准库在老 iPad 上可能很慢，需要结合日志判断进度。

### APK 在安装权限时触发 Bad system call

同一 App Store iSH 上，apk-tools 3.0.8 安装 Kerberos 时实测被 SIGSYS 终止，
`dmesg` 显示 `apk missing syscall 452`，即缺少 `fchmodat2`。
`util/ish/apk-compat.c` 为 APK 解压出的普通文件和目录提供兼容实现：
使用 `openat` 打开目标并通过 `fchmod` 修改权限，要求不跟随链接时使用 `O_NOFOLLOW`，
不把失败当作成功，也不静默忽略权限设置。

在支持交叉编译的机器上可生成 Linux i386 动态库：

```sh
clang --target=i386-linux-musl -DISH_STANDALONE_BUILD -nostdlib \
  -shared -fPIC -fuse-ld=lld -O2 util/ish/apk-compat.c -o libapk-compat.so
```

将库放入 iSH 的 `${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/ish-compat/libapk-compat.so`。
初始化只在 APK 安装/更新命令的子进程环境中加载它，不设置全局 `LD_PRELOAD`。
系统包安装完成后，重跑会先检查包是否齐全；齐全则跳过索引刷新与安装，
但仍检查 Kerberos SSH 客户端是否可用。此兼容库仅针对上述已复现的平台问题，
不作为通用 libc 替代品。

### 登录后退出：ncurses 调用 setfsuid32

App Store iSH 1.3.2 (494)、Alpine 3.24.3 上，交互式 Zsh 初始化终端时可触发
`zsh missing syscall 215`，以 SIGSYS（退出码 159）退出。恢复模式把
Launch Command 临时设为 `/bin/sh` 可进入系统；不要重置文件系统。

`util/ish/ncurses-compat.c` 仅替代 ncurses 的两个安全文件访问入口，
真实/有效用户及组相同时直接执行原文件访问，身份不同时拒绝访问。
不伪造身份切换成功，不修改 libc、系统 Zsh 或 ncurses 包。

```sh
clang --target=i386-linux-musl -DISH_STANDALONE_BUILD -nostdlib \
  -shared -fPIC -fuse-ld=lld -O2 util/ish/ncurses-compat.c -o libncurses-compat.so
```

将库安装到 iSH 的
`${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/ish-compat/libncurses-compat.so`。
`ish_client_setup` 检测到库后链接 `~/.local/bin/zsh` 登录包装命令；
`set_default_shell` 会将旧 `/bin/zsh` 登录入口更新为该包装命令。
包装命令在 Zsh 初始化终端前加载库，并显式保留登录 Shell 语义；子进程继承它。
不使用系统级 `/etc/ld.so.preload`，其他平台不受影响。

iSH 的交互配置使用 `config/ish/zshrc`，保留公共环境和别名、基础提示符、
持久历史、Ctrl+R、方向键、Home/End/Delete 和本地覆盖配置。
不在启动时加载 Zinit、扫描 compinit 或下载插件，避免旧模拟器上的启动延迟和网络等待。
已安装的插件不删除；其他平台继续使用完整 Zinit 配置。

修复后应先验证带终端的 `/bin/login -f root`，再将 iSH 的 Launch Command
恢复为 `/bin/login -f root`。当前设备已通过独立交互 Shell 和真实登录验证。

## 能力范围

- 复用 Termux 的公共 basic 配置任务：zsh、Git、Vim、tmux、npm/pnpm 配置、
  所有公共工具链接和 agent 指令文件。交互 Shell 保留实测可用的轻量配置。
- 安装 Alpine x86 原生 Git、curl、fzf、fd、jq、zoxide 等终端工具。
  Alpine 此分支没有 diff-so-fancy 包，core 从上游安装该 Perl 工具到 XDG 数据目录，
  使用同名命令和 Git 分页器；保留公共别名和个人身份配置。
- 实际搜索/提示符测试中，Alpine 3.24 的 ripgrep 和 starship 触发非法指令，因此 iSH
  默认不安装它们；fzf 文件列表使用 find，提示符使用原生 zsh。fd 通过 `~/.local/bin/fd`
  使用单线程并关闭 jemalloc thread cache；仍可能打印 MADV_DONTNEED 提示，但文件搜索已验证。
  不要给 fd 显式增加工作线程。Termux 的这些工具与提示符保持原行为。
- Kerberos 使用 `krb5`，SSH 明确安装 `openssh-client-krb5`，不允许被普通客户端替代。
- 本地 tmux 使用与 Termux 相同的插件列表，包含 tmux-agent-workbench 和 fastcopy。
  Workbench 安装器下载 `i586-unknown-linux-musl` 静态发布包（避开此模拟器不支持的 SSE 指令），无需在模拟器里编译 Rust；
  安装后检查实际命令版本。`./init workbench` 可单独安装或修复。
- `agent-team` 通过公共安装任务安装到 `$XDG_DATA_HOME/agent-team`，
  `agent-team-install` 和更新器使用相同默认目录；`AGENT_TEAM_REPO` 可显式覆盖。
  需要启动具体 agent 时，该 agent 的 CLI 仍须在目标机器上可用。
- iSH 没有 Android API 或 Termux 服务管理。SSH 服务通过 `./init sshd` 配置，
  不调用 Android 的 `sv-enable`。剪贴板、打开链接及主题同步取决于终端能力。
- Machine Fabric 是独立服务，不是 tmux-agent-workbench。目前上游没有 i686 发布包，
  Linux 安装器要求 systemd，因此 iSH core 不安装该服务。
- 本地 Vim 保留需要 Node 的 coc 和需要 Go 的 hexokinase 的现有兼容排除。
  Alpine 3.24 的 ripgrep/starship、Python 和 ncurses 的已知问题见上文；
  不因这些问题排除可运行的公共工具或整个 workbench。

`ssh-connect`、`ish-doctor`、`kinit-auto-login` 安装到 `~/.local/bin`。默认配置为
`~/.config/ish-kerberos/{user.conf,krb5.conf}`，票据缓存为
`FILE:~/.cache/ish-kerberos/krb5cc`（环境变量中是展开后的绝对路径）。
初始化后的 ash/zsh 登录环境会自动设置相同的 `KRB5_CONFIG` 和 `KRB5CCNAME`，
因此手工 `kinit`、`klist` 与连接工具共用票据。

```sh
kinit yourname@YOUR.REALM
klist
ish-doctor
ssh-connect --workbench         # Workbench 客户端连接远端工作台
ssh-connect --tmux              # 需要时交互 kinit，然后进入/恢复远端 tmux
ssh-connect --check             # 非交互 GSSAPI 认证并执行 whoami
ish-doctor --ssh               # 包含真实 SSH 认证的诊断
```

普通 `ssh-connect` 打开远端 shell，`--tmux` 恢复 tmux，`--check` 非交互验证。
`./init sync` 和 `./init kerberos` 会把现有 `user.conf` 的主机、用户和端口同步为
标准 SSH 别名，并在 `$XDG_CONFIG_HOME/ssh/kerberos` 增加受管理的 Principal 映射，
因此可以使用 `ssh-connect --workbench`。已有显式 SSH 设置和手工映射优先；
Kerberos 配置和 keytab 保持原样。首次连接仍需核对主机指纹。
`./init sync` 也会移除旧的 dotfiles `ish-connect` 链接。
Termux 和其他平台也使用同一命令，按 [Termux 配置说明](termux.md#kerberos-ssh) 绑定主机和 Principal。
默认只在连接时检查票据；没有配置自动登录时，过期后仍需在 kinit 提示中输入密码。

### 可选：自动获取 Kerberos 票据

已完成 `./init kerberos` 后，可以启用同一套 `kinit-auto-login`：

```sh
./init sync
kinit-auto-login install
kinit-auto-login status
# 需要立即刷新时：
kinit-auto-login renew
```

iSH 会从现有 `ish-kerberos/user.conf` 读取 Principal，使用相同的 `KRB5_CONFIG`
和 `KRB5CCNAME`；显式设置的环境变量优先。首次缺少 keytab 时会交互生成并验证，
密码只在终端输入，保存的是权限为 600 的 keytab。已有有效 keytab 时直接复用。
生成的 keytab 默认位于 `$XDG_DATA_HOME/kinit-auto-login/`，日志和 PID 位于
`$XDG_STATE_HOME/kinit-auto-login/`，工具配置位于 `$XDG_CONFIG_HOME/kinit-auto-login/kinit.env`。

iSH 使用后台进程，每六小时获取一次票据，并在私有的
`$XDG_CONFIG_HOME/.zshrc.local` 写入幂等启动块；不修改仓库中的共享 `.zshrc`。
iPadOS 挂起 iSH 时后台工作也会暂停，重新进入登录 Shell 后会检查并恢复进程。
`ssh-connect --tmux` 在票据过期时也会先尝试 keytab 刷新。密码更改后运行
`kinit-auto-login gen-keytab` 重新生成；停用时运行 `kinit-auto-login uninstall`，
该命令保留 keytab。

SSH 默认只尝试 `gssapi-with-mic`，不委派 TGT、不回退到密码/公钥，不自动接受新主机公钥。
`ssh-connect --tmux` 还禁用连接复用，防止旧的已认证连接绕过检查。首次连接必须通过可信渠道
核对指纹。普通 `ssh` 的明确本地主机设置可写在 `~/.ssh/config` 的 dotfiles Include 之前；
`ssh-connect --tmux` 始终强制上述认证策略。

## iPad mini 4 操作

1. 安装 App Store 中兼容 iPadOS 15 的 iSH Shell，记录 App build。
2. 在 Settings → Filesystems 保留并导出原文件系统，作为回滚点。
3. 下载官方 **Alpine x86 Mini Root Filesystem**。当前候选为 3.24.3；
   3.18 仅作历史对照，不作为长期安全维护方案。用官方 SHA256 校验下载文件。
4. 将 `.tar.gz` 通过 AirDrop、获准使用的 Files 存储或电脑已有 SSH 连接传到 iPad。
   云端示例：`scp cloud-user@cloud-host:/path/to/alpine-minirootfs-x86.tar.gz .`。
5. Settings → Filesystems → Import，选择归档，命名 `dotfiles-test`，选择
   **Boot From This Filesystem** 后重新打开 iSH。不要删除原文件系统。
6. 检查 `cat /etc/alpine-release` 和 `apk --print-arch`（必须是 `x86`）。
   不要将旧版 repositories 改成新版再跨版本 `apk upgrade`。
7. 按本文开头的命令直接 clone 并初始化。如果需要通过 Files 传输源码，也可以使用
   `ish-dotfiles-bundle.tar.gz` 和配套校验文件；按下面命令导入，包内顶层为 `dotfiles/`。

```sh
mkdir -p /mnt/import "$HOME/.config"
mount -t ios . /mnt/import
# 在 Files 选择器里选择存放归档的文件夹
cd /mnt/import
sha256sum -c ish-dotfiles-bundle.sha256
tar -xzf ish-dotfiles-bundle.tar.gz -C "$HOME/.config"
cd "$HOME/.config/dotfiles"
umount /mnt/import
./init core
. ~/.profile
./init kerberos
exec zsh -l
```

首次初始化会启用已有 main 镜像的**同版本** community 仓库，并备份 repositories；
不会跨版本升级。默认 full core 比先前仅装 Kerberos 的包更大，需要网络、空间和等待时间。
已有 Git checkout 可通过 `git pull --ff-only` 更新，再执行 `./init sync` 同步配置；
需要更新依赖时运行 `./init core`。

官方参考：[文件系统导入](https://github.com/ish-app/ish/wiki/Install-&-Activate-Alternate-Filesystems)、
[Files 挂载](https://github.com/ish-app/ish/wiki/Mounting-other-file-providers)、
[键盘界面](https://github.com/ish-app/ish/wiki/User-Interface)。

## 企业配置、认证和后台恢复

仅在自己的 iPad 上填写真实参数，云端复现环境只使用 `ISH.TEST`。`./init kerberos`
会询问 Realm、Principal、KDC（`dns` 表示 SRV）、SSH 主机/用户/端口、tmux session。
如管理员提供完整配置，先运行交互向导填写连接信息，再通过 Files 导入正式 krb5.conf：

```sh
mkdir -p /mnt/import
mount -t ios . /mnt/import
umask 077
cp "$KRB5_CONFIG" "$KRB5_CONFIG.backup.$(date +%s)"
cp /mnt/import/krb5.conf "$KRB5_CONFIG"
chmod 600 "$KRB5_CONFIG"
umount /mnt/import
vi ~/.config/ish-kerberos/user.conf
kinit yourname@YOUR.REALM
klist
ssh-connect --tmux
```

只在 kinit 的提示中输入密码。确保 iPad VPN 能访问 KDC 和 SSH，开启自动日期时间。
普通 HTTP 代理不等于 Kerberos/SSH VPN。配置中的 KDC_HOST 仅用于诊断，实际 KDC
来自 krb5.conf；采用 DNS SRV 时可以删除 KDC_HOST。配置为 `KEY=value`，不加引号。

手工验证时在本机屏幕查看调试输出，避免将内部主机、账户和票据信息保存到公开日志：

```sh
ssh -vvv -F /dev/null -p 22 -l your-linux-user \
  -o GSSAPIAuthentication=yes -o GSSAPIDelegateCredentials=no \
  -o PreferredAuthentications=gssapi-with-mic \
  -o PubkeyAuthentication=no -o PasswordAuthentication=no \
  -o KbdInteractiveAuthentication=no -o HostbasedAuthentication=no \
  -o ControlMaster=no -o ControlPath=none -o StrictHostKeyChecking=yes \
  dev.your-domain.example whoami
```

应看到 `Authenticated to ... using "gssapi-with-mic"` 和正确用户名。端口连通不等于认证成功。
`ish-doctor` 用 PASS/FAIL/SKIP 区分结果；UDP 探测明确 SKIP，不能把 `nc -u` 成功当作 KDC 响应。

`ssh-connect --tmux` 执行远端 `tmux new-session -A -s dev`，会话名可配置。在远端运行 Codex。
默认 Ctrl+B 后按 `d` 分离；再次连接恢复同名会话。使用远端实际配置的 tmux 前缀。
iSH 附加键行提供 Ctrl、Esc、Tab 和方向键；Esc 也可用 Ctrl+`[`。
切换 App 或锁屏可能导致 SSH 断开；远端 tmux 保留工作，回来重新运行 `ssh-connect --tmux`。
SSH 卡住时可在行首输入 `~.` 断开；过期票据会重新请求交互 kinit。

回滚时在 Filesystems 选择原 rootfs 启动。不要通过卸载 iSH 回滚，以免删除其他文件系统。

| 手工验收 | 当前状态 |
| --- | --- |
| iPad mini 4 / iPadOS 15 安装、导入、回滚 | NOT TESTED |
| `./init core` 完成、重复运行 | PASS（见下方 iPad 实机记录） |
| zsh 首次交互启动性能、终端操作体验 | NOT TESTED |
| `./init sync` 保留企业配置与主机指纹 | NOT TESTED |
| 企业 VPN、交互 kinit、TGT Principal/有效期 | NOT TESTED |
| 主机指纹核对、GSSAPI SSH、远端用户名正确 | NOT TESTED |
| tmux 分离/恢复、Codex 在远端 | NOT TESTED |
| Ctrl/Esc/Tab/粘贴/外接键盘 | NOT TESTED |
| 切换 App 30 秒/2 分钟及锁屏后恢复 | NOT TESTED |

## 开发验证与复现环境

仓库只保留公共初始化的轻量回归测试。Docker KDC、SSH 服务端、iSH 编译、rootfs
打包、多版本复现与生成产物存放在仓库外的 `~/.local/share/repro-environments/ish-kerberos/`，
不属于这次 dotfiles 提交内容。旧独立安装包保留作为先前测试快照，不能视为新 `./init core` 的交付包。

```sh
python3 -B -m unittest discover -s tests -v
./init --dry-run --json --platform ish core
```

先前的最小客户端在 Docker 与真实 iSH CLI 的 3.18/3.22/3.23/3.24 上完成过 GSSAPI 测试。
新增公共初始化、shell 和插件的验收结果单独记录在外部复现环境，不能沿用旧包的 PASS。

本次 Alpine 3.24 CLI 验证：两次 `core`、一次 `sync` 与配置保留通过；Docker 与真实
iSH 各 15 项 Kerberos/GSSAPI 用例通过；fd 搜索、fzf、zoxide、Vim、tmux 和 zsh
启动检查通过。完整初始化/插件运行使用了官方包及公开插件缓存；全新在线获取插件
曾超时或停滞，尚未获得一次完整通过记录。此处为此前公共初始化的验证记录；共享连接入口的新增验证见下方。
以上为 Linux 主机上的 CLI 验证，iPad 实机的新记录见下方。此前证据见外部环境的 `docs/DOTFILES_REPORT.md`。

共享 `ssh-connect` 验证（2026-10-24）：

- **PASS**：仓库回归 146 项，138 通过、8 项平台跳过；POSIX 语法、ShellCheck、两平台 sync dry-run。
- **PASS**：Docker Alpine 3.24.3 x86 与真实 iSH CLI 各 17 项 Kerberos/GSSAPI 用例。
  两层均有客户端 `using "gssapi-with-mic"`、远端 `whoami` 和 SSH 服务端认证日志。
  新共享别名映射和旧 iSH 配置均通过；故意开启密码/公钥/委派的配置无法覆盖连接策略。
- **PASS**：14 项共享入口回归包含 PTY 交互取票、重新校验身份、普通 SSH 与 workbench 交接。
  这些是命令替身测试；不代表 Android 上实际运行过 workbench。
- **NOT TESTED**：企业 KDC 的 iPad 实机认证、workbench 完整远端交互；需按设备指南验收。

复现环境继续留在仓库外，没有提交 Docker、KDC、keytab、rootfs 或测试日志。

### iPad mini 4 实机初始化验收（2026-10-24）

- App Store iSH 1.3.2 (494)，Alpine 3.24.3 x86；使用上述独立 Python 3.12.15
  和仅供 APK 使用的权限兼容库，保留系统 Python 3.14.8 和系统软件源。
- `./init core` 完整通过，任务阶段 818.4 秒；基础软件、zinit、tmux 和 Vim 插件安装完成。
- 完整重跑通过，任务阶段 243.2 秒，包含解释器启动的总耗时 311 秒；已安装的
  系统包跳过索引更新和安装。插件检查及老设备模拟执行仍需时间，重跑并非瞬时完成。
- 重跑前后 `.profile`、`.zshenv`、SSH 配置、Kerberos 两份配置、Git 配置的 SHA-256
  相同，SSH 服务 PID 保持不变。
- Python、Git、zsh、tmux、Vim、fzf、zoxide、Kerberos 命令执行通过；fd 单线程实际
  找到 `bootstrap/main.py`，SSH 接受 `GSSAPIAuthentication=yes`；27 个 Vim 插件无缺失。
- 隔离 tmux 服务器加载公共配置，并确认排除 iSH 不适用的 workbench/fastcopy 插件。
  测试服务器已退出；关闭后的 socket 状态查询客户端在 iSH 内出现不可中断等待，
  SIGKILL 也未立即清除该进程。它不是仍在运行的测试会话，不据此宣称进程清理全部通过。
- 仓库回归 184 项通过（15 项平台条件跳过），POSIX shell 语法和 ShellCheck 通过。
  C 兼容层的真实文件权限、目录 FD、符号链接拒绝及无效标志检查通过。
- 企业账号配置、真实 TGT 和企业 SSH 登录仍需用户的环境，未在这次本机初始化验收中测试。

Git LFS 历史迁移后的普通 clone、一键迁移和真实 iSH sync/pull 验证见 [LFS 测试报告](../LFS_TEST_REPORT.md)。

## 从局域网电脑连接 iSH（可选）

`./init sshd` 和 `./init pair` 直接转发到原生交互工具，不依赖 Python，
可在初始化之前运行。使用 `./init sshd --help`、`./init pair --help` 查看选项。
默认初始化仍不启动 SSH 服务。
在 iPad 的 iSH 中，进入仓库执行：

```sh
cd ~/.config/dotfiles
git -c core.hooksPath=/dev/null pull --ff-only
./init sshd
```

默认端口 2222，复用 iSH root 的已有密码；账号未设置可用密码时交互运行
`passwd root`。它与 iPad 解锁密码无关。`--set-password` 主动重设密码；
`--random-password` 确认后替换为随机密码，只允许在终端显示，不保存到日志或文件。
修改密码会影响该 iSH 用户的其他密码登录，不能通过恢复 SSH 配置撤销。
服务使用独立配置，不修改 `/etc/ssh/sshd_config`。默认一次完成 OpenRC 安装、
自启动注册和当次后台启动，完成后返回终端。首次安装会初始化 OpenRC 的 default
运行级别。不要将密码、私钥或完整认证日志发到公开渠道。
重跑时会跳过已安装的软件及已有的自启动注册；服务配置和脚本未变化且进程健康时，
不会重启服务或创建新备份。配置变化才备份并重启，服务停止时则重新启动。
普通重跑会保留已有的仅密钥登录设置；需要重新开启密码登录时显式使用
`./init sshd --set-password`。
配对提示尽量显示实际 IPv4：通过 SSH 运行时使用本次连接的服务端地址，
本地运行时尝试用 Python 查询 UDP 路由选用的地址（不发送数据，不依赖 DNS，
最多等待 3 秒）。iSH 上 `ip`/`ifconfig` 可能不可用，Python 不可用或检测失败时
明确提示手动查询；VPN 也可能影响路由检测所得的地址。

从旧版前台服务迁移时，先在原窗口按 Ctrl-C，避免两个服务争用 2222：

```sh
# 默认：安装、启用并启动 OpenRC 服务。
./init sshd

# 可选：前台排错（先停止已有服务）。
./init sshd --foreground

# 可选：只启动后台进程，不注册自启动。
./init sshd --background
```

自启动模式将配置保存到 `/etc/ssh/sshd_config.dotfiles`，使用独立服务
`dotfiles-sshd`，不接管系统原有的 `sshd` 服务。配置或服务脚本变化时会重启服务，
应从 iSH 本地终端执行这些变更。
服务直接启动 sshd，通过 PID 文件管理进程，避免 iSH 上 OpenRC 默认
`start-stop-daemon` 启动失败；启动时会等待 PID 文件就绪。服务日志默认位于
`/root/.local/state/dotfiles/sshd/service.log`（OpenRC 环境设置了 `XDG_STATE_HOME`
时使用该目录）。启动失败会显示最近的服务日志。
不要同时启用系统的 `sshd` 服务占用同一端口。
如果首次安装 OpenRC 后立即启动失败，完全关闭并重新打开 iSH，再检查：

```sh
rc-service dotfiles-sshd status
rc-service dotfiles-sshd start
```

停止或取消自启动分别使用：

```sh
rc-service dotfiles-sshd stop
rc-update del dotfiles-sshd default
```

已配对且不再需要密码登录时，可用 `./init sshd --key-only` 更新并重启服务。
`--foreground` 和 `--background` 不更新已安装的 OpenRC 服务；后台进程日志位于
`${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/sshd/sshd.log`。
这里的自启动指 iSH 虚拟环境启动，不是 iPad 开机后自动运行应用；
后台 sshd 不会绕过 iPadOS 的应用挂起限制。
连接断开时先区分服务与地址：在 iSH 前台运行 `rc-service dotfiles-sshd status`，
再用 `./init sshd` 查看当前 IP。Wi-Fi 与 VPN 切换后旧地址可能不再可达。
`ssh-first-reachable` 只给地址探测设置短超时，建立后的 SSH 通道不使用
Netcat 空闲超时；连接建立期限由 OpenSSH 的 `ConnectTimeout` 管理。

在 iPad「设置 → Wi-Fi → 当前网络」找到 IP（下例替换为实际地址）。
同一局域网电脑进入自己的 dotfiles 仓库后执行：

```sh
git -c core.hooksPath=/dev/null pull --ff-only
./init pair ipad-ish 192.168.1.50
ssh ipad-ish
```

电脑需安装 `ssh`、`ssh-copy-id`。配对复用默认密钥
`~/.ssh/id_ed25519` 及其 `.pub` 文件，不生成客户端密钥。缺少或不完整时立即停止；
先通过 `./init ssh-keys` 设置密钥，再重新配对。已有私钥缺少公钥时应先恢复公钥，
不要覆盖已有私钥。首次连接必须对照 iSH 上显示的
ED25519 指纹，核对后接受，再输入 iSH 的 root 密码。
若给私钥设置了口令，先在电脑的 ssh-agent 中加载它：

```sh
ssh-add ~/.ssh/id_ed25519
# 然后重新执行 ssh-pair；它不会重新生成已有密钥。
```

公钥复制后，必须通过真实、非交互、公钥认证才能保存别名。该验证禁止密码回退和
连接复用。电脑的 `~/.ssh/config` 在修改前备份到同目录的
`config.before-pair.*`；新别名放在已有默认项之前，原内容保留。重复执行同一配对
不会重复写配置，同名别名指向不同目标时拒绝覆盖。失败后可能已复制公钥，但不会
报告配对成功。主机密钥变化时应独立核验，脚本不会删除 known_hosts 或自动信任。
完成 `./init sync` 后可以直接运行 `ssh-setup`、`ssh-pair`。

配对不会自动关闭密码登录，方便其他电脑继续配对。按需关闭时，确认已有电脑能登录，
然后在 iPad 本地终端改为只允许密钥：

```sh
./init sshd --key-only
```

保留 iSH 在前台且 iPad 不锁屏。后台挂起、锁屏及 Wi-Fi 地址变化都可能使连接中断；
重新打开 iSH、重启服务器即可，配对密钥仍然保留。需要添加新的电脑时，可按需
用 `./init sshd --set-password` 恢复密码登录，完成新增配对后再选择是否改回 `--key-only`。
Wi-Fi 开启客户端隔离时，同一网络的设备也可能无法互访。云开发机无法直接访问此内网地址，需另行建立反向隧道。
当前实现面向 Alpine/iSH 设备端及 POSIX 连接端；不包含 Docker 或 Windows 原生配对。
