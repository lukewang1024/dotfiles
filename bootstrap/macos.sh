source "$partial_dir/env.sh"

prepareMacOSEnvCLI()
{
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  xcode-select --install

  brew tap homebrew/dupes

  brew update
  brew upgrade

  pkgs=(
    ansifilter
    aria2
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
    jq
    less
    make
    midnight-commander
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
    the_silver_searcher
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
    licecap
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
    java
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
    thunderbird
    wechat
    whatsapp

    # Entertainment
    battle-net
    openemu
    sopcast
  )

  brew cask install `join ' ' "${pkgs[@]}"`
  unset pkgs

  brew cask cleanup; brew cleanup; brew prune
}
