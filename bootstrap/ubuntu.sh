source "$partial_dir/env.sh"

ubuntuAddPPAs()
{
  for ppa in "${ppas[@]}"; do
    sudo add-apt-repository -y $ppa
  done
  unset ppas
}

ubuntuInstallPkgs()
{
  sudo apt update
  sudo apt -f install
  sudo apt upgrade -y
  sudo apt install -y `join ' ' "${pkgs[@]}"`
  unset pkgs
}

prepareUbuntuEnvCLI()
{
  ppas=(
    ppa:aacebedo/fasd         # fasd
    ppa:aguignard/ppa         # latest tig
    ppa:fish-shell/release-2  # fish shell
    ppa:git-core/ppa          # latest git
    ppa:jonathonf/vim         # latest vim
    ppa:pi-rho/dev            # latest tmux
    ppa:saiarcot895/myppa     # apt-fast
    ppa:webupd8team/java      # java
  )
  ubuntuAddPPAs

  sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

  # For Docker
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

  # For git-lfs
  curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash

  # For Yarn
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

  pkgs=(
    apt-fast
    aria2
    axel
    build-essential
    cloc
    cmatrix
    cpulimit
    docker-ce
    fasd
    figlet
    fish
    fortune-mod
    git
    git-flow
    git-lfs
    gnupg2
    golang
    httpie
    imagemagick
    irssi
    jq
    mc
    mosh
    mutt
    mycli
    nano
    nmap
    offlineimap
    oracle-java8-installer
    oracle-java8-set-default
    pandoc
    python-dev
    python-pip
    python-software-properties
    python3-pip
    ranger
    rsync
    rxvt-unicode-256color
    shellcheck
    silversearcher-ag
    tmate
    tpp
    tree
    vim
    w3m
    wget
    yarn
    zsh
  )
  ubuntuInstallPkgs

  # Make sure default locale is available
  sudo localedef -i en_US -f UTF-8 en_US.UTF-8

  # Use LinuxBrew for latest version of tools
  installLinuxBrew

  local pkgs = (
    gcc
    tig
    tmux
  )
  brew install `join ' ' "${pkgs[@]}"`

  envSetup
}

prepareUbuntuEnvGUI()
{
  ppas=(
    ppa:djcj/screenfetch    # screenfetch
    ppa:zeal-developers/ppa # zeal
  )
  ubuntuAddPPAs

  # Sublime Text 3 (Stable)
  wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
  echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list

  pkgs=(
    chromium-browser
    doublecmd-gtk
    meld
    oneko
    screenfetch
    sublime-text
    zeal
  )
  ubuntuInstallPkgs
}
