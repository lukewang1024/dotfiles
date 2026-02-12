source "$partial_dir/env.sh"
source "$partial_dir/nix.sh"
source "$partial_dir/macos-defaults.sh"

prepare_macos_env()
{
  case $1 in
    'core')
      prepare_macos_env_core
      ;;
    'cli')
      prepare_macos_env_cli
      ;;
    'gui')
      prepare_macos_env_gui
      ;;
    'game')
      setup_macos_gaming
      ;;
    'all')
      prepare_macos_env_cli
      prepare_macos_env_gui
      ;;
    *)
      prepare_macos_env_core
      ;;
  esac
}

prepare_macos_env_core()
{
  prepare_macos_env_cli_core
  prepare_macos_env_gui_core
  brew_cleanup
}

prepare_macos_env_cli()
{
  prepare_macos_env_cli_core
  prepare_macos_env_cli_extra
  brew_cleanup
}

prepare_macos_env_gui()
{
  prepare_macos_env_gui_core
  prepare_macos_env_gui_extra
  brew_cleanup
}

install_homebrew()
{
  if ! exists brew; then
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Make sure brew can be found right after installation
    [ -d /opt/homebrew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  brew tap homebrew/command-not-found
}

prepare_macos_env_cli_core()
{
  install_homebrew
  install_nix_brew_runtimes
  install_nix_brew_core_packages

  local pkgs=(
    colima                                        # Container runtimes on MacOS (and Linux) with minimal setup
    mas                                           # Mac App Store command-line interface
  )
  brew install `join ' ' "${pkgs[@]}"`

  # colima service does not respect XDG_CONFIG_HOME and does not configure docker context properly
  # local services=(
  #   colima
  # )
  # brew services start `join ' ' "${pkgs[@]}"`

  basic_env_setup
}

prepare_macos_env_cli_extra()
{
  install_nix_brew_extra_packages

  brew tap LizardByte/homebrew                    # sunshine

  local pkgs=(
    brightness                                    # Change macOS display brightness from the command-line
    csshx                                         # Cluster ssh tool for Terminal.app
    duti                                          # Select default apps for documents and URL schemes on macOS
    fortune                                       # Infamous electronic fortune-cookie generator
    hyperkit                                      # Toolkit for embedding hypervisor capabilities in your application
    m-cli                                         # Swiss Army Knife for macOS
    mackup                                        # Keep your Mac's application settings in sync
    reattach-to-user-namespace                    # Reattach process (e.g., tmux) to background
    scrcpy                                        # Display and control your Android device
    sunshine                                      # Self-hosted game stream host for Moonlight
    terminal-notifier                             # Send macOS User Notifications from the command-line
  )
  brew install `join ' ' "${pkgs[@]}"`

  local casks=(
    android-platform-tools                        # Android SDK component
    dotnet-sdk                                    # Developer platform
    gcloud-cli                                    # Set of tools to manage resources and applications hosted on Google Cloud
    miniconda                                     # Minimal installer for conda
    orbstack                                      # Replacement for Docker Desktop
    powershell                                    # Command-line shell and scripting language
    vagrant                                       # Development environment
  )
  brew install --cask `join ' ' "${casks[@]}"`

  extra_env_setup
}

prepare_macos_env_gui_core()
{
  local casks=(
    alacritty                                     # GPU-accelerated terminal emulator
    alfred                                        # Application launcher and productivity software
    alt-tab                                       # Enable Windows-like alt-tab
    appcleaner                                    # Application uninstaller
    fliqlo                                        # Flip clock screensaver
    font-fira-code-nerd-font                      # FiraCode Nerd Font (Fira Code)
    font-meslo-lg-nerd-font                       # MesloLG Nerd Font families (Meslo LG)
    font-sauce-code-pro-nerd-font                 # SauceCodePro Nerd Font (Source Code Pro)
    font-symbols-only-nerd-font                   # Symbols Nerd Font (Symbols Only)
    hammerspoon                                   # Desktop automation application
    iina                                          # Free and open-source media player
    iterm2                                        # Terminal emulator as alternative to Apple's Terminal app
    jordanbaird-ice                               # Menu bar manager
    karabiner-elements                            # Keyboard customiser
    keyboardholder                                # Switch input method per application
    macpass                                       # Open-source, KeePass-client and password manager
    maczip                                        # Utility to open, create and modify archive files
    mos                                           # Smooths scrolling and set mouse scroll directions independently
    pika                                          # Colour picker for colours onscreen
    rectangle                                     # Move and resize windows using keyboard shortcuts or snap areas
    shottr                                        # Screenshot measurement and annotation tool
    snipaste                                      # Snip or pin screenshots
    squirrel                                      # Rime input method engine
    sublime-merge                                 # Git client
    sublime-text                                  # Text editor for code, markup and prose
    visual-studio-code                            # Open-source code editor
  )
  brew install --cask `join ' ' "${casks[@]}"`

  rime_setup
  set_macos_configs
}

prepare_macos_env_gui_extra()
{
  # MAS apps

  local masApps=(
    441258766                                     # Magnet
    497799835                                     # Xcode
    664513913                                     # Futubull
    747648890                                     # Telegram
    768053424                                     # Gapplin
    784801555                                     # OneNote
    789066512                                     # Maipo for Weibo
    # 880001334                                     # Reeder 3
    897283731                                     # Strongbox - Password Manager
    937984704                                     # Amphetamine
    998361254                                     # Toothpicks
    998804308                                     # Blinks
    1025306797                                    # Resize Master
    1044484672                                    # ApolloOne - Photo Video Viewer
    1142151959                                    # Just Focus
    1176895641                                    # Spark
    1314842898                                    # miniQpicview (Kantu)
    1449412482                                    # Reeder 4
    1452453066                                    # Hidden Bar
    1477089520                                    # Backtrack
    1485844094                                    # iShot
    1497527363                                    # Blurred
    1499181666                                    # OwlOCR - Screenshot to Text
    1507782672                                    # Pixea
    1607635845                                    # Velja
    1615988943                                    # Folder Peek
    1659622164                                    # VidHub - Video Library & Player
    1661733229                                    # LocalSend
    6444050820                                    # Draw Things: AI Generation
  )

  mas install $masApps
  mas upgrade

  # Cask packages

  brew tap homebrew/cask-versions
  brew tap lukewang1024/homebrew-legacy
  brew tap dteoh/sqa                              # slowquitapps
  brew tap lihaoyun6/tap                          # airbattery, quickrecorder

  local casks=(
    aerial                                        # Apple TV Aerial screensaver
    airbattery                                    # Battery monitoring utility (cask unavailable)
    android-sdk                                   # Tools for the Android SDK
    android-studio                                # Tools for building Android applications
    androidtool                                   # App for recording the screen and installing apps in iOS and Android
    apppolice                                     # App for quickly limiting CPU usage of any running process
    aria2gui                                      # Graphical user interface for Aria2
    background-music                              # Audio utility
    betterdisplay                                 # Display management tool
    bitbar                                        # Utility to display the output from any script or program in the menu bar
    bob                                           # Translation application for text, pictures, and manual input
    boop                                          # Scriptable scratchpad for developers
    browserosaurus                                # Open-source browser prompter
    cakebrew                                      # GUI app for Homebrew
    calibre                                       # E-books management software
    caprine                                       # Elegant Facebook Messenger desktop app
    charles                                       # Web debugging Proxy application
    clash-verge-rev                               # Continuation of Clash Verge - A Clash Meta GUI based on Tauri
    commander-one                                 # Two-panel file manager
    coteditor                                     # Plain-text editor for web pages, program source codes and more
    cursor                                        # Write, edit, and chat about your code with AI
    db-browser-for-sqlite                         # Browser for SQLite databases
    dropbox                                       # Client for the Dropbox cloud storage service
    duet                                          # Remote desktop and second display tool
    easydict                                      # Dictionary and translator app
    electron-fiddle                               # Create and play with small Electron experiments
    espanso                                       # Cross-platform Text Expander written in Rust
    eul                                           # Status monitoring
    feishu                                        # Project management software
    firefox                                       # Web browser
    flume                                         # Instagram desktop client (cask unavailable)
    fluor                                         # Change the behavior of the fn keys depending on the active application
    flux                                          # Screen colour temperature controller
    folx                                          # Download manager with a torrent client
    font-smoothing-adjuster                       # Re-enable the font smoothing controls
    forklift3                                     # File manager and FTP/SFTP/WebDAV client (cask unavailable)
    google-chrome                                 # Web browser
    handbrake                                     # Open-source video transcoder
    handy                                         # Speech to text application
    haptickey                                     # Trigger haptic feedback when tapping Touch Bar
    hocus-focus                                   # Hide cursor while typing (cask unavailable)
    horndis                                       # Android USB tethering driver
    hyperconnect                                  # Cross-device interconnection service for the Xiaomi ecosystem
    imagealpha                                    # Utility to reduce the size of 24-bit PNG files
    imageoptim                                    # Tool to optimise images to a smaller size
    inkscape                                      # Vector graphics editor
    istat-menus                                   # System monitoring app
    itermai                                       # Enable generative AI features in iTerm2
    itsycal                                       # Menu bar calendar
    java                                          # Java Standard Edition Development Kit
    joplin                                        # Note taking and to-do application with synchronisation capabilities
    jupyter-notebook-viewer                       # Utility to render Jupyter notebooks
    kap                                           # Open-source screen recorder built with web technology
    kdiff3                                        # Utility for comparing and merging files and directories
    keepingyouawake                               # Tool to prevent the system from going into sleep mode
    keka                                          # File archiver
    keycastr                                      # Open-source keystroke visualiser
    kitematic                                     # Visual user interface for Docker Container management
    kitty                                         # GPU-based terminal emulator
    lark                                          # Project management software
    lepton                                        # Snippet management app
    logoer                                        # Create logos with a simple interface
    losslesscut                                   # Trims video and audio files losslessly
    lulu                                          # Open-source firewall to block unknown outgoing connections
    lyricsx                                       # Lyrics for iTunes, Spotify, Vox and Audirvana Plus
    mac-mouse-fix@2                               # Mouse utility to add gesture functions and smooth scrolling to 3rd party mice
    maccy                                         # Clipboard manager
    mark-text                                     # Markdown editor
    markedit                                      # Markdown editor
    marta                                         # Extensible two-pane file manager
    microsoft-edge                                # Multi-platform web browser
    microsoft-remote-desktop                      # Remote desktop client
    mongodb-compass                               # Interactive tool for analyzing MongoDB data
    monitorcontrol                                # Tool to control external monitor brightness & volume
    moonlight                                     # GameStream client
    msty                                          # Run LLMs locally
    mweb2                                         # Markdown writing and note taking
    netnewswire                                   # Free and open-source RSS reader
    netspot                                       # WiFi site survey software and WiFi scanner
    nightfall                                     # Menu bar utility for toggling dark mode
    ntfstool                                      # Utility that provides NTFS read and write support
    nvalt                                         # Note taking app
    omnidisksweeper                               # Finds large, unwanted files and deletes them
    onyx                                          # Verify system files structure, run miscellaneous maintenance and more
    openinterminal                                # Finder Toolbar app to open the current directory in Terminal or Editor
    openmtp                                       # Android file transfer
    pdf-expert                                    # PDF reader, editor and annotator
    pdfsam-basic                                  # Extracts pages, splits, merges, mixes and rotates PDF files
    phantomjs                                     # Headless web browser
    pngyu                                         # Front-end GUI application for pngquant
    provisionql                                   # Quick Look plugin for mobile apps and provisioning profiles
    proxifier                                     # Proxy client
    qlcolorcode                                   # Quick Look plug-in that renders source code with syntax highlighting
    qlmarkdown                                    # Quick Look generator for Markdown files
    qlprettypatch                                 # Quick Look plugin to view patch files
    qlstephen                                     # Quick Look plugin for plaintext files without an extension
    qlvideo                                       # Thumbnails, static previews, cover art and metadata for video files
    qq                                            # Instant messaging tool
    qqmusic                                       # Chinese music streaming application
    quicklook-csv                                 # Quick Look plugin for CSV files
    quicklook-json                                # Quick Look plugin for JSON files
    quicklook-pat                                 # Quick Look plugin for Adobe Photoshop pattern files
    quicklookapk                                  # Quick Look plugin for Android packages
    quicklookase                                  # Quick Look generator for Adobe Swatch Exchange files
    quickrecorder                                 # Screen recording app (cask unavailable)
    qutebrowser                                   # Keyboard-driven, vim-like browser based on PyQt5
    rapidapi                                      # HTTP client that helps testing and describing APIs
    raycast                                       # Control your tools with a few keystrokes
    redisinsight                                  # GUI for streamlined Redis application development
    resilio-sync                                  # File sync and share software
    robo-3t                                       # MongoDB management tool
    rowanj-gitx                                   # Native graphical client for the git version control system
    sequel-pro                                    # MySQL/MariaDB database management platform
    shifty                                        # Menu bar app that provides more control over Night Shift
    skim                                          # PDF reader and note-taking application
    slack                                         # Team communication and collaboration software
    sloth                                         # Displays all open files and sockets in use by all running processes
    slowquitapps
    soundflower                                   # Audio driver for sound routing
    soundflowerbed                                # Taps into Soundflower channels and route them to an audio device
    spotifree                                     # Automatically mutes ads on Spotify (not supported)
    spotify                                       # Music streaming service
    sqlpro-for-postgres                           # Lightweight PostgreSQL database client
    stats                                         # System monitor for the menu bar
    stretchly                                     # Break time reminder app
    suspicious-package                            # Application for inspecting installer packages
    swiftdefaultappsprefpane                      # Replacement for RCDefaultApps, written in Swift
    switchhosts                                   # App to switch hosts
    the-unarchiver                                # Unpacks archive files
    thorium                                       # Epub reader
    toau                                          # System optimization utility (cask unavailable)
    topnotch                                      # Utility to hide the notch
    tweeten                                       # Twitter client (cask unavailable)
    ubersicht                                     # Run commands and display their output on the desktop
    uninstallpkg                                  # PKG software package uninstall tool
    utm                                           # Virtual machines UI using QEMU
    v2rayu                                        # Collection of tools to build a dedicated basic communication network
    vagrant-manager                               # Vagrant management tool
    virtualbox                                    # Virtualiser for arm64 hardware
    virtualbox-extension-pack                     # VirtualBox Extension Pack (cask unavailable)
    vitalsigns                                    # System monitoring utility (cask unavailable)
    # vmware-fusion                                 # Create, manage, and run virtual machines
    vnc-viewer                                    # Remote desktop application focusing on security
    webpquicklook                                 # Quick Look plugin for webp files
    wechat                                        # Free messaging and calling application
    whatsapp                                      # Native desktop client for WhatsApp
    wireshark                                     # Network protocol analyzer
    wkhtmltopdf                                   # HTML to PDF renderer
    xld                                           # Lossless audio decoder
    xquartz                                       # Open-source version of the X.Org X Window System
  )
  brew install --cask `join ' ' "${casks[@]}"`

  local no_quarantined_casks=(
    syntax-highlight                              # Quicklook extension for source files
  )
  brew install --cask --no-quarantine `join ' ' "${no_quarantined_casks[@]}"`

  sudo kextload /Library/Extensions/HoRNDIS.kext # enable HoRNDIS
}

set_macos_configs()
{
  apply_nix_app_configs

  sync_config_repo ~/.hammerspoon https://github.com/ashfinal/awesome-hammerspoon
  backup_then_symlink "$config_dir/hammerspoon/private" ~/.hammerspoon/private
  backup_then_symlink "$config_dir/karabiner" ~/.config/karabiner
  backup_then_symlink "$config_dir/ranger/macos" ~/.config/ranger
  backup_then_symlink "$config_dir/Rime" ~/Library/Rime
  cp "$config_dir/RectangleApp/RectangleConfig.json" '~/Library/Application Support/Rectangle/RectangleConfig.json'

  # Handy scripts
  backup_then_symlink "$util_dir/macos/virtualbox-kext" "$bin_dir/virtualbox-kext"

  brew_multi_user_permission
  fix_battery_drain_over_sleep
  better_macos_defaults # This needs to be the last one, as Terminal will be killed when finish.
}

brew_multi_user_permission()
{
  sudo chmod -R g+w /usr/local/*
}

fix_battery_drain_over_sleep()
{
  sudo pmset -b tcpkeepalive 0
}

install_mac_wechat_plugin()
{
  echo 'Installing Mac WeChat plugin...'
  local localPath=/tmp/WeChatPlugin-MacOS
  sync_config_repo $localPath https://github.com/TKkk-iOSer/WeChatPlugin-MacOS
  `$localPath/Other/Install.sh`
  echo 'Done.'
}

backup_automator_stuff()
{
  rsync -au ~/Library/Services/ ~/Dropbox/Sync/Automator/Services --progress
  rsync -au ~/Applications/Automator/ ~/Dropbox/Sync/Automator/Applications --progress
}

setup_macos_gaming()
{
  local casks=(
    battle-net                                    # Online gaming platform
    dosbox                                        # Emulator for x86 with DOS
    dosbox-x                                      # Fork of the DOSBox project
    ea                                            # Electronic Arts game launcher
    epic-games                                    # Launcher for Epic Games games
    gog-downloader                                # Tool for downloading games from GOG.com (cask unavailable)
    homebrew/cask-versions/openemu@experimental   # Video game console emulator (experimental)
    openra                                        # Real-time strategy game engine for Westwood games
    steam                                         # Video game digital distribution service
  )
  brew install --cask `join ' ' "${casks[@]}"`
  brew_cleanup
}
