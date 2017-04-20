source "$partial_dir/env.sh"
source "$partial_dir/shell.sh"

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
    python2
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
    translate-shell
    yarn
  )
  yaourtInstallPkgs

  zgenSetup

  nvmSetup
  rbenvSetup
  pyenvSetup
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
