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
    'ag',                             # Fast code searching tool, also known as "The Silver Searcher"
    'delta',                          # Syntax-highlighting pager for git, diff, and grep output
    'fd',                             # Fast and user-friendly alternative to the find command
    'fx',                             # Terminal-based JSON viewer and processor
    'fzf',                            # Fuzzy finder command-line tool for interactive filtering
    'git',                            # Distributed version control system
    'gow',                            # GNU utilities for Windows - provides Unix-like command line tools
    'jq',                             # Lightweight command-line JSON processor
    'lf',                             # Terminal file manager with vim-like keybindings
    'ln',                             # Command for creating symbolic links and hard links
    'openssh',                        # Secure Shell protocol implementation
    'procs',                          # Modern replacement for the ps command with colored output
    'ripgrep',                        # Recursively searches directories for a regex pattern
    'runat',                          # Windows utility for running commands at specific times
    'say',                            # Text-to-speech command that converts text input into spoken audio
    'sudo',                           # Allows users to run commands with elevated privileges
    'touch',                          # Unix-like utility for creating empty files or updating timestamps
    'vim',                            # Highly configurable text editor with modal editing
    'yazi',                           # Blazing fast terminal file manager written in Rust, based on async I/O
    'zoxide'                          # A faster way to navigate your filesystem

  scoop_install $pkgs

  # Uncomment this if proxy needed
  #sudo winget settings --enable ProxyCommandLineOptions
  #sudo winget settings set DefaultProxy http://127.0.0.1:1081

  $wingetPkgs =
    'JanDeDobbeleer.OhMyPosh',
    'Microsoft.PowerShell'

  winget_install $wingetPkgs
}

function prepare_windows_env_cli_extra()
{
  $pkgs =
    'adb',                            # Android Debug Bridge - Command-line tool for communicating with Android devices
    'aria2',                          # Multi-protocol download utility with fast parallel downloading
    'broot',                          # Interactive tree view file manager with fuzzy search
    'cloc',                           # Count Lines of Code - Tool that counts lines of source code in many languages
    'cowsay',                         # Fun command-line program that generates ASCII pictures of a cow saying text
    'deno',                           # Modern JavaScript and TypeScript runtime built on V8
    'duf',                            # Disk Usage/Free utility - Modern replacement for 'df'
    'dum',                            # Simple duplicate file finder
    'far',                            # File and Archive manager - Advanced file manager for Windows
    'ffmpeg',                         # A complete, cross-platform solution to record, convert and stream audio and video
    'fq',                             # jq for binary formats - Tool for exploring binary data
    'gcloud',                         # Google Cloud CLI - Command-line interface for Google Cloud Platform
    'gh',                             # GitHub CLI - Official command-line tool for GitHub
    'git-lfs',                        # Git Large File Storage - Extension for versioning large files
    'gitui',                          # Terminal-based Git user interface written in Rust
    'gping',                          # Ping tool with a graph - Visual ping utility with real-time graphs
    'helix',                          # Post-modern modal text editor with multiple selections and LSP support
    'imagemagick',                    # Create, edit, compose, and convert 200+ bitmap image formats.
    'kubectl',                        # Kubernetes command-line tool for managing containerized applications
    'lazydocker',                     # Terminal UI for Docker and Docker Compose
    'lazygit',                        # Simple terminal UI for Git commands
    'losslesscut',                    # Cross-platform GUI tool for lossless trimming of video and audio files,
    'lxrunoffline',                   # Windows Subsystem for Linux (WSL) management tool
    'mc',                             # Midnight Commander - Terminal-based file manager with dual-pane interface
    'micro',                          # Modern terminal-based text editor that aims to be easy to use
    'miniconda3',                     # Minimal installer for Conda package manager and Python environment management
    'minikube',                       # Tool for running Kubernetes clusters locally for development and testing
    'musikcube',                      # Terminal-based music player with a ncurses interface
    'nmap',                           # Network discovery and security auditing tool for port scanning
    'nodejs',                         # JavaScript runtime built on Chrome's V8 engine for server-side development
    'now-cli',                        # Command-line interface for Vercel (formerly Zeit Now) deployment platform
    'ntfy',                           # Simple notification service for sending push notifications via HTTP requests
    'nvm',                            # Node Version Manager for switching between different Node.js versions
    'oraclejdk',                      # Oracle's Java Development Kit for Java application development
    'pandoc',                         # Universal document converter between numerous markup and document formats
    'pipx',                           # Tool for installing and running Python applications in isolated environments
    'pnpm',                           # Fast, disk space efficient package manager for Node.js
    'poppler',                        # PDF rendering library
    'python',                         # Python programming language interpreter and runtime environment
    'resvg',                          # An SVG rendering library.
    'sbt',                            # Scala Build Tool for building and managing Scala and Java projects
    'scrcpy',                         # Tool for displaying and controlling Android devices connected via USB or wireless
    'shasum',                         # Command-line utility for calculating and verifying SHA checksums of files
    'sniffnet',                       # Network traffic monitor with a graphical interface
    'starship',                       # Cross-platform shell prompt that is fast, customizable, and feature-rich
    'uv',                             # Ultra-fast Python package installer and resolver written in Rust
    'vagrant',                        # Tool for building and managing virtual machine environments for development
    'xan',                            # Fast CSV processing tool with various data manipulation and analysis capabilities
    'yarn'                            # Package manager for Node.js that provides faster, more reliable dependency management

  scoop_install $pkgs

  $wingetPkgs =
    'Docker.DockerDesktop'

  winget_install $wingetPkgs
}

function prepare_windows_env_gui_core()
{
  $pkgs =
    '7zip',                           # Open-source file archiver with high compression ratio
    'alacritty',                      # Cross-platform, GPU-accelerated terminal emulator
    'altsnap',                        # Window management utility for moving and resizing windows
    'autohotkey',                     # Powerful automation scripting language for Windows
    'autohotkey1.1',                  # Legacy version of AutoHotkey for compatibility
    'ditto',                          # Advanced clipboard manager that stores clipboard history
    'dotnet-sdk',                     # Microsoft .NET Software Development Kit
    'everything',                     # Ultra-fast file search engine that instantly locates files
    'keepassxc',                      # Cross-platform password manager with strong encryption
    'listary',                        # Smart file search and launcher for Windows
    'localsend',                      # Share files to nearby devices. An open source cross-platform alternative to AirDrop
    'powertoys',                      # Microsoft's collection of utilities for power users
    'quicklook',                      # Spacebar preview functionality for Windows, similar to macOS
    'snipaste',                       # Screenshot and image annotation tool with pinning capabilities
    'sublime-merge',                  # Git client with powerful merge conflict resolution
    'sublime-text',                   # Sophisticated text editor for code, markup, and prose
    'sumatrapdf',                     # Lightweight, fast PDF, eBook, and document viewer
    'switcheroo',                     # Alt-Tab replacement with enhanced window switching
    'sysinternals',                   # Microsoft's collection of advanced system utilities
    'trafficmonitor',                 # Network and system monitoring tool with real-time usage display
    'unlocker',                       # Utility to unlock files that are in use by system processes
    'vscode',                         # Microsoft's free, open-source code editor with extensive extensions
    'windows-terminal'                # Modern, fast terminal application for command-line tools

  scoop_install $pkgs

  $fonts =
    'FiraCode-NF',                    # FiraCode Nerd Font - Programming font with ligatures
    'Meslo-NF',                       # Meslo Nerd Font - Terminal font based on Menlo
    'SourceCodePro-NF'                # Source Code Pro Nerd Font - Adobe's programming font

  scoop_sudo_install $fonts

  $wingetPkgs =
    'Rime.Weasel',                    # Chinese input method engine for Windows
    'stnkl.EverythingToolbar'         # Everything search integration for Windows taskbar

  winget_install $wingetPkgs

  set_windows_configs
}

function prepare_windows_env_gui_extra()
{
  $pkgs =
    'altsnap',                        # Window management utility for moving and resizing windows using Alt+drag
    'android-sdk',                    # Android Software Development Kit for Android app development
    'android-studio',                 # Official integrated development environment (IDE) for Android development
    'calibre',                        # E-book management software for organizing and converting digital books
    'carnac',                         # Keystroke visualizer for presentations and tutorials
    'ccleaner',                       # System optimization and privacy tool for cleaning temporary files
    'chromium',                       # Open-source web browser foundation for Google Chrome
    'clash-verge-rev',                # Cross-platform proxy client with GUI for network management
    'cpu-z',                          # System information utility displaying hardware specifications
    'doublecmd',                      # Dual-pane file manager with advanced features
    'dropit',                         # Drag-and-drop automation tool with customizable rules
    'eartrumpet',                     # Advanced volume control with per-application audio management
    'filezilla',                      # Free FTP, FTPS, and SFTP client for file transfer
    'firefox',                        # Open-source web browser with privacy-focused features
    'flux',                           # Screen color temperature adjustment tool for reducing blue light
    'foobar2000',                     # Lightweight, customizable audio player
    'foobar2000-encoders',            # Additional audio encoding components for foobar2000
    'foxit-pdf-reader',               # PDF viewer and editor with annotation capabilities
    'googlechrome',                   # Popular web browser with integrated Google services
    'handbrake',                      # Open-source video transcoder for format conversion,
    'heidisql',                       # Database management GUI for MySQL, MariaDB, PostgreSQL, SQLite
    'hexchat',                        # Cross-platform IRC client with graphical interface
    'hub',                            # Command-line wrapper for Git with GitHub integration
    'hwmonitor',                      # System monitoring tool for hardware temperatures and voltages
    'irfanview',                      # Fast and compact image viewer and editor
    'joplin',                         # Open-source note-taking and to-do list application
    'kdiff3',                         # File and directory comparison and merge tool
    'kitematic',                      # Docker GUI for managing containers visually
    'licecap',                        # Screen recording tool that saves as animated GIF files
    'marktext',                       # Real-time markdown editor with live preview
    'mobaxterm',                      # Enhanced terminal with X11 server and SSH client
    'nimbleset',                      # Text manipulation tool for bulk find-and-replace operations
    'nimbletext',                     # Data manipulation tool for transforming structured text
    'nircmd',                         # Command-line utility for various Windows system operations
    'nirlauncher',                    # Collection launcher for all NirSoft utilities
    'nodejs-lts',                     # Long Term Support version of Node.js JavaScript runtime
    'obs-studio',                     # Open-source software for video recording and live streaming
    'openark',                        # Database administration toolkit for MySQL
    'openhardwaremonitor',            # System monitoring application for hardware sensors
    'pdfarranger',                    # PDF document manipulation tool for merging and splitting,
    'pdfsam',                         # PDF manipulation tool for splitting, merging, and rotating pages
    'phantomjs',                      # Headless WebKit browser for web scraping and automation
    'potplayer',                      # Feature-rich multimedia player with advanced playback options
    'processhacker',                  # Advanced system monitor and process manager
    'proxifier',                      # Network proxy client with SOCKS/HTTPS support
    'putty',                          # SSH and telnet client for secure remote connections
    'qutebrowser',                    # Keyboard-driven web browser with vim-like keybindings
    'robo3t',                         # GUI client for MongoDB database management
    'rufus',                          # Utility for creating bootable USB drives from ISO images
    'runcat',                         # System monitor displaying CPU usage through animated cat
    'screentogif',                    # Screen recorder that exports animations to GIF format
    'slack',                          # Team communication and collaboration platform
    'smartmontools',                  # Command-line utilities for monitoring hard drive health
    'spacesniffer',                   # Disk usage analyzer with treemap visualization
    'spotify',                        # Music streaming service with millions of songs and podcasts
    'sqlitebrowser',                  # GUI tool for creating and editing SQLite database files
    'strokesplus',                    # Mouse gesture recognition software for commands and shortcuts
    'switchhosts',                    # Quick hosts file editor for switching configurations
    'synctrayzor',                    # GUI wrapper for Syncthing file synchronization
    'telegram',                       # Cross-platform messaging app with security focus,
    'thorium-reader',                 # Accessible EPUB reader supporting various ebook formats
    'translucenttb',                  # Utility that makes Windows taskbar transparent or translucent
    'v2rayn',                         # GUI client for V2Ray proxy tool for network privacy
    'vcredist',                       # Microsoft Visual C++ Redistributable packages
    'vcxsrv',                         # X11 server for Windows allowing Linux GUI applications
    'vncviewer',                      # Remote desktop client for connecting to VNC servers
    'whatsapp',                       # Popular messaging application for text, voice, and video
    'win-dynamic-desktop',            # Utility that changes wallpaper based on time of day
    'windirstat',                     # Disk usage statistics viewer with treemap visualization
    'winscp',                         # SFTP, FTP, and SCP client for secure file transfers
    'wireshark',                      # Network protocol analyzer for examining network traffic
    'wsltty',                         # Terminal emulator for Windows Subsystem for Linux
    'xming',                          # X Window System server for Windows
    'xnviewmp',                       # Image viewer and converter supporting hundreds of formats
    'zeal',                           # Offline documentation browser for programming languages,
    'https://raw.githubusercontent.com/acdzh/zpt/master/bucket/pasteex.json',
    'https://raw.githubusercontent.com/go-musicfox/go-musicfox/master/deploy/scoop/go-musicfox.json'

  scoop_install $pkgs

  $wingetPkgs =
    '9NGHP3DX8HDX',                   # Files App - Modern file manager for Windows
    '9NW33J738BL0',                   # Monitorian - Monitor brightness control
    'Anysphere.Cursor',               # AI-powered code editor with intelligent assistance
    'Bytedance.Feishu',               # Team collaboration and productivity platform
    'CLechasseur.PathCopyCopy',       # Context menu plugin for copying file paths
    'Dropbox.Dropbox',                # Cloud storage and file synchronization service
    'Google.Drive',                   # Google's cloud storage and office suite
    'Oracle.VirtualBox',              # Virtual machine software for running multiple OS
    'Tencent.QQ',                     # Popular Chinese instant messaging application
    'Tencent.QQMusic',                # Chinese music streaming service
    'Tencent.WeChat',                 # Chinese multi-purpose messaging and social media app
    'XK72.Charles'                    # Web debugging proxy for monitoring HTTP traffic

  winget_install $wingetPkgs
}

function prepare_windows_gaming()
{
  $pkgs =
    'dosbox',                         # Emulator for x86 with DOS for running legacy games
    'dosbox-x',                       # Enhanced fork of DOSBox with additional features
    'openra',                         # Real-time strategy game engine for classic Westwood games
    'steam'                           # Digital distribution platform for PC gaming

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

  # Uncomment this if proxy needed
  #scoop config proxy 127.0.0.1:1080

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

  sync_config_repo https://github.com/lukewang1024/dotfiles "$dotPath"

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

function sync_config_repo($repoUrl, $configPath, $shallow = $false)
{
  if (Test-Path "$configPath") {
    if (Test-Path "$configPath\.git") {
      Invoke-Expression "pwsh -Command { cd '$configPath' ; git pull }"
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
