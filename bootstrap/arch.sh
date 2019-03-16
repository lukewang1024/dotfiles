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
  yay -Sy --needed `join ' ' "aur/${pkgs[@]}"`
  unset pkgs
}

prepare_arch_env_cli()
{
  pkgs=(
    android-tools
    aria2
    aws-cli
    axel
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
    fasd
    figlet
    fish
    flatpak
    fortune-mod
    fzf
    gifsicle
    git
    go
    haproxy
    htop
    httpie
    imagemagick
    irssi
    jdk8-openjdk
    jdk9-openjdk
    jpegoptim
    jq
    lolcat
    mc
    mpc
    mpd
    mps-youtube
    mpv
    multitail
    mutt
    ncmpcpp
    nghttp2
    offlineimap
    openssh
    p7zip
    pamixer
    pandoc
    playerctl
    polipo
    progress
    proxychains-ng
    ranger
    rsync
    shadowsocks-libev
    shellcheck
    snapd
    the_silver_searcher
    tig
    tldr
    tmux
    transmission-cli
    tree
    unrar
    unzip
    vagrant
    vim
    w3m
    wget
    wtf
    yarn
    yay
    you-get
    zip
    zsh
  )
  pacman_install_pkgs

  # Set some configs for yay
  yay --save --nocleanmenu --nodiffmenu --noupgrademenu --noremovemake

  pkgs=(
    apache-spark
    cheat-git
    downgrader
    fswatch
    git-lfs
    gitflow-avh
    google-cloud-sdk
    icdiff
    mons
    mycli
    peco
    pgcli
    sparklines-git
    touchpad-state-git
    translate-shell
    ttf-weather-icons
    urlview
    wsta
  )
  aur_install_pkgs

  install_linuxbrew
  install_nix_brew_runtimes

  env_setup
  apply_app_configs
  fix_ENOSPC

  sudo systemctl enable --now snapd.socket # enable snapd
}

add_sublime_text_repo()
{
  if ! grep -q '\[sublime-text\]' /etc/pacman.conf; then
    curl -O https://download.sublimetext.com/sublimehq-pub.gpg && \
      sudo pacman-key --add sublimehq-pub.gpg && \
      sudo pacman-key --lsign-key 8A8F901A && \
      rm sublimehq-pub.gpg

    echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" | sudo tee -a /etc/pacman.conf
  else
    echo 'Sublime Text repository has been added. Skip.'
  fi
}

prepare_arch_env_gui()
{
  add_sublime_text_repo

  pkgs=(
    android-file-transfer
    arandr
    atom
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
    handbrake
    hardinfo
    i3-gaps
    i3blocks
    i3status
    kdiff3
    keepassxc
    lxappearance
    lxsession
    lxtask
    neofetch
    network-manager-applet
    noto-fonts-emoji
    pa-applet
    polybar
    qutebrowser
    redshift
    rofi
    rofi-scripts
    rxvt-unicode
    scrot
    shadowsocks-qt5
    sublime-text
    syncthing-gtk
    telegram-desktop
    termite
    thunar
    thunar-archive-plugin
    thunar-media-tags-plugin
    thunar-shares-plugin
    thunar-volman
    tilda
    ttf-font-awesome
    udiskie
    winetricks
    wkhtmltopdf
    wqy-zenhei
    xautomation
    xbindkeys
    xcape
    xorg-apps
    xscreensaver
    zathura
    zathura-cb
    zathura-djvu
    zathura-pdf-mupdf
    zathura-ps
    zeal
  )
  pacman_install_pkgs

  pkgs=(
    android-sdk
    android-sdk-platform-tools
    android-studio
    betterlockscreen
    deepin-wechat
    deepin-wine-tim
    dropbox
    etcher-bin
    feedreader
    genymotion
    git-cola
    gluqlo-git
    google-chrome-stable
    i3ass
    i3lock-color
    kitematic
    losslesscut
    mailspring
    musixmatch-bin
    nerd-fonts-complete
    notable-bin
    python-pywal
    rslsync
    screenkey
    skypeforlinux-stable-bin
    slack-desktop
    spotify
    spotify-adkiller-dns-block-git
    sublime-merge
    ttf-ms-fonts
    typora
    urxvt-fullscreen
    urxvt-resize-font-git
    visual-studio-code-bin
    whatsapp-web-desktop
    xinit-xsession
  )
  aur_install_pkgs

  set_default_apps
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
