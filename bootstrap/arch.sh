source "$partial_dir/env.sh"

pacmanInstallPkgs()
{
  sudo pacman -Sy `join ' ' "${pkgs[@]}"` --needed
  unset pkgs
}

yaourtInstallPkgs()
{
  yaourt -Sy `join ' ' "${pkgs[@]}"`
  unset pkgs
}

prepareArchEnvCLI()
{
  pkgs=(
    apache
    apache-spark
    aws-cli
    axel
    cloc
    cmatrix
    cowsay
    cpulimit
    fasd
    figlet
    fish
    fortune-mod
    fzf
    git
    go
    htop
    httpie
    imagemagick
    irssi
    jq
    lolcat
    mc
    nghttp2
    nginx-mainline
    nodejs
    npm
    offlineimap
    openssh
    php
    polipo
    python
    python-pip
    python2
    python2-pip
    readline
    rsync
    ruby
    the_silver_searcher
    tmux
    tree
    unzip
    vim
    w3m
    wget
    you-get
    zip
    zsh
  )
  pacmanInstallPkgs

  pkgs=(
    cheat-git
    git-lfs
    gitflow-avh
    google-cloud-sdk
    jdk
    mycli
    sparklines-git
    tldr-git
    translate-shell
    yarn
  )
  yaourtInstallPkgs

  envSetup
}

prepareArchEnvGUI()
{
  pkgs=(
    chromium
    firefox
    kdiff3
    keepass
    screenfetch
    wkhtmltopdf
  )
  pacmanInstallPkgs

  pkgs=(
    dropbox
    electronic-wechat
    firefox-developer
    google-chrome
    keepass-plugin-dbbackup
    keepass-plugin-favicon
    keepass-plugin-haveibeenpwned
    keepass-plugin-http
    keepass-plugin-keeotp
    keepass-plugin-qualitycolumn
    keepass-plugin-quickunlock
    keepass-plugin-rpc
    keepass-plugin-traytotp
    skypeforlinux-bin
    sublime-text-dev
    visual-studio-code
  )
  yaourtInstallPkgs
}
