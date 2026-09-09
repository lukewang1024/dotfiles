# Hammerspoon 面板迭代结果（2026-09-09）

旧配置的主要问题是入口过多、模式退出不完整、相同能力存在多套快捷键，以及弹窗重载后残留。
最终配置使用独立入口，不再加载旧 awesome-hammerspoon 的模式管理器和 Spoons。

## 最终交互

- Ctrl+Alt+V 发送当前剪贴板图片，不模拟复制，不要求内容刚刚更新。
- Ctrl+Alt+Shift+V 打开原生图片同步菜单：发送、目标选择、上次结果。
- 目标来自 distributed-workbench 已连接节点，不可用节点显示原因；失败不自动重试或改发。
- 原生菜单支持 Esc 退出，不使用 chooser 或 Cmd+数字快捷键。
- Hyper 应用切换、录屏和 Karabiner 远程桌面切换保留。
- 窗口分屏使用原 Rectangle 快捷键；Rectangle 运行时让出，退出后自动接管。
- 旧时钟、倒计时、搜索、帮助和模式面板不加载。旧配置文件仅留作历史参考。

## 验证与部署

三个 Lua 测试覆盖同步状态、错误与超时、目标选择、菜单清理及窗口快捷键接管。
本机已重载新配置。distributed-workbench v0.6.48 / workbench-config v1.0.237
已部署，两个 Linux 目标的图片写入和 X11 图片读取已验证。
Windows 服务会话尚不支持交互剪贴板，因此目标保持禁用并显示原因。

Linux 普通 codex 启动函数会自动接入托管剪贴板环境；已有进程需要退出后重新启动。
快捷键和安装说明以 `config/hammerspoon/private/README.md` 为准。
