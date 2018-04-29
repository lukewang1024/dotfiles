source "$partial_dir/env.sh"
source "$partial_dir/linux.sh"

configPacman()
{
  timedatectl set-ntp true
  sudo pacman-mirrors -c Hong_Kong,Taiwan
}

pacmanInstallPkgs()
{
  sudo pacman -Sy --needed --noconfirm `join ' ' "${pkgs[@]}"`
  unset pkgs
}

aurInstallPkgs()
{
  pacaur -Sy --needed --noconfirm --noedit `join ' ' "aur/${pkgs[@]}"`
  unset pkgs
}

prepareArchEnvCLI()
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
  pacmanInstallPkgs

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
  aurInstallPkgs

  installLinuxBrew
  installNixBrewRuntimes

  envSetup
  applyAppConfigs

  sudo systemctl enable --now snapd.socket # enable snapd
}

addSublimeTextRepo()
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

prepareArchEnvGUI()
{
  addSublimeTextRepo

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
    xcape
    xorg-apps
    zathura
    zathura-cb
    zathura-djvu
    zathura-pdf-mupdf
    zathura-ps
    zeal
  )
  pacmanInstallPkgs

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
  aurInstallPkgs

  setDefaultApps
}

setupArchGaming()
{
  pkgs=(
    retroarch
    retroarch-assets-xmb
    retroarch-autoconfig-udev
  )
  pacmanInstallPkgs

  pkgs=(
    emulationstation
    libretro-mame-git
  )
  aurInstallPkgs
}

setDefaultApps()
{
  xdg-mime default nemo.desktop inode/directory
  xdg-mime default chromium.desktop x-scheme-handler/http
  xdg-mime default chromium.desktop x-scheme-handler/https
}
