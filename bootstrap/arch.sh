source "$partial_dir/env.sh"

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
    aws-cli
    axel
    cloc
    cmatrix
    cowsay
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
    multitail
    mutt
    nghttp2
    offlineimap
    openssh
    p7zip
    pacaur
    polipo
    ranger
    readline
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
    git-lfs
    gitflow-avh
    google-cloud-sdk
    heroku-cli
    icdiff
    mycli
    nerd-fonts-complete
    peco
    sparklines-git
    translate-shell
  )
  aurInstallPkgs

  installLinuxBrew
  installLinuxBrewBuildTools
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
    keepass
    neofetch
    network-manager-applet
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
    wkhtmltopdf
    xcape
    xorg-xdpyinfo
    xorg-xprop
    xorg-xrandr
    xorg-xwininfo
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
    electronic-wechat
    etcher
    feedreader
    genymotion
    git-cola
    google-chrome
    i3lock-color
    keepass-plugin-qualitycolumn
    keepass-plugin-quickunlock
    kitematic
    losslesscut
    mailspring
    python-pywal
    skypeforlinux-stable-bin
    slack-desktop
    spotify
    todoist
    ttf-ms-fonts
    visual-studio-code-bin
    whatsapp-desktop
  )
  aurInstallPkgs
}
