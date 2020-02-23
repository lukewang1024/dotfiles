source "$partial_dir/env.sh"

crew_install_pkgs()
{
  crew install `join ' ' "${pkgs[@]}"`
  unset pkgs
}

prepare_chromeos()
{
  exists crew || curl -Ls git.io/vddgY | bash

  crew update; crew upgrade

  pkgs=(
    ag
    fasd
    figlet
    fzf
    git
    htop
    imagemagick7
    jq
    less
    manpages
    mc
    nano
    neofetch
    openssh
    p7zip
    proxychains
    ranger
    rsync
    syncthing
    tig
    tldr
    tmux
    unzip
    yarn
    zip
    zsh
  )
  crew_install_pkgs

  env_setup
}
