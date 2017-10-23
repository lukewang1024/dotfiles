source "$partial_dir/env.sh"
source "$partial_dir/linux.sh"

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
  ubuntuInstallPkgs

  installLinuxBrew
  installLinuxBrewPackages

  envSetup
  fixENOSPC
  fixLocale
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
