[Hammerspoon](http://www.hammerspoon.org/)
====

[Mac神器hammerspoon](http://seanxp.com/2016/mac-hammerspoon/)

## 图片同步入口

菜单栏 **图片同步** 或 **Ctrl+Option+Shift+V** 打开原生菜单，方向键/鼠标选择、Enter 执行、Esc 关闭。
不再使用 chooser 搜索弹窗，因此没有 Cmd+数字提示或绑定。
只保留三个动作：发送已有剪贴板图片、选择同步目标、查看上次同步结果。
Ctrl+Option+V 直接发送当前剪贴板图片，不必打开菜单。原 Ctrl+Option+C、Ctrl+Option+Z 和 Ctrl+Option+/ 已释放。

Hyper 键位现在由 [共享配置](../../hyper/README.md) 统一管理。
菜单内搜索框为空时，Backspace 返回上一级；有文字时正常删除，顶层不退出，Esc 关闭整个面板。
Q/W 分别是个人与工作浏览器：H+Q/H+Shift+Q 为 Firefox/Safari，H+W/H+Shift+W 为 Edge/Chrome。
H+E/H+Shift+E 为 Sublime Text/VS Code，H+A/H+S 为 ChatGPT/豆包，
H+D/H+Shift+D 为 Dictionary/DevDocs，H+Z 为 Finder，H+X/H+Shift+X 为 Feishu/Feishu Meetings，
H+C/H+Shift+C 为微信/Telegram。剪贴板历史统一使用 H+3，原 H+Shift+V 的剪贴板工具菜单移到 H+0 → C。
数字行恢复为 H+1 窗口搜索、2 应用搜索、3 剪贴板历史、4 区域截图、5 录屏入口，
6 音频输出、7 麦克风、0 Hyper 配置；Shift+数字释放，H+8/9 也释放。
H+0 → S/V/D/F/X 分别为截图、录屏、显示器设置、专注设置和系统菜单；H+3 首次使用需确认开启内存文本历史。
横屏 H+左右方向键贴左/右半屏，半屏接 H+上/下进入对应上/下角 1/4；普通窗口 H+上最大化，H+下最小化，
H+上优先恢复最近由 Hyper 最小化的窗口。H+Shift+上循环左/右 2/3，
H+Shift+下按右→中→左循环 1/3；H+Backspace 撤销，H+Shift+左右跨屏。
竖屏按当前屏幕可用区域高度大于宽度自动识别：H+左右改为上/下半屏，
H+Shift+上循环上/下 2/3，H+Shift+下循环下/中/上 1/3。
竖屏 H+上/下保留最大化、恢复和最小化，不触发横屏的半屏/四分屏转换；切屏按键不变。
H+分号切换主终端，H+Shift+分号切换副终端；Enter 和 backtick 两组终端绑定已移除。
H+Home/End 居中/最大化恢复，H+PageUp/PageDown 保留为完整键盘的固定上下半屏补充入口；这四键加 Shift 后按左/右/上/下聚焦窗口。
H+Shift+Space 系统全屏；H+方括号减小/增加宽度，加 Shift 调高度，均不弹菜单。
Hammerspoon 独占 Hyper 窗口动作；首次迁移需执行共享配置中的 Rectangle 迁移脚本。
H+Space 搜索，H+/ 速查；窗口菜单、旧分号分屏和单引号入口已取消，应用键再次按下仍隐藏应用。
H+Shift+/ 或 H+0 后按 A 配置应用角色，显示当前应用与快捷键，选择后立即保存生效，也可恢复默认。
无快捷键的角色可从 H+Space 搜索执行；修改角色配置立即影响该角色动作，固定应用直达键保持不变。
配置候选包含已安装应用的缓存索引。旧 chat 偏好迁移为 workChat，不影响 dailyChat。
H+R 为 Windows App，H+Shift+R 为 Reeder，H+Shift+N 为 NoMachine。
菜单随系统首选语言显示中文或英文，重载后更新；中英文功能名都能搜索。
Hyper 为 Ctrl+Option+Command。保留远程桌面的 Karabiner 自动切换和图片同步入口。

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
