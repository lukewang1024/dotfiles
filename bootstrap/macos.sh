source "$partial_dir/env.sh"

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

  pkgs=(
    ansifilter
    aria2
    awscli
    axel
    bash
    bash-completion
    binutils
    cloc
    cheat
    cmake
    cmatrix
    cmus
    coreutils
    cpanminus
    cpulimit
    csshx
    curl
    diffutils
    ed
    fasd
    ffmpeg
    figlet
    file-formula
    findutils
    fish
    fortune
    fzf
    gawk
    git
    git-extras
    git-flow
    git-lfs
    gnu-indent
    gnu-sed
    gnu-tar
    gnu-which
    gnutls
    go
    grep
    gzip
    httpie
    httpstat
    imagemagick
    irssi
    jq
    kubectl
    less
    m-cli
    mackup
    make
    mas
    midnight-commander
    mobile-shell
    mutt
    mycli
    nano
    ncurses
    neovim
    netcat
    nmap
    offline-imap
    pandoc
    phantomjs
    reattach-to-user-namespace
    rsync
    screenfetch
    shellcheck
    spark
    the_silver_searcher
    thefuck
    tig
    tldr
    tmate
    tmux
    tpp
    translate-shell
    tree
    unzip
    w3m
    watch
    wget
    yarn
    you-get
    youtube-dl
    zsh
    zsh-completions
  )
  brewInstallPkgs

  # Packages with arguments
  brew install openssh --with-brewed-openssl
  brew install python --with-brewed-openssl
  brew install python3 --with-brewed-openssl
  brew install vim --with-lua
  brew install wdiff --with-gettext

  brew tap caskroom/fonts && brew update

  pkgs=(
    # Fonts
    font-sourcecodepro-nerd-font-mono

    # CLI tools
    docker
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
    rescuetime
    resilio-sync
    shadowsocksx
    skim
    slowquitapps
    soundflower
    squirrel
    the-unarchiver
    toau
    ubersicht
    vnc-viewer
    whatpulse

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
