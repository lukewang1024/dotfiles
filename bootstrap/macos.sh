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
    mas
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
  brew cask install `join ' ' "${casks[@]}"`

  extra_env_setup
}

prepare_macos_env_gui_core()
{
  brew tap homebrew/cask-fonts

  local casks=(
    alacritty
    alfred
    appcleaner
    ezip
    fliqlo
    font-sourcecodepro-nerd-font
    hammerspoon
    hyperswitch
    iina
    iterm2
    karabiner-elements
    mos
    rectangle
    sublime-merge
    sublime-text
    visual-studio-code
  )
  brew cask install `join ' ' "${casks[@]}"`

  set_macos_configs
}

prepare_macos_env_gui_extra()
{
  # MAS apps

  local masApps=(
    406056744  # Evernote
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
    880001334  # Reeder 3
    937984704  # Amphetamine
    998804308  # Blinks
    1025306797 # Resize Master
    1147396723 # WhatsApp
    1176895641 # Spark
    1254743014 # LyricsX
    1278508951 # Trello
    1295203466 # Microsoft Remote Desktop
    1314842898 # miniQpicview (Kantu)
    1452453066 # Hidden Bar
    1477089520 # Backtrack
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
    balenaetcher
    bartender
    bitbar
    browserosaurus
    cakebrew
    calibre
    caprine
    charles
    chromium
    commander-one
    dropbox
    duet
    electron-fiddle
    fantastical
    figma
    firefox
    flume
    flux
    folx
    font-anonymouspro-nerd-font
    font-dejavusansmono-nerd-font
    font-firacode-nerd-font
    font-hack-nerd-font
    font-meslo-nerd-font
    font-ubuntumono-nerd-font
    forklift
    google-backup-and-sync
    google-chrome
    handbrake
    haptickey
    hocus-focus
    horndis
    imagealpha
    imageoptim
    istat-menus
    itsycal
    java
    joplin
    kap
    kdiff3
    keka
    keycastr
    kitematic
    lepton
    losslesscut
    macpass
    microsoft-edge
    mongodb-compass
    mweb2
    notable
    nvalt
    omnidisksweeper
    onedrive
    onyx
    openinterminal
    openmtp
    pdf-expert
    pdfsam-basic
    phantomjs
    postman
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
    sequel-pro
    shadowsocksx-ng
    shifty
    skim
    skype
    sloth
    slowquitapps
    snipaste
    soundflower
    soundflowerbed
    sourcetree
    spotifree
    spotify
    spotify-notifications
    sqlpro-for-postgres
    squirrel
    stretchly
    suspicious-package
    switchhosts
    syncthing
    toau
    tweeten
    typora
    ubersicht
    v2rayu
    vagrant-manager
    virtualbox
    virtualbox-extension-pack
    vnc-viewer
    webpquicklook
    wireshark
    wkhtmltopdf
    xld
    xquartz
    zeplin
    zoomus
  )
  brew cask install `join ' ' "${casks[@]}"`

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

  better_macos_defaults
  brew_multi_user_permission
  fix_battery_drain_over_sleep
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
    caskroom/versions/openemu-experimental
    gog-downloader
    origin
    steam
  )
  brew cask install `join ' ' "${casks[@]}"`
  brew_cleanup
}
