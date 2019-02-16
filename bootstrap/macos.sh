source "$partial_dir/env.sh"
source "$partial_dir/nix.sh"

prepare_macos_env_cli()
{
  exists brew || ( \
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" && \
    xcode-select --install \
  )

  brew tap esphen/wsta https://github.com/esphen/wsta.git

  brew upgrade

  install_nix_brew_runtimes
  install_nix_brew_packages

  local pkgs=(
    ansifilter
    brightness
    cmatrix
    cmus
    cpulimit
    csshx
    extract_url
    figlet
    fortune
    fswatch
    gawk
    ghi
    git-appraise
    git-lfs
    gnu-indent
    gnu-sed
    gnu-tar
    gnu-which
    gnutls
    grep
    httpstat
    kubernetes-cli
    m-cli
    mackup
    mas
    mpc
    mpd
    mps-youtube
    mpv
    ncmpcpp
    netcat
    progress
    reattach-to-user-namespace
    spark
    telnet
    tmate
    tpp
    urlview
    wsta
    yarn
  )
  brew install `join ' ' "${pkgs[@]}"`

  local casks=(
    docker
    dotnet-sdk
    google-cloud-sdk
    vagrant
  )
  brew cask install `join ' ' "${casks[@]}"`

  brew cleanup; brew prune

  env_setup
}

prepare_macos_env_gui()
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
    1012930195 # HandShaker
    1147396723 # WhatsApp
    1176895641 # Spark
    1254743014 # LyricsX
    1278508951 # Trello
    1295203466 # Microsoft Remote Desktop
    1314842898 # miniQpicview (Kantu)
  )

  mas install $masApps
  mas upgrade

  # Cask packages

  brew tap homebrew/cask-fonts
  brew tap homebrew/cask-versions
  brew tap lukewang1024/homebrew-legacy
  brew tap dteoh/sqa

  local casks=(
    # Fonts
    font-anonymouspro-nerd-font
    font-dejavusansmono-nerd-font
    font-firacode-nerd-font
    font-hack-nerd-font
    font-sourcecodepro-nerd-font
    font-ubuntumono-nerd-font

    # Quicklook plugin
    provisionql
    qlcolorcode
    qlimagesize
    qlmarkdown
    qlprettypatch
    qlstephen
    qlvideo
    quicklook-csv
    quicklook-json
    quicklook-pat
    quicklookapk
    quicklookase
    suspicious-package
    webpquicklook

    # Screen saver
    aerial
    fliqlo

    # OS enhancement
    alfred
    background-music
    bartender
    commander-one
    ezip
    flux
    forklift
    go2shell
    hammerspoon
    haptickey
    hyperswitch
    iina
    iterm2
    karabiner-elements
    keka
    macpass
    mos
    slowquitapps
    snipaste
    soundflower
    soundflowerbed
    squirrel

    # Editor
    atom
    mweb2
    notable
    nvalt
    sublime-text
    typora
    visual-studio-code

    # Utility
    airdroid
    android-file-transfer
    android-platform-tools
    android-sdk
    android-studio
    androidtool
    appcleaner
    balenaetcher
    bitbar
    cakebrew
    calibre
    duet
    fantastical
    handbrake
    istat-menus
    itsycal
    kap
    keycastr
    lepton
    losslesscut
    onyx
    pdf-expert
    pdfsam-basic
    proxifier
    shadowsocksx-ng
    shifty
    skim
    stretchly
    suspicious-package
    switchhosts
    toau
    ubersicht
    vnc-viewer
    wkhtmltopdf

    # DevTool
    imagealpha
    imageoptim
    java
    java8
    kitematic
    phantomjs
    vagrant-manager
    virtualbox
    virtualbox-extension-pack
    zeplin

    # Network diagnostic tools
    charles
    horndis
    postman
    wireshark

    # VCS tools
    kdiff3
    rowanj-gitx
    sourcetree

    # DB tools
    mongodb-compass
    robo-3t
    sequel-pro
    sqlpro-for-postgres

    # Browser
    chromium
    firefox
    google-chrome
    qutebrowser

    # Storage
    dropbox
    google-backup-and-sync
    onedrive
    resilio-sync
    syncthing-app

    # Social
    caprine
    flume
    skype
    tweeten
    zoomus

    # Download
    aria2gui
    folx

    # Entertainment
    bilibili
    qqmusic
    spotifree
    spotify
    spotify-notifications
  )
  brew cask install `join ' ' "${casks[@]}"`

  sudo kextload /Library/Extensions/HoRNDIS.kext # enable HoRNDIS

  brew cleanup; brew prune

  set_macos_configs
}

set_macos_configs()
{
  sync_config_repo ~/.hammerspoon https://github.com/ashfinal/awesome-hammerspoon
  backup_then_symlink "$config_dir/hammerspoon/private" ~/.hammerspoon/private
  backup_then_symlink "$config_dir/karabiner" ~/.config/karabiner

  # Handy scripts
  backup_then_symlink "$util_dir/macos/virtualbox-kext" ~/bin/virtualbox-kext

  better_macos_defaults
  brew_multi_user_permission
  fix_battery_drain_over_sleep
  install_mac_wechat_plugin
}

better_macos_defaults()
{
  # Keyboard
  defaults write -g ApplePressAndHoldEnabled -bool false
  defaults write -g InitialKeyRepeat -int 15 # minimum 10
  defaults write -g KeyRepeat -int 2         # minimum 1

  # Animation
  defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
  defaults write -g NSBrowserColumnAnimationSpeedMultiplier -float 0
  defaults write -g NSDocumentRevisionsWindowTransformAnimation -bool false
  defaults write -g NSScrollAnimationEnabled -bool false
  defaults write -g NSScrollViewRubberbanding -bool false
  defaults write -g NSToolbarFullScreenAnimationDuration -float 0
  defaults write -g NSWindowResizeTime -float 0.001
  defaults write -g QLPanelAnimationDuration -float 0
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0
  defaults write com.apple.dock expose-animation-duration -float 0
  defaults write com.apple.dock launchanim -bool false
  defaults write com.apple.dock mineffect scale # genie, scale & suck (hidden effect)
  defaults write com.apple.dock springboard-hide-duration -float 0
  defaults write com.apple.dock springboard-page-duration -float 0
  defaults write com.apple.dock springboard-show-duration -float 0
  defaults write com.apple.finder DisableAllAnimations -bool true
  defaults write com.apple.Mail DisableReplyAnimations -bool true
  defaults write com.apple.Mail DisableSendAnimations -bool true
  defaults write com.apple.Safari WebKitInitialTimedLayoutDelay 0.25
  defaults write com.apple.universalaccess reduceMotion -bool true

  # Dock
  defaults write com.apple.dock mouse-over-hilite-stack -bool true
  defaults write com.apple.dock ResetLaunchPad -bool true
  defaults write com.apple.dock scroll-to-open -bool true
  defaults write com.apple.dock showhidden -bool true
  defaults write com.apple.dock springboard-columns -int 8
  defaults write com.apple.dock springboard-rows -int 7

  # Notification
  defaults write com.apple.notificationcenterui bannerTime 3
  defaults write com.apple.CrashReporter UseUNC 1

  # Print
  defaults write -g PMPrintingExpandedStateForPrint -bool true

  # Mojave non-Retina font rendering fix
  defaults write -g CGFontRenderingFontSmoothingDisabled -bool false

  # Safari
  defaults write com.apple.Safari IncludeInternalDebugMenu 1

  # Forklift
  defaults write -g NSFileViewer -string com.binarynights.ForkLift-3

  # SlowQuitApps
  defaults write com.dteoh.SlowQuitApps delay -int 500

  killall Dock
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
}
