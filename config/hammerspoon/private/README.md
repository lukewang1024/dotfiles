[Hammerspoon](http://www.hammerspoon.org/)
====

[Mac神器hammerspoon](http://seanxp.com/2016/mac-hammerspoon/)

## 图片同步入口

菜单栏 **图片同步** 或 **Ctrl+Option+Shift+V** 打开原生菜单，方向键/鼠标选择、Enter 执行、Esc 关闭。
不再使用 chooser 搜索弹窗，因此没有 Cmd+数字提示或绑定。
只保留三个动作：发送已有剪贴板图片、选择同步目标、查看上次同步结果。
Ctrl+Option+V 直接发送当前剪贴板图片，不必打开菜单。原 Ctrl+Option+C、Ctrl+Option+Z 和 Ctrl+Option+/ 已释放。

窗口分屏只用快捷键，沿用 Rectangle 配置：Hyper+方向键为上下左右半屏，
Hyper+Return 最大化；Hyper+Shift+左右跨屏，上为左侧三分之二，下为右侧三分之一。
Rectangle 运行时不重复注册；退出后 Hammerspoon 自动接管，重新启动则让出。
Hyper 为 Ctrl+Option+Command。保留 Hyper 应用切换、导航、既有录屏快捷键和
远程桌面的 Karabiner 自动切换。窗口、控制台、重载、功能管理不再放进列表。
功能开关仍保存在 `workbench.toolbox.features` 设置中。

新入口不加载旧 ModalMgr、appM、ClipShow、HSearch、KSheet、时钟和倒计时面板。

安装由 `bootstrap/macos.sh` 配置：将本目录上一级的 `init.lua` 链接到
`$XDG_CONFIG_HOME/hammerspoon/init.lua` 和 `workbench-init.lua`，并把 Hammerspoon 的
`MJConfigFile` 指向此路径。首次切换后使用 Hammerspoon 菜单 Reload Config。
本机迁移前的旧入口备份在 `$XDG_CONFIG_HOME/hammerspoon/legacy-init.lua`。
两种入口路径均指向新配置，避免运行中的 Hammerspoon 重载缓存的旧路径。无需依赖旧 awesome-hammerspoon 启动器或 Spoons。

## Workbench 图片同步

`modules/workbench-clipboard.lua` 通过 distributed-workbench CLI 获取已连接的远端节点；
菜单每 30 秒刷新节点元数据，不读取或监听剪贴板。选择目标后按 `Ctrl+Option+V`
（不含 Command，不使用 Hyper/HyperAlt），直接发送当前剪贴板中的图片。
不会模拟 Cmd-C，也不要求剪贴板刚刚发生更新；截图或复制图片后都可以发送。
`Ctrl+Option+Shift+V` 打开同步菜单，用于选择目标、发送图片和查看状态。
只有远端确认写入才提示成功；无图片、节点未就绪、断线或超时会显示原因，不自动重试或改发其他设备。
文本仍通过终端正常粘贴。

依赖支持 `workbench clipboard targets --json` 和 `clipboard push --target ID --image-only --json`
的版本。默认 CLI 路径为 `~/.local/bin/workbench`；开发调试可设置
`hs.settings.set('workbench.clipboard.binary', '/absolute/path/to/workbench')` 后重载配置。
清除该设置即可恢复默认路径。节点尚未安装图片支持时会置灰。
Linux 的 dotfiles `codex` shell 函数会在检测到托管 `clipboard-env` 时自动通过
`workbench clipboard exec` 启动，确保连接到同一个 DISPLAY/XAUTHORITY。已有终端需重新加载
`config/zsh/agent-resume-history.zsh`，并退出后重新启动 Codex；也可显式运行
`workbench clipboard exec -- codex resume`。之后 Ctrl-V 使用原生图片粘贴。

运行逻辑测试：

```sh
luajit config/hammerspoon/private/tests/workbench-clipboard.lua
luajit config/hammerspoon/private/tests/toolbox.lua
luajit config/hammerspoon/private/tests/window-shortcuts.lua
```
