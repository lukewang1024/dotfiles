# Termux SSH 指纹解锁

[English](README.md) | 简体中文

Android 11+ 的单口令应用。现有 SSH 私钥及其口令不变。
应用使用 Android Keystore AES-256-GCM，每次加解密均通过 BiometricPrompt CryptoObject 认证。
密文和 IV 保存在应用私有存储，禁止备份；口令不会写入 Termux 文件、参数、日志或剪贴板。
Keystore 是否由安全硬件支持取决于手机，不能仅凭 API 保证。

## 可选安装

在 dotfiles 仓库运行 `./init ssh-biometric` 安装依赖、构建 APK 并链接命令。
它不属于默认 core 安装。命令会自动打开 Android 安装界面，只需在手机上确认。
源码、固定 SDK、签名身份和 APK 校验均未变时复用已有 APK，不再下载或编译；
源码或签名变更、缓存损坏时重新构建。仅改文档和命令脚本不会重建 APK。

## 首次使用

已有 dotfiles 的另一台手机可参考[更新和场景验证步骤](../../docs/termux-ssh-biometric-testing.md)。

1. 运行 `./init ssh-biometric`，在自动打开的 Android 安装界面确认。
2. 打开「SSH 指纹解锁」，输入 SSH 私钥口令，按指纹保存。应用随后自动关闭。
3. 在已有 ssh-agent 的终端运行 `ssh-add-biometric /实际路径/私钥`。
   不传参数时识别并加载 `~/.ssh` 目录下全部私钥（包括自定义名称），排除公钥和配置文件，可传 `-t 1h` 等 ssh-add 参数。
4. 首次请求核对应用与终端显示的证书 SHA-256 指纹，完全一致才确认。
5. 按指纹后，以 `ssh-add -l` 检查是否加入成功。

如当前终端没有 agent，可先执行 `eval "$(ssh-agent -s)"`。应优先复用现有 agent。
密钥加入后的使用由 ssh-agent 管理；锁屏和退出本应用不会自动移除密钥。
使用 `ssh-add -d /实际路径/私钥` 移除该密钥。

应用未安装、尚未保存口令或取消认证时，命令会给出对应提示。
保存的口令与密钥不匹配时会停止该密钥的指纹重试，避免反复弹窗。

## 通信与生命周期

SSH_ASKPASS helper 仅监听 127.0.0.1 的随机端口，以 TLS 加密连接。
Termux 的传输私钥保存在 XDG_STATE_HOME/termux-biometric-ssh/transport-key.pem（权限 0600）。
首次连接时应用要求用户核对终端显示的 SHA-256 证书指纹，再将其固定。
后续连接必须匹配固定证书，TLS 握手证明 Termux 持有对应私钥。
应用另需发送本次请求的 192 位随机令牌；服务器拒绝不匹配的连接。
不使用跨应用 Unix socket、剪贴板或明文口令临时文件。
应用增加 INTERNET 权限以访问本机回环连接，源码只连接 127.0.0.1。
Termux UID 下的其他进程属于同一信任边界；勿直接运行 askpass helper，否则口令会输出到终端。
首次配对的身份验证依赖用户核对指纹，勿接受非自己发起的请求。
升级时覆盖安装 APK，不要卸载；签名和 Keystore 别名保持不变。
删除已保存口令也会清除固定证书；传输身份丢失后需核对并重新配对。

## 恢复与删除

请在 KeePassDX 中保留原口令。卸载应用、清空应用数据、某些锁屏设置变更或增加指纹
可能使 Keystore 密钥失效。此时重新打开应用，删除保存的口令后重新录入。
原 SSH 私钥及 KeePassDX 中的口令不受影响。

## 构建与验证

Termux 依赖：openjdk-21、aapt、d8、apksigner、zip、python、python-cryptography、openssh。
`~/.cache/termux-biometric-ssh/android.jar.b64` 来自 AOSP prebuilts/sdk 的 固定提交 3af7c93524be6f51e092b87b17f009f13ee98b43 的 35/public/android.jar（format=TEXT），安装器验证 SHA-256。
运行 `./build.sh` 构建和验证签名。应用签名密钥位于
`~/.local/state/termux-biometric-ssh/signing.p12`，应保留以便升级。
`python test_bridge.py` 检查真实 TLS 传输、错误令牌、证书指纹不匹配、取消、截断、异常长度和身份持久化；真实指纹与 ssh-agent 链路需手机实测。

卸载命令：删除 `~/.local/bin/ssh-add-biometric` 和 `~/.local/bin/termux-biometric-askpass`
两个符号链接，并从 Android 卸载本应用。源代码和构建缓存可按需删除。

## RC 集成

本机 dotfiles 的 `config/sh/ssh-agent-connect.sh` 已接入：检测到 Termux 且
`~/.local/bin/ssh-add-biometric` 可用时，`addKeys` 先说明用途，等待回车才用它加载尚未加入的密钥；按 Esc 立即改用普通 SSH 口令输入。
输入其他内容后回车也会选择口令输入。指纹失败或取消后自动回退到普通 ssh-add；
Ctrl-C 或 Ctrl-D 结束这次启动加载，选择结束后恢复终端输入设置。
非交互 shell 不触发指纹认证。
现有 zsh prepare 流程在 tmux 外调用 `connectSSHAgent`，继续复用稳定 socket。
密钥已齐时不弹认证，SSH agent 转发会沿用原有跳过本机加载的规则。
新终端自动生效，当前终端可运行 `ssh-agent-connect` 重新加载连接脚本。

界面和终端提示跟随 Android 系统语言：中文系统显示中文，其余或读取失败时默认英文，不受 Termux `LANG` 影响。更新后运行 `./init ssh-biometric` 安装新版应用。
