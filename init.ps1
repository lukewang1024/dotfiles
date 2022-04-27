function prepare_windows_env($mode = "core")
{
  switch ($mode) {
    'core' {
      prepare_windows_env_core
      break
    }
    'cli' {
      prepare_windows_env_cli
      break
    }
    'gui' {
      prepare_windows_env_gui
      break
    }
    'game' {
      prepare_windows_gaming
      break
    }
    'all' {
      prepare_windows_env_cli
      prepare_windows_env_gui
      break
    }
    Default {
      print_usage
      break
    }
  }
}

function prepare_windows_env_core()
{
  prepare_windows_env_cli_core
  prepare_windows_env_gui_core
}

function prepare_windows_env_cli()
{
  prepare_windows_env_cli_core
  prepare_windows_env_cli_extra
}

function prepare_windows_env_gui()
{
  prepare_windows_env_gui_core
  prepare_windows_env_gui_extra
}

function prepare_windows_env_cli_core()
{
  install_scoop
  install_winget

  $pkgs =
    'ag',
    'broot',
    'delta',
    'fd',
    'fzf',
    'git',
    'gow',
    'jq',
    'lf',
    'ln',
    'micro',
    'openssh',
    'procs',
    'runat',
    'say',
    'sudo',
    'touch',
    'vim'

  scoop_install $pkgs

  $wingetPkgs =
    'JanDeDobbeleer.OhMyPosh',
    'Microsoft.PowerShell'

  winget_install $wingetPkgs
}

function prepare_windows_env_cli_extra()
{
  $pkgs =
    'adb',
    'aria2',
    'cloc',
    'cowsay',
    'deno',
    'duf',
    'far',
    'fq',
    'git-lfs',
    'gping',
    'kubectl',
    'lazydocker',
    'lazygit',
    'losslesscut',
    'lxrunoffline',
    'mc',
    'miniconda3',
    'minikube',
    'nmap',
    'nodejs',
    'now-cli',
    'nvm',
    'oraclejdk',
    'pandoc',
    'python',
    'sbt',
    'shasum',
    'vagrant',
    'yarn'

  scoop_install $pkgs

  $wingetPkgs =
    'Docker.DockerDesktop'

  winget_install $wingetPkgs
}

function prepare_windows_env_gui_core()
{
  $pkgs =
    '7zip',
    'alacritty',
    'altsnap',
    'autohotkey',
    'ditto',
    'everything',
    'keepass',
    'listary',
    'quicklook',
    'snipaste',
    'sublime-merge',
    'sublime-text',
    'sumatrapdf',
    'switcheroo',
    'sysinternals',
    'trafficmonitor',
    'unlocker',
    'vcredist2019', # for windows-terminal
    'vscode',
    'windows-terminal'

  scoop_install $pkgs

  $fonts =
    'FiraCode-NF',
    'Meslo-NF',
    'SourceCodePro-NF'

  scoop_sudo_install $fonts

  $wingetPkgs =
    'Rime.Weasel'

  winget_install $wingetPkgs

  set_windows_configs
}

function prepare_windows_env_gui_extra()
{
  $pkgs =
    'android-sdk',
    'android-studio',
    'atom',
    'calibre',
    'carnac',
    'ccleaner',
    'chromium',
    'cpu-z',
    'dotnet3-sdk',
    'dotnet5-sdk',
    'dotnet6-sdk',
    'doublecmd',
    'dropit',
    'eartrumpet',
    'filezilla',
    'firefox',
    'flux',
    'foobar2000',
    'foobar2000-encoders',
    'foxit-pdf-reader',
    'googlechrome',
    'handbrake',
    'heidisql',
    'hexchat',
    'hub',
    'hwmonitor',
    'irfanview',
    'joplin',
    'kdiff3',
    'kitematic',
    'licecap',
    'marktext',
    'mobaxterm',
    'nimbleset',
    'nimbletext',
    'nircmd',
    'nirlauncher',
    'nodejs-lts',
    'obs-studio',
    'openark',
    'openhardwaremonitor',
    'pdfarranger',
    'pdfsam',
    'phantomjs',
    'potplayer',
    'powertoys',
    'processhacker',
    'proxifier',
    'putty',
    'qutebrowser',
    'robo3t',
    'rufus',
    'screentogif',
    'shadowsocks',
    'skype',
    'slack',
    'smartmontools',
    'spacesniffer',
    'spotify',
    'strokesplus',
    'switchhosts',
    'synctrayzor',
    'telegram',
    'translucenttb',
    'v2rayn',
    'vcredist2015',
    'vcredist2017',
    'vcredist2022',
    'vcxsrv',
    'vncviewer',
    'whatsapp',
    'win-dynamic-desktop',
    'windirstat',
    'winscp',
    'wireshark',
    'wsltty',
    'xming',
    'xnviewmp',
    'zeal',
    'https://raw.githubusercontent.com/acdzh/zpt/master/bucket/pasteex.json'

  scoop_install $pkgs

  $wingetPkgs =
    '9NW33J738BL0', # Monitorian
    'Bytedance.Feishu',
    'CLechasseur.PathCopyCopy',
    'Dropbox.Dropbox',
    'Google.Drive',
    'lyswhut.lx-music-desktop',
    'Oracle.VirtualBox',
    'Resilio.ResilioSync',
    'Tencent.QQ',
    'Tencent.QQMusic',
    'Tencent.WeChat',
    'XK72.Charles'

  winget_install $wingetPkgs
}

function prepare_windows_gaming()
{
  $pkgs =
    'dosbox',
    'dosbox-x',
    'openra',
    'steam'

  scoop_install $pkgs
}

function install_scoop()
{
  Set-ExecutionPolicy RemoteSigned -scope CurrentUser

  if (Get-Command scoop -errorAction SilentlyContinue) {
    scoop update
  } else {
    iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
  }

  scoop install git

  $buckets =
    'extras',
    'games',
    'java',
    'nerd-fonts',
    'nirsoft',
    'nonportable',
    'versions'
  scoop_bucket_add $buckets
  scoop bucket add customize https://github.com/ChinLong/scoop-customize.git
}

function install_winget()
{
  $pkgMgr = Get-AppPackage -name 'Microsoft.DesktopAppInstaller'
  if (!$pkgMgr -or [version]$pkgMgr.Version -lt [version]"1.10.0.0") {
    Start-Process ms-appinstaller:?source=https://aka.ms/getwinget
    Read-Host -Prompt "Press enter to continue..."
  }
}

function set_windows_configs()
{
  $dotPath = "$env:USERPROFILE\.dotfiles"
  $configPath = "$dotPath\config"

  # enable developer mode
  sudo reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"

  # enable ssh-agent service
  sudo Set-Service ssh-agent -StartupType Automatic

  sync_config_repo https://github.com/lukewang1024/dotfiles $dotPath

  backup_then_symlink "$configPath\alacritty" "$env:APPDATA\alacritty"
  backup_then_symlink "$configPath\powershell" "$env:USERPROFILE\Documents\PowerShell"
  backup_then_symlink "$configPath\Rime" "$env:APPDATA\Rime"
  backup_then_symlink "$configPath\ssh\config" "$env:USERPROFILE\.ssh\config"
  backup_then_symlink "$configPath\tig" "$env:USERPROFILE\.config\tig"

  # Make git work with openssh
  [environment]::setenvironmentvariable('GIT_SSH', (resolve-path (scoop which ssh)), 'USER')
  git config --global core.sshCommand C:/Windows/System32/OpenSSH/ssh.exe
}

#########
# Utils #
#########

function blank_lines($num = 3, $char = '.')
{
  for ($i = 0; $i -lt $num; $i++) {
    $char
  }
}

function scoop_bucket_add($buckets)
{
  foreach ($bucket in $buckets) {
    Invoke-Expression "scoop bucket add $bucket"
  }
}

function scoop_install($pkgs)
{
  Invoke-Expression "scoop install $pkgs"
}

function scoop_sudo_install($pkgs)
{
  Invoke-Expression "sudo scoop install $fonts"
}

function winget_install($pkgs)
{
  foreach ($pkg in $pkgs) {
    Invoke-Expression "winget install $pkg --accept-package-agreements"
  }
}

function sync_config_repo($repoUrl, $configPath, $shallow = false)
{
  if (Test-Path "$configPath") {
    if (Test-Path "$configPath\.git") {
      Invoke-Expression "pwsh -Command { cd $configPath ; git pull }"
      return
    }

    backup $configPath
  }

  if ($shallow) {
    git clone --depth 1 $repoUrl $configPath
  } else {
    git clone $repoUrl $configPath
  }
}

function backup($path)
{
  $backupPath = "$path~"
  if (!(Test-Path $path)) {
    Write-Output "[util.backup] Target not found."
    return
  }
  if (Test-Path $backupPath) {
    Remove-Item $backupPath
  }
  Move-Item $path $backupPath
}

function symlink($fromPath, $toPath)
{
  if (!(Test-Path $fromPath)) {
    Write-Output "[util.symlink] Target not found."
    return
  }

  $parentPath = Split-Path -Path $toPath

  if (!(Test-Path $parentPath)) {
    New-Item -ItemType Directory -Path $parentPath
  }

  New-Item -ItemType SymbolicLink -Path $toPath -Target $fromPath
}

function backup_then_symlink($fromPath, $toPath)
{
  if (!(Test-Path $fromPath)) {
    Write-Output "[util.backup_then_symlink] Target not found."
    return
  }

  backup $toPath
  symlink $fromPath $toPath
}

function print_usage()
{
  'Usage: .\init.ps1 [mode]'
  'Modes: core, cli, gui, game, all'
  exit
}

########
# Main #
########

if ($args.count -eq 0) {
  print_usage
}

prepare_windows_env($args[0])
