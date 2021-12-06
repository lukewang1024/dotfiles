install_nix_brew_runtimes()
{
  local pkgs=(
    deno
    go
    node
    php
    python
    python@2
    ruby
  )
  brew install `join ' ' "${pkgs[@]}"`
}

install_nix_brew_core_packages()
{
  brew tap beeftornado/rmtree

  local pkgs=(
    bash
    broot
    diff-so-fancy
    dog
    fasd
    fd
    findutils
    fzf
    git
    git-extras
    git-flow-avh
    htop
    httpie
    icdiff
    imagemagick
    jq
    less
    lf
    lsd
    micro
    navi
    neovim
    openssh
    peco
    percol
    prettyping
    ranger
    ripgrep
    rsync
    the_silver_searcher
    tig
    tldr
    tmux
    tmuxinator
    trash-cli
    urlview
    vim
    wdiff
    wget
    xsv
    yarn
    zsh
  )
  brew install `join ' ' "${pkgs[@]}"`
}

install_nix_brew_extra_packages()
{
  brew tap jesseduffield/lazynpm
  brew tap xwmx/taps

  local pkgs=(
    ansifilter
    apache-spark
    aria2
    awscli
    axel
    azure-cli
    bash-completion
    bat
    binutils
    calcurse
    cheat
    cmake
    cmatrix
    cmus
    coreutils
    cowsay
    cpanminus
    cpulimit
    ddgr
    diffutils
    dive
    duf
    ed
    emscripten
    exiftool
    extract_url
    ffmpeg
    ffmpegthumbnailer
    figlet
    file-formula
    fish
    fpp
    fswatch
    gawk
    gdu
    gh
    ghi
    gifsicle
    gist
    git-appraise
    git-filter-repo
    git-lfs
    git-quick-stats
    gitui
    glances
    glow
    gnu-indent
    gnu-sed
    gnu-tar
    gnu-which
    gnutls
    googler
    gping
    graphviz
    grep
    gzip
    haproxy
    hashcat
    httpstat
    hub
    hyperfine
    iftop
    inetutils
    irssi
    jpegoptim
    kubernetes-cli
    lazydocker
    lazygit
    lazynpm
    lolcat
    make
    media-info
    midnight-commander
    minikube
    mkcert
    mosh
    mpc
    mpd
    mps-youtube
    mpv
    multitail
    mutt
    mycli
    nb
    ncdu
    ncmpcpp
    neofetch
    netcat
    nmap
    nyancat
    ocrmypdf
    offlineimap
    onefetch
    open-mpi
    optipng
    p7zip
    pandoc
    pgcli
    pngquant
    progress
    proxychains-ng
    qpdf
    redis
    rtv
    sachaos/todoist/todoist
    sc-im
    scc
    shadowsocks-libev
    shellcheck
    sl
    spark
    tesseract
    tesseract-lang
    testdisk
    thefuck
    tmate
    tpp
    translate-shell
    tree
    unzip
    w3m
    watch
    wtf
    wtfutil
    xpdf
    you-get
    youtube-dl
    zsh-completions
  )
  brew install `join ' ' "${pkgs[@]}"`
}

install_nix_brew_packages()
{
  install_nix_brew_core_packages
  install_nix_brew_extra_packages
}

apply_nix_app_configs()
{
  backup_then_symlink "$config_dir/alacritty" ~/.config/alacritty
  backup_then_symlink "$config_dir/kitty" ~/.config/kitty
  backup_then_symlink "$config_dir/lf" ~/.config/lf
}

brew_cleanup()
{
  brew cleanup
}

brew_bundle_cleanup()
{
  brew bundle dump && brew bundle --force cleanup
}
