source "$partial_dir/env.sh"
source "$partial_dir/linux.sh"

debian_add_PPAs()
{
  for ppa in "${ppas[@]}"; do
    sudo add-apt-repository -y $ppa
  done
  unset ppas
}

debian_install_pkgs()
{
  sudo apt update
  sudo apt upgrade -y
  sudo apt install -y `join ' ' "${pkgs[@]}"`
  unset pkgs
}

prepare_debian_env()
{
  case $1 in
    'core')
      prepare_debian_env_core
      ;;
    'cli')
      prepare_debian_env_cli
      ;;
    'gui')
      prepare_debian_env_gui
      ;;
    'all')
      prepare_debian_env_cli
      prepare_debian_env_gui
      ;;
    *)
      prepare_debian_env_core
      ;;
  esac
}

prepare_debian_env_core()
{
  prepare_debian_env_cli_core
  brew_cleanup
}

prepare_debian_env_cli()
{
  prepare_debian_env_cli_core
  prepare_debian_env_cli_extra
  brew_cleanup
}

prepare_debian_env_gui()
{
  prepare_debian_env_gui_extra
  brew_cleanup
}

prepare_debian_env_cli_core()
{
  pkgs=(
    build-essential
    curl
    file
    git
  )
  debian_install_pkgs

  install_linuxbrew
  install_linux_brew_core_packages
  basic_env_setup
  apply_app_configs
  fix_ENOSPC
  fix_locale
}

prepare_debian_env_cli_extra()
{
  pkgs=(
    # Build tools
    apt-transport-https
    ca-certificates
    dstat
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

    # Apps
    fortune-mod
    gnupg2
    polipo
    python-dev
    python-pip
    python3-pip
    rxvt-unicode-256color
    w3m-img
  )
  debian_install_pkgs

  install_linux_brew_extra_packages
  extra_env_setup
}

prepare_debian_env_gui_extra()
{
  ppas=(
    ppa:jtaylor/keepass     # KeyPass2
    ppa:zeal-developers/ppa # Zeal
  )
  debian_add_PPAs

  # Sublime Text 3 & Sublime Merge (Stable)
  wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
  echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list

  pkgs=(
    chromium-browser
    doublecmd-gtk
    kdiff3
    keepass2
    oneko
    sublime-merge
    sublime-text
    zeal
  )
  debian_install_pkgs

  install_st
}
