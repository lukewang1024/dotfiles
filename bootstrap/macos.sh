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
    1012930195 # HandShaker
    1147396723 # WhatsApp
    1176895641 # Spark
    1231406087 # QuickTab for Trello
    1254743014 # LyricsX
  )

  mas install `join ' ' "${masApps[@]}"`
  mas upgrade

  # Cask packages

  brew tap caskroom/versions # Java 8 etc.
  brew tap dteoh/sqa # Slow Quit Apps
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
    soundflower
    squirrel

    # Editor
    atom
    macdown
    macvim
    marp
    meld
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
    charles
    fork
    horndis
    imagealpha
    imageoptim
    java
    java8
    kitematic
    postman
    smaller
    sourcetree
    vagrant-manager
    virtualbox
    wireshark
    zeplin

    # Database GUI
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
    skype
    tweeten
    wewechat

    # Download
    aria2gui
    folx

    # Entertainment
    bilibili
    neteasemusic
    openemu
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

  installMacWeChatPlugin
}

installMacWeChatPlugin()
{
  echo 'Installing Mac WeChat plugin...'
  git clone https://github.com/Sunnyyoung/WeChatTweak-macOS.git /tmp/WeChatTweak-macOS
  (cd /tmp/WeChatTweak-macOS; sudo make install)
  echo 'Done.'
}
