source "$partial_dir/env.sh"

prepareMacOSEnvCLI()
{
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  xcode-select --install

  brew tap homebrew/dupes

  brew update
  brew upgrade

  pkgs=(
    ack
    ansifilter
    aria2
    bash
    bash-completion
    binutils
    cmake
    cmatrix
    cmus
    coreutils
    cpanminus
    csshx
    curl
    diffutils
    ed
    fasd
    file-formula
    findutils
    fish
    fortune
    fzf
    gawk
    git
    git-extras
    git-flow
    gnu-indent
    gnu-sed
    gnu-tar
    gnu-which
    gnutls
    go
    grep
    gzip
    httpstat
    imagemagick
    irssi
    less
    make
    mobile-shell
    mutt
    nano
    ncurses
    netcat
    nmap
    reattach-to-user-namespace
    rsync
    screenfetch
    shellcheck
    tig
    tmate
    tmux
    tpp
    translate-shell
    unzip
    w3m
    watch
    wget
    yarn
    you-get
    zsh
    zsh-completions
  )

  brew install `join ' ' "${pkgs[@]}"`
  unset pkgs

  # Packages with arguments
  brew install openssh --with-brewed-openssl
  brew install python --with-brewed-openssl
  brew install python3 --with-brewed-openssl
  brew install vim --with-lua
  brew install wdiff --with-gettext

  brew cleanup; brew prune

  envSetup
}

prepareMacOSEnvGUI()
{
  brew tap caskroom/fonts
  brew update

  pkgs=(
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

    # Fonts
    font-source-code-pro
    font-source-code-pro-for-powerline

    # Editors
    atom
    macdown
    mactex
    macvim
    meld
    sublime-text
    typora
    visual-studio-code

    # Utilities
    1password
    alfred
    amethyst
    appcleaner
    bartender
    bettertouchtool
    bitbar
    caffeine
    calibre
    cheatsheet
    day-o
    duet
    flashlight
    hyperswitch
    iina
    karabiner
    noizio
    pandoc
    shadowsocksx
    skim
    spectacle
    squirrel
    the-unarchiver
    things
    toau
    ubersicht
    vnc-viewer
    xtrafinder

    # Dev tools
    charles
    dash
    dockertoolbox
    fiddler
    filezilla
    imagealpha
    imageoptim
    iterm2
    mamp
    postman
    smaller
    sourcetree
    vagrant
    vagrant-manager
    virtualbox

    # Internet
    anatine
    caprine
    chromium
    dropbox
    evernote
    firefox
    google-chrome
    google-drive
    google-hangouts
    qq
    ramme
    skype
    slack
    telegram
    wechat
    whatsapp

    # Entertainment
    battle-net
    openemu
    sopcast
  )

  brew install `join ' ' "${pkgs[@]}"`
  unset pkgs

  brew cask cleanup; brew cleanup; brew prune
}
