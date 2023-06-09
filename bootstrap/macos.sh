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
    mas
  )
  brew install `join ' ' "${pkgs[@]}"`

  basic_env_setup
}

prepare_macos_env_cli_extra()
{
  install_nix_brew_extra_packages

  local pkgs=(
    brightness
    csshx
    fortune
    hyperkit
    m-cli
    mackup
    reattach-to-user-namespace
    scrcpy
  )
  brew install `join ' ' "${pkgs[@]}"`

  local casks=(
    android-platform-tools
    docker
    dotnet-sdk
    orbstack
    powershell
    vagrant
  )
  brew install --cask `join ' ' "${casks[@]}"`

  extra_env_setup
}

prepare_macos_env_gui_core()
{
  brew tap homebrew/cask-fonts

  local casks=(
    alacritty
    alfred
    alt-tab
    appcleaner
    browserosaurus
    fliqlo
    font-fira-code-nerd-font
    font-meslo-lg-nerd-font
    font-sauce-code-pro-nerd-font
    hammerspoon
    iina
    iterm2
    karabiner-elements
    keyboardholder
    macpass
    maczip
    mos
    rectangle
    shottr
    snipaste
    squirrel
    sublime-merge
    sublime-text
    visual-studio-code
  )
  brew install --cask `join ' ' "${casks[@]}"`

  rime_setup
  set_macos_configs
}

prepare_macos_env_gui_extra()
{
  # MAS apps

  local masApps=(
    441258766  # Magnet
    497799835  # Xcode
    539883307  # LINE
    568494494  # Pocket
    585829637  # Todoist
    664513913  # 富途牛牛
    747648890  # Telegram
    768053424  # Gapplin
    784801555  # OneNote
    789066512  # Maipo for Weibo
    # 880001334  # Reeder 3
    937984704  # Amphetamine
    998361254  # Toothpicks
    998804308  # Blinks
    1025306797 # Resize Master
    1044484672 # ApolloOne - Photo Video Viewer
    1142151959 # Just Focus
    1176895641 # Spark
    1278508951 # Trello
    1314842898 # miniQpicview (Kantu)
    1449412482 # Reeder 4
    1452453066 # Hidden Bar
    1477089520 # Backtrack
    1485844094 # iShot
    1497527363 # Blurred
    1499181666 # OwlOCR - Screenshot to Text
    1507782672 # Pixea
    1607635845 # Velja
    1615988943 # Folder Peek
    1661733229 # LocalSend
  )

  mas install $masApps
  mas upgrade

  # Cask packages

  brew tap homebrew/cask-versions
  brew tap lukewang1024/homebrew-legacy
  brew tap dteoh/sqa

  local casks=(
    aerial
    aldente
    android-sdk
    android-studio
    androidtool
    apppolice
    aria2gui
    background-music
    betterdisplay
    bitbar
    bob
    boop
    cakebrew
    calibre
    caprine
    charles
    commander-one
    coteditor
    dropbox
    duet
    electron-fiddle
    espanso
    eul
    fantastical
    feishu
    figma
    firefox
    firefox-nightly
    flume
    flux
    folx
    font-smoothing-adjuster
    forklift
    google-backup-and-sync
    google-chrome
    google-chrome-canary
    handbrake
    haptickey
    hocus-focus
    horndis
    imagealpha
    imageoptim
    inkscape
    istat-menus
    itsycal
    java
    joplin
    jupyter-notebook-viewer
    kdiff3
    keepingyouawake
    keka
    keycastr
    kitematic
    kitty
    lark
    lepton
    losslesscut
    lulu
    lx-music
    lyricsx
    maccy
    mark-text
    microsoft-edge
    microsoft-remote-desktop
    mongodb-compass
    monitorcontrol
    mweb2
    netspot
    nightfall
    ntfstool
    nvalt
    omnidisksweeper
    onedrive
    onyx
    openinterminal
    openmtp
    pdf-expert
    pdfsam-basic
    phantomjs
    provisionql
    proxifier
    qlcolorcode
    qlimagesize
    qlmarkdown
    qlprettypatch
    qlstephen
    qlvideo
    qq
    qqmusic
    quicklook-csv
    quicklook-json
    quicklook-pat
    quicklookapk
    quicklookase
    qutebrowser
    rapidapi
    redisinsight
    resilio-sync
    robo-3t
    rowanj-gitx
    safari-technology-preview
    sequel-pro
    shifty
    skim
    slack
    sloth
    soundflower
    soundflowerbed
    spotifree
    spotify
    sqlpro-for-postgres
    stats
    stretchly
    suspicious-package
    switchhosts
    the-unarchiver
    toau
    topnotch
    tweeten
    ubersicht
    uninstallpkg
    utm
    v2rayu
    vagrant-manager
    virtualbox
    virtualbox-extension-pack
    vitalsigns
    vnc-viewer
    webpquicklook
    wechat
    whatsapp
    wireshark
    wkhtmltopdf
    xld
    xquartz
    zeplin
    zoomus
  )
  brew install --cask `join ' ' "${casks[@]}"`

  local no_quarantined_casks=(
    syntax-highlight
  )
  brew install --cask `join ' ' "${no_quarantined_casks[@]}"`

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
    battle-net
    dosbox
    dosbox-x
    epic-games
    gog-downloader
    homebrew/cask-versions/openemu-experimental
    openra
    origin
    steam
  )
  brew install --cask `join ' ' "${casks[@]}"`
  brew_cleanup
}
