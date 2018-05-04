source "$partial_dir/env.sh"
source "$partial_dir/linux.sh"

ubuntu_add_PPAs()
{
  for ppa in "${ppas[@]}"; do
    sudo add-apt-repository -y $ppa
  done
  unset ppas
}

ubuntu_install_pkgs()
{
  sudo apt update
  sudo apt -f install
  sudo apt upgrade -y
  sudo apt install -y `join ' ' "${pkgs[@]}"`
  unset pkgs
}

prepare_ubuntu_env_cli()
{
  # Build tools
  pkgs=(
    apt-transport-https
    build-essential
    ca-certificates
    curl
    dstat
    file
    git
    libbz2-dev
    libncurses5-dev
    libreadline-dev
    libsqlite3-dev
    libssl-dev
    llvm
    make
    python-setuptools
    ruby
    software-properties-common
    tk-dev
    wget
    xz-utils
    zlib1g-dev
  )
  ubuntu_install_pkgs

  ppas=(
    ppa:aacebedo/fasd     # fasd
    ppa:saiarcot895/myppa # apt-fast
    ppa:webupd8team/java  # java
  )
  ubuntu_add_PPAs

  # Docker
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

  # Google Cloud SDK
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  echo "deb http://packages.cloud.google.com/apt cloud-sdk-$(lsb_release -c -s) main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

  # Heroku
  wget -qO- https://cli-assets.heroku.com/install-ubuntu.sh | sh

  # Yarn
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

  pkgs=(
    apt-fast
    cmatrix
    cpulimit
    docker-ce
    fasd
    figlet
    fortune-mod
    gnupg2
    google-cloud-sdk
    oracle-java8-installer
    oracle-java8-set-default
    polipo
    python-dev
    python-pip
    python-software-properties
    python3-pip
    rxvt-unicode-256color
    tmate
    tpp
    yarn
    zsh
  )
  ubuntu_install_pkgs

  install_linuxbrew
  install_nix_brew_runtimes
  install_nix_brew_packages

  env_setup
  apply_app_configs
  fix_ENOSPC
  fix_locale
}

prepare_ubuntu_env_gui()
{
  ppas=(
    ppa:jtaylor/keepass     # KeyPass2
    ppa:zeal-developers/ppa # Zeal
  )
  ubuntu_add_PPAs

  # Sublime Text 3 (Stable)
  wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
  echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list

  pkgs=(
    chromium-browser
    doublecmd-gtk
    kdiff3
    keepass2
    oneko
    sublime-text
    zeal
  )
  ubuntu_install_pkgs
}
