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
| `./init --list-tasks` | 查看公共任务 |
| `./init --dry-run --json --platform ish core` | 在其他机器预览，无安装和文件修改 |

日志沿用 `$XDG_STATE_HOME/dotfiles/bootstrap/` 的 `output.log` 和 `results.json`。
重复初始化保留 Kerberos 配置、SSH 本地内容和主机指纹。更新已有启动文件时保留原内容并备份。
`kerberos` 明确确认后才备份并替换配置；管理员配置可以直接导入。

## 能力范围

- 复用公共 zsh / zinit、Git 别名、Vim 配置、tmux 配置和键位。
- 安装 Alpine x86 原生 Git、curl、fzf、fd、jq、zoxide 等终端工具。
  Alpine 此分支没有 diff-so-fancy，Git 分页使用 less，保留公共别名和个人身份配置。
- 实际搜索/提示符测试中，Alpine 3.24 的 ripgrep 和 starship 触发非法指令，因此 iSH
  默认不安装它们；fzf 文件列表使用 find，提示符使用原生 zsh。fd 通过 `~/.local/bin/fd`
  使用单线程并关闭 jemalloc thread cache；仍可能打印 MADV_DONTNEED 提示，但文件搜索已验证。
  不要给 fd 显式增加工作线程。Termux 的这些工具与提示符保持原行为。
- Kerberos 使用 `krb5`，SSH 明确安装 `openssh-client-krb5`，不允许被普通客户端替代。
- iSH 本地 tmux 保留公共插件，排除本地 agent workbench 和需要额外原生二进制的 fastcopy；
  本地 Vim 不安装需要 Node 的 coc 或需要 Go 编译的 hexokinase。
  剪贴板、打开链接及终端主题自动同步还取决于 iSH 的终端能力，需实机验收。
- iSH 没有 Android API、Termux:API/服务管理。本客户端不启动本地 sshd/ssh-agent，
  不安装本地 Codex、agent-team 或 Machine Fabric；开发工具和完整工作台运行在远端。
- 公共 zsh 插件首启可能继续下载；云端通过不代表 iPad mini 4 的启动速度可接受。

`ssh-connect`、`ish-doctor` 安装到 `~/.local/bin`。默认配置为
`~/.config/ish-kerberos/{user.conf,krb5.conf}`，票据缓存为
`FILE:~/.cache/ish-kerberos/krb5cc`（环境变量中是展开后的绝对路径）。
初始化后的 ash/zsh 登录环境会自动设置相同的 `KRB5_CONFIG` 和 `KRB5CCNAME`，
因此手工 `kinit`、`klist` 与连接工具共用票据。

```sh
kinit yourname@YOUR.REALM
klist
ish-doctor
ssh-connect --tmux              # 需要时交互 kinit，然后进入/恢复远端 tmux
ssh-connect --check             # 非交互 GSSAPI 认证并执行 whoami
ish-doctor --ssh               # 包含真实 SSH 认证的诊断
```

普通 `ssh-connect` 打开远端 shell，`--tmux` 恢复 tmux，`--check` 非交互验证。
已有 `user.conf` 无需迁移；`./init sync` 会移除旧的 dotfiles `ish-connect` 链接。
Termux 和其他平台也使用同一命令，按 [Termux 配置说明](termux.md#kerberos-ssh) 绑定主机和 Principal。
只在连接时检查票据；过期后仍需在 kinit 提示中输入密码，没有后台续票或密码保存。

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
| `./init core` 完成、重复运行、zsh 首启性能 | NOT TESTED |
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
iPad 实机仍为 NOT TESTED。完整证据见外部环境的 `docs/DOTFILES_REPORT.md`。

共享 `ssh-connect` 验证（2026-10-24）：

- **PASS**：仓库回归 146 项，138 通过、8 项平台跳过；POSIX 语法、ShellCheck、两平台 sync dry-run。
- **PASS**：Docker Alpine 3.24.3 x86 与真实 iSH CLI 各 17 项 Kerberos/GSSAPI 用例。
  两层均有客户端 `using "gssapi-with-mic"`、远端 `whoami` 和 SSH 服务端认证日志。
  新共享别名映射和旧 iSH 配置均通过；故意开启密码/公钥/委派的配置无法覆盖连接策略。
- **PASS**：14 项共享入口回归包含 PTY 交互取票、重新校验身份、普通 SSH 与 workbench 交接。
  这些是命令替身测试；不代表 Android 上实际运行过 workbench。
- **NOT TESTED**：Termux 与 iPad 实机、workbench 完整远端交互；需按设备指南验收。

复现环境继续留在仓库外，没有提交 Docker、KDC、keytab、rootfs 或测试日志。

Git LFS 历史迁移后的普通 clone、一键迁移和真实 iSH sync/pull 验证见 [LFS 测试报告](../LFS_TEST_REPORT.md)。
