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
    ppa:stb-tester/stb-tester # stb-tester
    ppa:webupd8team/java      # java
  )
  ubuntuAddPPAs

  # For Yarn
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

  # For MongoDB
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
  echo 'deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.0 multiverse' | sudo tee /etc/apt/sources.list.d/mongodb-org-3.0.list

  pkgs=(
    apt-fast
    aria2
    axel
    build-essential
    cloc
    cmatrix
    cpulimit
    fasd
    figlet
    fish
    fortune-mod
    git
    git-flow
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
    nmap
    oracle-java8-installer
    oracle-java8-set-default
    pandoc
    python-dev
    python-pip
    python-software-properties
    python3-pip
    ranger
    rxvt-unicode-256color
    shellcheck
    silversearcher-ag
    software-properties-common
    stb-tester
    tig
    tmate
    tmux
    tpp
    tree
    vim
    w3m
    yarn
    zsh
  )
  ubuntuInstallPkgs

  envSetup
}

prepareUbuntuEnvGUI()
{
  ppas=(
    ppa:djcj/screenfetch    # screenfetch
    ppa:zeal-developers/ppa # zeal
  )
  ubuntuAddPPAs

  pkgs=(
    chromium-browser
    doublecmd-gtk
    meld
    oneko
    screenfetch
    zeal
  )
  ubuntuInstallPkgs
}
