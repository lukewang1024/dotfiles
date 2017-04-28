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
    cmatrix
    fish
    fortune-mod
    fzf
    git
    go
    htop
    irssi
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
    tmux
    unzip
    vim
    w3m
    wget
    zip
    zsh
  )
  pacmanInstallPkgs

  pkgs=(
    gitflow-avh
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
