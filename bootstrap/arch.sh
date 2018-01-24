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
    aws-cli
    axel
    cloc
    cmatrix
    cowsay
    cpulimit
    dstat
    fasd
    figlet
    fish
    fortune-mod
    fzf
    gifsicle
    git
    go
    haproxy
    httpie
    imagemagick
    irssi
    jq
    lolcat
    mc
    multitail
    nghttp2
    nodejs
    npm
    offlineimap
    openssh
    p7zip
    polipo
    python
    python-pip
    python2
    python2-pip
    readline
    rsync
    ruby
    shadowsocks-libev
    the_silver_searcher
    tmux
    tree
    unzip
    vim
    w3m
    wget
    wtf
    you-get
    zip
    zsh
  )
  pacmanInstallPkgs

  pkgs=(
    apache-spark
    cheat-git
    git-lfs
    gitflow-avh
    google-cloud-sdk
    heroku-cli
    icdiff
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
    shadowsocks-qt5
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
