# Git LFS history migration

2026-10-24：Rime 大型资源迁入 Git LFS，原路径保持不变。范围为字体 `.ttf`、
语言模型 `.gram` 和 512 KiB 以上的第三方词库，共 18 个当前文件、153,243,563 字节。
小配置、自定义短语和小词典仍使用普通 Git。

## 已有设备：一个命令

从旧 checkout 或任意其他目录执行：

```sh
curl -fsSL https://raw.githubusercontent.com/lukewang1024/dotfiles/main/util/dotfiles/migrate-lfs | sh
```

默认选择当前目录中的 dotfiles checkout，否则使用
`${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles`。自定义位置：

```sh
curl -fsSL https://raw.githubusercontent.com/lukewang1024/dotfiles/main/util/dotfiles/migrate-lfs |
  sh -s -- --repo /absolute/path/to/dotfiles
```

需要 Python 3.10+ 和 Git。也可以下载并检查脚本，再用 `sh /path/to/migrate-lfs` 执行。
原生 Windows PowerShell（已安装 Python 3.10+）：

```powershell
& ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/lukewang1024/dotfiles/main/util/dotfiles/migrate-lfs.ps1').Content))
```

Windows 包装器使用同一份 Python 迁移实现，并通过 `init.ps1 sync` 更新配置。
Windows 包装器尚未实机验证；POSIX/Linux 和 iSH 的执行结果见测试报告。

脚本依次执行：

1. 检查 main 分支、未提交/未跟踪文件，以及是否存在 linked worktree。
2. 在同一父目录暂存新 checkout，保持 LFS 资源为指针。
3. 根据公开提交映射检查所有本地分支，拒绝丢弃未发布提交；保留可映射的本地分支。
4. 保留 Git 忽略的本机文件（含权限、文件符号链接），出现路径冲突时停止。
5. 再检查一次并发修改，把原目录整体重命名为 `dotfiles.before-lfs.<timestamp>.<suffix>`。
6. 将新 checkout 放回原路径，执行 `./init sync`。已有 Rime 配置指向本仓库时，再获取并验证资源。
7. 同步失败时恢复原 checkout。初始化产生的独立配置备份和日志仍按公共初始化器规则保留。

以 `PASS migrated checkout is ready` 为迁移完成依据。失败时保留错误输出；不要用
`reset --hard` 或删除旧目录跳过检查。多 worktree、未发布提交或本地修改需要先整理，
脚本不会替用户决定如何提交、删除或合并这些工作。

重复运行会识别已迁移的 checkout，不会重复备份/重建。检查而不替换用 `--check`；
只替换、稍后同步用 `--skip-sync`。

## 新设备与日常使用

```sh
git clone https://github.com/lukewang1024/dotfiles.git "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
cd "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
./init core
```

`.lfsconfig` 中的 `lfs.fetchexclude = *` 默认避免 smudge 下载，即使机器已经配置了
Git LFS 过滤器。普通 iSH/Termux checkout 和初始化不需要 git-lfs。
桌面 Rime 初始化会安装所需 git-lfs，显式 pull `config/Rime/**` 并清空本次下载的
exclude 选项，然后按 `config/Rime/lfs-manifest.json` 验证内容。资源未完整下载时不会
继续建立 Rime 配置链接；本地已修改的资源也不会被悄悄覆盖。

手动获取：

```sh
./init run maintenance rime_assets
```

资源齐全并校验通过后，重复任务不联网。Windows `sync` 若首次需要 Rime 资源，
也会完成这一步；其他同步行为沿用公共初始化流程。

修改大资源时，更新 manifest 中的 `size` 和 `sha256`，保留 `.gitattributes` 的匹配。
仓库使用自有 `core.hooksPath`，因此新增的 `util/git/hooks/pre-push` 会调用
`git lfs pre-push`，保证先上传资源再发布 Git 提交。推送者需要 git-lfs。
已有稀疏 checkout 仍可继续使用；迁移脚本创建的普通 checkout 无需稀疏设置。

## 历史与回滚

公开的 `main` 和 `wip` 历史均已转换。旧到新提交的映射在
`config/git/lfs-commit-map.csv`，迁移标记在 `config/git/lfs-migration.json`。
改写前已备份远端完整镜像/bundle、本机所有分支和 worktree 的本地修改；这些备份
留在实施机器的 XDG 数据目录中，具体位置和验证结果见实施报告。

旧历史的普通 `git pull --ff-only` 无法跨越这次改写；请使用上面的一键迁移。
旧 checkout 的完整备份保留原提交和 `.git/config`，可以作为回滚和找回本地设置的依据。
自动迁移只重建与当前仓库配套的配置；其他本机应用状态不属于 Git 历史迁移。

GitHub 仍可能保留旧 Pull Request 的只读引用和缓存；这次迁移清理的是可写公开分支的
Git 下载历史，不声称删除 GitHub 的所有旧对象。改写后的普通 clone 不会抓取旧 PR 引用。
