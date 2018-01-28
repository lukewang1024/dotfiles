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

  pkgs=(
    # Fonts
    caskroom/fonts/font-sourcecodepro-nerd-font-mono

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
    1231406087 # QuickTab for Trello
    1254743014 # LyricsX
    1295203466 # Microsoft Remote Desktop
  )

  mas install `join ' ' "${masApps[@]}"`
  mas upgrade

  # Cask packages

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
    commander-one
    flux
    go2shell
    hammerspoon
    hyperswitch
    iina
    iterm2
    karabiner-elements
    keka
    macpass
    mos
    snipaste
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
    android-platform-tools
    android-sdk
    android-studio
    androidtool
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
    onyx
    pdfexpert
    pdfsam-basic
    proxifier
    shadowsocksx-ng
    shifty
    skim
    stretchly
    suspicious-package
    teambition
    the-unarchiver
    toau
    ubersicht
    vnc-viewer

    # DevTool
    caskroom/versions/java8
    imagealpha
    imageoptim
    java
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
    kdiff3
    rowanj-gitx
    sourcetree

    # DB tools
    mongodb-compass
    robo-3t
    sequel-pro
    sqlpro-for-postgres

    # Browser
    caskroom/versions/firefoxdeveloperedition
    chromium
    firefox
    google-chrome

    # Storage
    dropbox
    google-backup-and-sync
    onedrive
    resilio-sync

    # Social
    caprine
    caskroom/versions/skype7
    flume
    tweeten

    # Download
    aria2gui
    folx

    # Entertainment
    battle-net
    bilibili
    caskroom/versions/openemu-experimental
    gog-downloader
    neteasemusic
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
  brewMultiUserPermission
  fixBatteryDrainOverSleep
  installMacWeChatPlugin
}

betterMacOSDefaults()
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

  # Safari
  defaults write com.apple.Safari IncludeInternalDebugMenu 1

  killall Dock
}

brewMultiUserPermission()
{
  sudo chmod -R g+w /usr/local/*
}

fixBatteryDrainOverSleep()
{
  sudo pmset -b tcpkeepalive 0
}

installMacWeChatPlugin()
{
  echo 'Installing Mac WeChat plugin...'
  git clone https://github.com/Sunnyyoung/WeChatTweak-macOS.git /tmp/WeChatTweak-macOS
  (cd /tmp/WeChatTweak-macOS; sudo make install)
  echo 'Done.'
}

backupAutomatorStuff()
{
  rsync -au ~/Library/Services/ ~/Dropbox/Sync/Automator/Services --progress
  rsync -au ~/Applications/Automator/ ~/Dropbox/Sync/Automator/Applications --progress
}
