source "$partial_dir/env.sh"
source "$partial_dir/nix.sh"

brewInstallPkgs()
{
  brew install `join ' ' "${pkgs[@]}"`
  unset pkgs
}

caskInstallPkgs()
{
  brew cask install `join ' ' "${pkgs[@]}"`
  unset pkgs
}

prepareMacOSEnvCLI()
{
  which brew &> /dev/null || ( \
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" && \
    xcode-select --install \
  )

  brew update; brew upgrade

  installNixBrewPackages

  pkgs=(
    ansifilter
    apache-spark
    cmatrix
    cmus
    cpanminus
    cpulimit
    csshx
    extract_url
    fasd
    figlet
    fortune
    fpp
    gawk
    ghi
    gist
    gnu-indent
    gnu-sed
    gnu-tar
    gnu-which
    gnutls
    grep
    heroku
    httpstat
    m-cli
    mackup
    mas
    netcat
    reattach-to-user-namespace
    screenfetch
    spark
    telnet
    tmate
    tpp
    urlview
    yarn
    zsh
    zsh-completions
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
    747648890  # Telegram
    784801555  # OneNote
    803453959  # Slack
    836500024  # WeChat
    880001334  # Reeder 3
    926036361  # LastPass
    1012930195 # HandShaker
    1059334054 # Jietu
    1147396723 # WhatsApp
    1176895641 # Spark
    1278508951 # Trello
  )

  mas install `join ' ' "${masApps[@]}"`
  mas upgrade

  # Cask packages

  brew tap dteoh/sqa # Slow Quit Apps
  brew update

  local pkgs=(
    # Quick-look plugins
    betterzipql
    qlcolorcode
    qlimagesize
    qlmarkdown
    qlprettypatch
    qlstephen
    quicklook-csv
    quicklook-json
    suspicious-package
    webpquicklook

    # Editors
    atom
    macdown
    macvim
    meld
    sublime-text
    typora
    visual-studio-code

    # Utilities
    alfred
    android-file-transfer
    appcleaner
    bitbar
    cakebrew
    calibre
    clipy
    cyberduck
    duet
    fantastical
    go2shell
    hammerspoon
    hyperswitch
    iina
    istat-menus
    karabiner-elements
    keka
    licecap
    pdfexpert
    pdfsam-basic
    resilio-sync
    shadowsocksx
    shifty
    skim
    slowquitapps
    soundflower
    squirrel
    stretchly
    the-unarchiver
    toau
    ubersicht
    vnc-viewer

    # Dev tools
    charles
    filezilla
    horndis
    imagealpha
    imageoptim
    iterm2
    java
    postman
    robo-3t
    sequel-pro
    smaller
    sourcetree
    vagrant-manager
    virtualbox
    wireshark
    zeplin

    # Internet
    caprine
    chromium
    dropbox
    firefox
    google-backup-and-sync
    google-chrome
    google-hangouts
    onedrive
    ramme
    skype

    # Entertainment
    musixmatch
    neteasemusic
    openemu
    spotify
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
