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
  # Build tools
  pkgs=(
    apt-transport-https
    build-essential
    ca-certificates
    curl
    file
    git
    python-setuptools
    ruby
    software-properties-common
  )
  ubuntuInstallPkgs

  ppas=(
    ppa:aacebedo/fasd     # fasd
    ppa:saiarcot895/myppa # apt-fast
    ppa:webupd8team/java  # java
  )
  ubuntuAddPPAs

  # Docker
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

  # Yarn
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

  pkgs=(
    apt-fast
    axel
    cloc
    cmatrix
    cpulimit
    docker-ce
    fasd
    figlet
    fortune-mod
    gnupg2
    golang
    oracle-java8-installer
    oracle-java8-set-default
    python-dev
    python-pip
    python-software-properties
    python3-pip
    ranger
    rxvt-unicode-256color
    shellcheck
    tmate
    tpp
    tree
    w3m
    wget
    yarn
    zsh
  )
  ubuntuInstallPkgs

  # Use LinuxBrew for latest version of tools
  installLinuxBrew

  local pkgs = (
    gcc
    aria2
    fish
    git
    git-flow-avh
    git-lfs
    htop
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
    openssh
    pandoc
    rsync
    tig
    the_silver_searcher
    tmux
    vim
  )
  brew install `join ' ' "${pkgs[@]}"`

  # Make sure default locale is available
  sudo localedef -i en_US -f UTF-8 en_US.UTF-8

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
