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

  pkgs=(
    fortune-mod
    gnupg2
    polipo
    python-dev
    python-pip
    python3-pip
    rxvt-unicode-256color
  )
  ubuntu_install_pkgs

  install_linuxbrew
  install_linux_brew_packages

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
