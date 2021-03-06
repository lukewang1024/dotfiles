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

prepare_macos_env_cli_core()
{
  exists brew || ( \
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" && \
    xcode-select --install \
  )

  brew tap homebrew/command-not-found

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
  brew tap esphen/wsta https://github.com/esphen/wsta.git

  install_nix_brew_extra_packages

  local pkgs=(
    brightness
    csshx
    fortune
    m-cli
    mackup
    reattach-to-user-namespace
    wsta
  )
  brew install `join ' ' "${pkgs[@]}"`

  local casks=(
    docker
    dotnet-sdk
    google-cloud-sdk
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
    appcleaner
    browserosaurus
    fliqlo
    font-fira-code-nerd-font
    font-meslo-lg-nerd-font
    font-sauce-code-pro-nerd-font
    hammerspoon
    hyperswitch
    iina
    iterm2
    karabiner-elements
    macpass
    maczip
    mos
    rectangle
    snipaste
    squirrel
    sublime-merge
    sublime-text
    switchkey
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
    425424353  # The Unarchiver
    441258766  # Magnet
    451108668  # QQ
    497799835  # Xcode
    539883307  # LINE
    568494494  # Pocket
    585829637  # Todoist
    664513913  # 富途牛牛
    747648890  # Telegram
    784801555  # OneNote
    789066512  # Maipo for Weibo
    803453959  # Slack
    836500024  # WeChat
    # 880001334  # Reeder 3
    937984704  # Amphetamine
    998804308  # Blinks
    1025306797 # Resize Master
    1044484672 # ApolloOne - Photo Video Viewer
    1147396723 # WhatsApp
    1176895641 # Spark
    1254743014 # LyricsX
    1278508951 # Trello
    1295203466 # Microsoft Remote Desktop
    1314842898 # miniQpicview (Kantu)
    1449412482 # Reeder 4
    1452453066 # Hidden Bar
    1477089520 # Backtrack
    1485844094 # iShot
    1497527363 # Blurred
    1507782672 # Pixea
  )

  mas install $masApps
  mas upgrade

  # Cask packages

  brew tap homebrew/cask-versions
  brew tap lukewang1024/homebrew-legacy
  brew tap dteoh/sqa

  local casks=(
    aerial
    android-platform-tools
    android-sdk
    android-studio
    androidtool
    aria2gui
    atom
    background-music
    bitbar
    bob
    cakebrew
    calibre
    caprine
    charles
    commander-one
    dropbox
    duet
    electron-fiddle
    fantastical
    feishu
    figma
    firefox
    firefox-nightly
    flume
    flux
    folx
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
    istat-menus5
    itsycal
    java
    joplin
    kap
    kdiff3
    keka
    keycastr
    kitematic
    lark
    lepton
    losslesscut
    lx-music
    microsoft-edge
    mongodb-compass
    monitorcontrol
    mweb2
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
    qqmusic
    quicklook-csv
    quicklook-json
    quicklook-pat
    quicklookapk
    quicklookase
    qutebrowser
    resilio-sync
    robo-3t
    rowanj-gitx
    safari-technology-preview
    sequel-pro
    shadowsocksx-ng
    shifty
    skim
    skype
    sloth
    slowquitapps
    soundflower
    soundflowerbed
    sourcetree
    spotifree
    spotify
    spotify-notifications
    sqlpro-for-postgres
    stretchly
    suspicious-package
    switchhosts
    syncthing
    tencent-lemon
    toau
    tweeten
    typora
    ubersicht
    utm
    v2rayu
    vagrant-manager
    virtualbox
    virtualbox-extension-pack
    vnc-viewer
    webpquicklook
    wireshark
    wkhtmltopdf
    xld
    zeplin
    zoomus
  )
  brew install --cask `join ' ' "${casks[@]}"`

  sudo kextload /Library/Extensions/HoRNDIS.kext # enable HoRNDIS
}

set_macos_configs()
{
  apply_nix_app_configs

  sync_config_repo ~/.hammerspoon https://github.com/ashfinal/awesome-hammerspoon
  backup_then_symlink "$config_dir/hammerspoon/private" ~/.hammerspoon/private
  backup_then_symlink "$config_dir/karabiner" ~/.config/karabiner
  backup_then_symlink "$config_dir/ranger/macos" ~/.config/ranger

  # Handy scripts
  backup_then_symlink "$util_dir/macos/virtualbox-kext" ~/bin/virtualbox-kext

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
    gog-downloader
    homebrew/cask-versions/openemu-experimental
    origin
    steam
  )
  brew install --cask `join ' ' "${casks[@]}"`
  brew_cleanup
}
