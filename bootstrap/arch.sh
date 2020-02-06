source "$partial_dir/env.sh"
source "$partial_dir/linux.sh"

config_pacman()
{
  timedatectl set-ntp true
  sudo pacman-mirrors -c Hong_Kong,Taiwan
}

pacman_install_pkgs()
{
  sudo pacman -Sy --needed --noconfirm `join ' ' "${pkgs[@]}"`
  unset pkgs
}

aur_install_pkgs()
{
  pkgs=( "${pkgs[@]/#/aur/}" )
  yay -Sy --needed `join ' ' "${pkgs[@]}"`
  unset pkgs
}

prepare_arch_env()
{
  config_pacman

  case $1 in
    'core')
      prepare_arch_env_core
      ;;
    'cli')
      prepare_arch_env_cli
      ;;
    'gui')
      prepare_arch_env_gui
      ;;
    'game')
      setup_arch_gaming
      ;;
    'all')
      prepare_arch_env_cli
      prepare_arch_env_gui
      ;;
    *)
      prepare_arch_env_core
      ;;
  esac
}

prepare_arch_env_core()
{
  prepare_arch_env_cli_core
  prepare_arch_env_gui_core
  brew_cleanup
}

prepare_arch_env_cli()
{
  prepare_arch_env_cli_core
  prepare_arch_env_cli_extra
  brew_cleanup
}

prepare_arch_env_gui()
{
  prepare_arch_env_gui_core
  prepare_arch_env_gui_extra
}

prepare_arch_env_cli_core()
{
  pkgs=(
    diff-so-fancy
    fasd
    fd
    fzf
    git
    htop
    httpie
    imagemagick
    jq
    lsd
    neovim
    openssh
    percol
    prettyping
    ranger
    rsync
    the_silver_searcher
    tig
    tldr
    tmux
    vim
    wget
    yarn
    yay
    zsh
  )
  pacman_install_pkgs

  # Set some configs for yay
  yay --save --nocleanmenu --nodiffmenu --noupgrademenu --noremovemake

  pkgs=(
    gitflow-avh
    icdiff
    lf-bin
    peco
    urlview
    xsv
  )
  aur_install_pkgs

  install_linuxbrew
  install_nix_brew_runtimes

  basic_env_setup
  apply_app_configs
  fix_ENOSPC
}

prepare_arch_env_cli_extra()
{
  pkgs=(
    android-tools
    aria2
    aws-cli
    axel
    bat
    cloc
    cmatrix
    cmus
    cowsay
    cpanminus
    cpulimit
    docker
    docker-compose
    docker-machine
    dstat
    figlet
    fish
    flatpak
    fortune-mod
    gifsicle
    go
    graphviz
    haproxy
    hashcat
    hub
    irssi
    jdk-openjdk
    jpegoptim
    kubectl
    lolcat
    mc
    mediainfo
    mpc
    mpd
    mps-youtube
    mpv
    multitail
    mutt
    ncmpcpp
    nghttp2
    nyancat
    offlineimap
    p7zip
    pamixer
    pandoc
    perl-image-exiftool
    pkgfile
    playerctl
    polipo
    progress
    proxychains-ng
    ripgrep
    shadowsocks-libev
    shellcheck
    snapd
    transmission-cli
    tree
    unrar
    unzip
    v2ray
    v2ray-domain-list-community
    v2ray-geoip
    vagrant
    w3m
    wtf
    you-get
    zip
  )
  pacman_install_pkgs

  # Set some configs for yay
  yay --save --nocleanmenu --nodiffmenu --noupgrademenu --noremovemake

  pkgs=(
    apache-spark
    cheat-git
    dive
    downgrader
    fpp
    fswatch
    git-bug-bin
    git-lfs
    git-quick-stats
    google-cloud-sdk
    hyperfine
    mons
    mycli
    onefetch
    pgcli
    sc-im
    sparklines-git
    touchpad-state-git
    translate-shell
    ttf-weather-icons
    wsta
  )
  aur_install_pkgs

  extra_env_setup

  sudo systemctl enable --now snapd.socket # enable snapd
}

prepare_arch_env_gui_core()
{
  pkgs=(
    arandr
    arc-gtk-theme
    arc-icon-theme
    blueman
    chromium
    compton
    fcitx
    fcitx-configtool
    fcitx-im
    fcitx-rime
    feh
    firefox
    galculator
    gsimplecal
    i3-gaps
    i3blocks
    i3status
    lxappearance
    lxsession
    lxtask
    maim
    network-manager-applet
    noto-fonts-emoji
    pa-applet
    polybar
    redshift
    rofi
    rofi-scripts
    termite
    thunar
    thunar-archive-plugin
    thunar-media-tags-plugin
    thunar-shares-plugin
    thunar-volman
    tilda
    ttf-font-awesome
    tumbler
    udiskie
    wqy-zenhei
    xautomation
    xbindkeys
    xcape
    xclip
    xorg-apps
    xscreensaver
    xsel
    zathura
    zathura-cb
    zathura-djvu
    zathura-pdf-mupdf
    zathura-ps
  )
  pacman_install_pkgs

  pkgs=(
    betterlockscreen
    gluqlo-git
    i3ass
    i3lock-color
    nerd-fonts-complete
    python-pywal
    sublime-merge
    sublime-text-dev
    visual-studio-code-bin
    xinit-xsession
  )
  aur_install_pkgs

  install_st
  set_default_apps
}

prepare_arch_env_gui_extra()
{
  pkgs=(
    android-file-transfer
    atom
    chromium
    file-roller
    handbrake
    hardinfo
    kdiff3
    keepassxc
    moka-icon-theme
    neofetch
    qutebrowser
    qv2ray
    rxvt-unicode
    shadowsocks-qt5
    syncthing-gtk
    telegram-desktop
    winetricks
    wkhtmltopdf
    zeal
  )
  pacman_install_pkgs

  pkgs=(
    android-sdk
    android-sdk-platform-tools
    android-studio
    deepin-wechat
    deepin-wine-tim
    dropbox
    etcher-bin
    feedreader
    genymotion
    git-cola
    google-chrome-stable
    kitematic
    losslesscut
    mailspring
    musixmatch-bin
    notable-bin
    rslsync
    screenkey
    skypeforlinux-stable-bin
    slack-desktop
    spotify
    ttf-ms-fonts
    typora
    urxvt-fullscreen
    urxvt-resize-font-git
    whatsapp-web-desktop
  )
  aur_install_pkgs
}

setup_arch_gaming()
{
  pkgs=(
    retroarch
    retroarch-assets-xmb
  )
  pacman_install_pkgs

  pkgs=(
    emulationstation
    libretro-mame-git
    retroarch-autoconfig-udev-git
  )
  aur_install_pkgs
}

set_default_apps()
{
  xdg-mime default chromium.desktop x-scheme-handler/http
  xdg-mime default chromium.desktop x-scheme-handler/https
  xdg-mime default Thunar.desktop inode/directory
}
