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
    cloc
    cmatrix
    cpulimit
    figlet
    fish
    fortune-mod
    fzf
    git
    go
    htop
    irssi
    jq
    mc
    nghttp2
    nginx-mainline
    nodejs
    npm
    openssh
    php
    python
    python-pip
    python2
    python2-pip
    readline
    ruby
    the_silver_searcher
    tmux
    tree
    unzip
    vim
    w3m
    wget
    zip
    zsh
  )
  pacmanInstallPkgs

  pkgs=(
    cheat-git
    gitflow-avh
    jdk
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
    screenfetch
    thunderbird
  )
  pacmanInstallPkgs

  pkgs=(
    dropbox
    google-chrome
    skypeforlinux-bin
    sublime-text-dev
    visual-studio-code
  )
  yaourtInstallPkgs
}
