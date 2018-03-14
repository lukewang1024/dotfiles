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
  pacaur -Sy --needed --noconfirm --noedit `join ' ' "${pkgs[@]}"`
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
    dstat
    fasd
    fcitx
    fcitx-im
    fcitx-rime
    figlet
    fish
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
    multitail
    mutt
    nghttp2
    nodejs
    npm
    offlineimap
    openssh
    p7zip
    pacaur
    polipo
    python
    python-pip
    python2
    python2-pip
    readline
    rsync
    ruby
    shadowsocks-libev
    the_silver_searcher
    tig
    tldr
    tmux
    tree
    unzip
    vim
    w3m
    wget
    wtf
    xcape
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
    sparklines-git
    translate-shell
  )
  aurInstallPkgs

  envSetup
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
    atom
    chromium
    firefox
    firefox-developer-edition
    kdiff3
    keepass
    rofi
    screenfetch
    shadowsocks-qt5
    sublime-text
    wkhtmltopdf
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
    dropbox
    electronic-wechat
    etcher
    genymotion
    git-cola
    google-chrome
    keepass-plugin-qualitycolumn
    keepass-plugin-quickunlock
    losslesscut
    skypeforlinux-stable-bin
    visual-studio-code-bin
  )
  aurInstallPkgs
}
