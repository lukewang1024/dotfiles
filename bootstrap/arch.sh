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
    broot
    diff-so-fancy
    dog
    fd
    fzf
    git
    git-delta
    htop
    httpie
    imagemagick
    jq
    lsd
    micro
    neovim
    openssh
    pamac-cli
    peco
    percol
    prettyping
    procs
    ranger
    rsync
    the_silver_searcher
    tig
    tldr
    tmux
    trash-cli
    vim
    wget
    yarn
    yay
    zoxide
    zsh
  )
  pacman_install_pkgs

  # Set some configs for yay
  yay --save --nocleanmenu --nodiffmenu --noupgrademenu --noremovemake

  pkgs=(
    gitflow-avh
    icdiff
    lf-bin
    navi
    urlview
    xsv
  )
  aur_install_pkgs

  install_linuxbrew
  install_nix_brew_runtimes

  basic_env_setup
  apply_linux_app_configs
  fix_ENOSPC
}

prepare_arch_env_cli_extra()
{
  pkgs=(
    android-tools
    aria2
    axel
    bat
    calcurse
    cloc
    cmake
    cmatrix
    cmus
    cowsay
    cpanminus
    cpulimit
    dnsmasq
    docker
    docker-compose
    dstat
    duf
    ebtables
    ffmpeg
    ffmpegthumbnailer
    figlet
    fish
    flatpak
    fortune-mod
    gdu
    gifsicle
    git-lfs
    github-cli
    gitui
    glances
    glow-bin
    go
    gping
    graphviz
    haproxy
    hashcat
    hexyl
    hub
    hyperfine
    iftop
    iptables-nft
    irssi
    jdk-openjdk
    jpegoptim
    kubectl
    lazygit
    libvirt
    lolcat
    mc
    mediainfo
    minikube
    mpc
    mpd
    mps-youtube
    mpv
    multitail
    mutt
    ncdu
    ncmpcpp
    nghttp2
    nyancat
    offlineimap
    onefetch
    optipng
    p7zip
    pamixer
    pandoc
    perl-image-exiftool
    pkgfile
    playerctl
    pngquant
    progress
    proxychains-ng
    qemu
    ripgrep
    shadowsocks-libev
    shellcheck
    sl
    snapd
    translate-shell
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
    cheat-bin
    dive
    downgrader
    fpp
    fswatch
    git-bug-bin
    git-quick-stats
    lazydocker-bin
    lazynpm
    mons
    mycli
    nb
    ocrmypdf
    pgcli
    polipo
    sc-im
    sparklines-git
    touchpad-state-git
    ttf-weather-icons
  )
  aur_install_pkgs

  extra_env_setup

  sudo systemctl enable --now snapd.socket # enable snapd
}

prepare_arch_env_gui_core()
{
  pkgs=(
    alacritty
    appmenu-gtk-module
    arandr
    blueman
    chromium
    compton
    fcitx
    fcitx-configtool
    fcitx-im
    fcitx-rime
    feh
    firefox
    flameshot
    foliate
    galculator
    gsimplecal
    i3-gaps
    i3blocks
    i3status
    libdbusmenu-glib
    libdbusmenu-gtk2
    libdbusmenu-gtk3
    lxappearance
    lxsession
    lxtask
    maim
    network-manager-applet
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    pa-applet
    polybar
    python-pywal
    redshift
    rofi
    rofi-scripts
    thunar
    thunar-archive-plugin
    thunar-media-tags-plugin
    thunar-shares-plugin
    thunar-volman
    ttf-font-awesome
    ttf-sarasa-gothic
    tumbler
    udiskie
    vala-panel-appmenu-xfce
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
    jumpapp
    nerd-fonts-fira-code
    nerd-fonts-meslo
    nerd-fonts-source-code-pro
    sublime-merge
    sublime-text-4
    visual-studio-code-bin
    xgetres
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
    arc-gtk-theme
    arc-icon-theme
    atom
    chromium
    copyq
    drawing
    file-roller
    handbrake
    hardinfo
    kdiff3
    keepassxc
    kitty
    materia-gtk-theme
    neofetch
    pdfarranger
    qutebrowser
    rxvt-unicode
    shadowsocks-qt5
    syncthing-gtk
    telegram-desktop
    termite
    tilda
    virt-manager
    virtualbox
    winetricks
    wkhtmltopdf
    xcursor-simpleandsoft
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
    feedreader
    feishu-bin
    genymotion
    git-cola
    google-chrome-stable
    joplin
    kitematic
    losslesscut
    mailspring
    marktext-bin
    musixmatch-bin
    qv2ray-static-bin-nightly
    rslsync
    screenkey
    skypeforlinux-stable-bin
    slack-desktop
    spotify
    ttf-ms-fonts
    urxvt-fullscreen
    urxvt-resize-font-git
    whatsapp-web-desktop
  )
  aur_install_pkgs
}

setup_arch_gaming()
{
  pkgs=(
    desmume
    dosbox
    higan
    mame
    openra
    pcsx2
    ppsspp
    snes9x-gtk
    vbam-wx
  )
  pacman_install_pkgs

  pkgs=(
    dosbox-x
  )
  aur_install_pkgs
}

set_default_apps()
{
  xdg-mime default chromium.desktop x-scheme-handler/http
  xdg-mime default chromium.desktop x-scheme-handler/https
  xdg-mime default Thunar.desktop inode/directory
}
