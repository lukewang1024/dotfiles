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
    # Build tools
    build-essential                   # Essential packages for building Debian packages
    curl                              # Command-line tool for transferring data with URL syntax
    file                              # Utility for determining file types

    # Apps
    fzf                               # Command-line fuzzy finder written in Go
    git                               # Distributed version control system
    htop                              # Interactive process viewer for Unix systems
    ripgrep                           # Search tool like grep and The Silver Searcher
    silversearcher-ag                 # Code-search similar to ack, fast text search tool
    tig                               # Text interface for Git repositories
    tmux                              # Terminal multiplexer
    vim                               # Vi 'workalike' with many additional features
    zsh                               # UNIX shell (command interpreter)
  )
  debian_install_pkgs

  install_linuxbrew
  install_linux_brew_core_packages
  basic_env_setup
  apply_linux_app_configs
  fix_ENOSPC
  fix_locale
}

prepare_debian_env_cli_extra()
{
  pkgs=(
    # Build tools
    apt-transport-https               # APT transport for downloading via HTTPS
    ca-certificates                   # Common CA certificates for SSL/TLS verification
    dstat                             # System resource statistics tool
    libbz2-dev                        # Development files for bzip2 compression library
    libncurses5-dev                   # Development files for ncurses library
    libreadline-dev                   # Development files for GNU readline library
    libsqlite3-dev                    # Development files for SQLite 3 database
    libssl-dev                        # Development files for OpenSSL library
    llvm                              # Low-Level Virtual Machine compiler infrastructure
    make                              # Utility for directing compilation
    python3-setuptools                # Python setuptools for package installation
    ruby                              # Object-oriented scripting language
    software-properties-common        # Common software properties management
    tk-dev                            # Development files for Tk GUI toolkit
    wget                              # Network utility to retrieve files from the web
    xz-utils                          # XZ compression utilities
    zlib1g-dev                        # Development files for zlib compression library

    # Apps
    fortune-mod                       # Fortune cookie program that displays random quotes
    gnupg2                            # GNU Privacy Guard - encryption and signing tool
    neovim                            # Vim-fork focused on extensibility and usability
    polipo                            # Small and fast caching web proxy
    python3-dev                       # Header files and development tools for Python 3
    python3-pip                       # Python package installer
    rxvt-unicode-256color             # Terminal emulator with 256 color support
    w3m-img                           # Text-based web browser with image support
  )
  debian_install_pkgs

  install_linux_brew_extra_packages
  extra_env_setup
}

prepare_debian_env_gui_extra()
{
  ppas=(
    ppa:mmstick76/alacritty # Alacritty
    ppa:jtaylor/keepass     # KeyPass2
    ppa:zeal-developers/ppa # Zeal
  )
  debian_add_PPAs

  # Sublime Text 3 & Sublime Merge (Stable)
  wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
  echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list

  pkgs=(
    alacritty                         # GPU-accelerated terminal emulator
    chromium-browser                  # Open-source web browser
    doublecmd-gtk                     # Twin-panel file manager with GTK interface
    kdiff3                            # File and directory comparison and merge tool
    keepass2                          # Password manager with strong encryption
    oneko                             # Desktop cat that chases your mouse cursor
    sublime-merge                     # Git client with powerful merge tools
    sublime-text                      # Sophisticated text editor for code and markup
    zeal                              # Offline documentation browser
  )
  debian_install_pkgs

  install_st
}
