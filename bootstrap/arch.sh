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
  pacaur -Sy --needed --noconfirm --noedit `join ' ' "aur/${pkgs[@]}"`
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
    pacaur
    pamixer
    pandoc
    playerctl
    polipo
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
    unzip
    vagrant
    vim
    w3m
    wget
    wtf
    yaourt
    yarn
    you-get
    zip
    zsh
  )
  pacman_install_pkgs

  pkgs=(
    apache-spark
    cheat-git
    fswatch
    git-lfs
    gitflow-avh
    google-cloud-sdk
    heroku-cli
    icdiff
    mons
    mycli
    peco
    sparklines-git
    translate-shell
    ttf-weather-icons
    urlview
  )
  aur_install_pkgs

  install_linuxbrew
  install_nix_brew_runtimes

  env_setup
  apply_app_configs

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
    i3-gaps
    i3blocks
    i3status
    kdiff3
    keepassxc
    lxappearance
    nemo
    nemo-bulk-rename
    nemo-fileroller
    nemo-image-converter
    nemo-preview
    nemo-seahorse
    nemo-share
    neofetch
    network-manager-applet
    pa-applet
    polybar
    redshift
    rofi
    rofi-scripts
    rxvt-unicode
    scrot
    shadowsocks-qt5
    sublime-text
    telegram-desktop
    termite
    tilda
    ttf-font-awesome
    wkhtmltopdf
    wqy-zenhei
    xbindkeys
    xcape
    xorg-apps
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
    dropbox
    etcher
    feedreader
    genymotion
    git-cola
    i3lock-color
    kitematic
    losslesscut
    mailspring
    musixmatch-bin
    nerd-fonts-complete
    python-pywal
    screenkey
    skypeforlinux-stable-bin
    slack-desktop
    spotify
    spotify-adkiller-dns-block-git
    todoist
    ttf-ms-fonts
    urxvt-fullscreen
    urxvt-resize-font-git
    visual-studio-code-bin
    whatsapp-desktop
  )
  aur_install_pkgs

  install_i3ass
  set_default_apps
}

setup_arch_gaming()
{
  pkgs=(
    retroarch
    retroarch-assets-xmb
    retroarch-autoconfig-udev
  )
  pacman_install_pkgs

  pkgs=(
    emulationstation
    libretro-mame-git
  )
  aur_install_pkgs
}

set_default_apps()
{
  xdg-mime default nemo.desktop inode/directory
  xdg-mime default chromium.desktop x-scheme-handler/http
  xdg-mime default chromium.desktop x-scheme-handler/https
}
