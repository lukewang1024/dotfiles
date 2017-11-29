source "$partial_dir/env.sh"
source "$partial_dir/nix.sh"

caskInstallPkgs()
{
  for pkg in "${pkgs[@]}"; do
    brew cask install "$pkg"
  done
  unset pkgs
}

prepareMacOSEnvCLI()
{
  which brew &> /dev/null || ( \
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" && \
    xcode-select --install \
  )

  brew update; brew upgrade

  # Build tools
  pkgs=(
    openssl
    readline
    xz
  )
  brewInstallPkgs

  installNixBrewPackages

  pkgs=(
    ansifilter
    cmatrix
    cmus
    cpulimit
    csshx
    extract_url
    figlet
    fortune
    gawk
    ghi
    gist
    git-appraise
    git-lfs
    gnu-indent
    gnu-sed
    gnu-tar
    gnu-which
    gnutls
    grep
    heroku
    httpstat
    kubernetes-cli
    m-cli
    mackup
    mas
    netcat
    phantomjs
    reattach-to-user-namespace
    screenfetch
    spark
    telnet
    tmate
    tpp
    urlview
    yarn
  )
  brewInstallPkgs

  brew tap caskroom/fonts && brew update

  pkgs=(
    # Fonts
    font-sourcecodepro-nerd-font-mono

    # CLI tools
    docker
    dotnet
    dotnet-sdk
    google-cloud-sdk
    vagrant
  )
  caskInstallPkgs

  brew cask cleanup; brew cleanup; brew prune

  envSetup
}

prepareMacOSEnvGUI()
{
  # MAS apps

  local masApps=(
    406056744  # Evernote
    441258766  # Magnet
    451108668  # QQ
    568494494  # Pocket
    585829637  # Todoist
    664513913  # 富途牛牛
    747648890  # Telegram
    784801555  # OneNote
    789066512  # Maipo for Weibo
    803453959  # Slack
    836500024  # WeChat
    880001334  # Reeder 3
    926036361  # LastPass
    998804308  # Blinks
    1012930195 # HandShaker
    1147396723 # WhatsApp
    1176895641 # Spark
    1231406087 # QuickTab for Trello
    1254743014 # LyricsX
    1295203466 # Microsoft Remote Desktop
  )

  mas install `join ' ' "${masApps[@]}"`
  mas upgrade

  # Cask packages

  brew tap caskroom/versions # Java 8, Skype 7.x etc.
  brew update

  local pkgs=(
    # Quicklook plugin
    betterzipql
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
    padbury-clock

    # OS enhancement
    alfred
    bartender
    flux
    go2shell
    hammerspoon
    hyperswitch
    iina
    iterm2
    jietu
    karabiner-elements
    keka
    mos
    soundflower
    squirrel

    # Editor
    atom
    macdown
    macvim
    marp
    sublime-text
    typora
    visual-studio-code

    # Utility
    android-file-transfer
    appcleaner
    bitbar
    cakebrew
    calibre
    cyberduck
    duet
    fantastical
    istat-menus
    keycastr
    licecap
    pdfexpert
    pdfsam-basic
    shadowsocksx-ng
    shifty
    skim
    stretchly
    suspicious-package
    the-unarchiver
    toau
    ubersicht
    vnc-viewer

    # DevTool
    imagealpha
    imageoptim
    java
    java8
    kitematic
    vagrant-manager
    virtualbox
    zeplin

    # Network diagnostic tools
    charles
    horndis
    postman
    wireshark

    # VCS tools
    fork
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
    firefoxdeveloperedition
    google-chrome

    # Storage
    dropbox
    google-backup-and-sync
    onedrive
    resilio-sync

    # Social
    caprine
    flume
    google-hangouts
    skype7
    tweeten
    wewechat

    # Download
    aria2gui
    folx

    # Entertainment
    battle-net
    bilibili
    gog-downloader
    neteasemusic
    openemu-experimental
    origin
    spotifree
    spotify
    spotify-notifications
  )
  caskInstallPkgs

  brew cask cleanup; brew cleanup; brew prune

  setMacOSConfigs
}

setMacOSConfigs()
{
  syncConfigRepo ~/.hammerspoon https://github.com/ashfinal/awesome-hammerspoon
  backupThenSymlink "$config_dir/hammerspoon/private" ~/.hammerspoon/private
  backupThenSymlink "$config_dir/karabiner" ~/.config/karabiner

  betterMacOSDefaults
  installMacWeChatPlugin
}

betterMacOSDefaults()
{
  # Keyboard
  defaults write -g ApplePressAndHoldEnabled -bool false
  defaults write -g KeyRepeat -int 2         # minimum 1
  defaults write -g InitialKeyRepeat -int 15 # minimum 10

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
  defaults write com.apple.dock springboard-hide-duration -float 0
  defaults write com.apple.dock springboard-page-duration -float 0
  defaults write com.apple.dock springboard-show-duration -float 0
  defaults write com.apple.finder DisableAllAnimations -bool true
  defaults write com.apple.Mail DisableReplyAnimations -bool true
  defaults write com.apple.Mail DisableSendAnimations -bool true
  defaults write com.apple.Safari WebKitInitialTimedLayoutDelay 0.25
  defaults write com.apple.universalaccess reduceMotion -bool true

  # Dock
  defaults write com.apple.dock scroll-to-open -bool true
  defaults write com.apple.dock springboard-columns -int 8
  defaults write com.apple.dock springboard-rows -int 7
  defaults write com.apple.dock ResetLaunchPad -bool true
  killall Dock
}

installMacWeChatPlugin()
{
  echo 'Installing Mac WeChat plugin...'
  git clone https://github.com/Sunnyyoung/WeChatTweak-macOS.git /tmp/WeChatTweak-macOS
  (cd /tmp/WeChatTweak-macOS; sudo make install)
  echo 'Done.'
}
