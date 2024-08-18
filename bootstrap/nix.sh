install_nix_brew_runtimes()
{
  local pkgs=(
    anyenv
    deno
    go
    node
    php
    python
    ruby
  )
  brew install `join ' ' "${pkgs[@]}"`
}

install_nix_brew_core_packages()
{
  brew tap beeftornado/rmtree

  local pkgs=(
    diff-so-fancy
    fd
    findutils
    fx
    fzf
    git
    htop
    httpie
    jq
    less
    lf
    lsd
    navi
    openssh
    peco
    prettyping
    procs
    ripgrep
    rsync
    the_silver_searcher
    tig
    tldr
    tmux
    trash-cli
    unar
    urlview
    vim
    wget
    xsv
    yazi
    zoxide
    zsh
  )
  brew install `join ' ' "${pkgs[@]}"`
}

install_nix_brew_extra_packages()
{
  brew tap abhimanyu003/sttr     # sttr
  brew tap anhoder/go-musicfox   # go-musicfox & spotifox
  brew tap clangen/musikcube     # musikcube
  brew tap egoist/tap            # dum
  brew tap jesseduffield/lazynpm # lazynpm
  brew tap textualize/homebrew   # frogmouth
  brew tap wader/tap             # fq
  brew tap xwmx/taps             # nb
  brew tap jstkdng/programs      # ueberzugpp

  local pkgs=(
    ansifilter
    aria2
    ata
    autossh
    axel
    bash
    bash-completion
    bat
    binutils
    broot
    c2048
    calcurse
    cheat
    checkbashisms
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
    dog
    duf
    dum
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
    fq
    frogmouth
    fswatch
    gawk
    gdu
    gh
    ghi
    gifsicle
    gist
    git-appraise
    git-delta
    git-extras
    git-filter-repo
    git-flow-avh
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
    go-musicfox
    googler
    gping
    graphviz
    grep
    gzip
    haproxy
    hashcat
    helix
    hexyl
    httpstat
    hub
    hyperfine
    icdiff
    iftop
    imagemagick
    inetutils
    irssi
    jless
    jpegoptim
    kubernetes-cli
    lazydocker
    lazygit
    lazynpm
    lolcat
    mailsy
    make
    media-info
    micro
    midnight-commander
    minikube
    mkcert
    mosh
    mpc
    mpd
    mps-youtube
    mpv
    multitail
    musikcube
    mutt
    mycli
    nb
    ncdu
    ncmpcpp
    neofetch
    neovim
    netcat
    nmap
    ntfy
    nyancat
    ocrmypdf
    offlineimap
    oha
    onefetch
    open-mpi
    optipng
    p7zip
    pandoc
    pdfsandwich
    pgcli
    pngquant
    pnpm
    polipo
    poppler
    privoxy
    progress
    proxychains-ng
    qpdf
    ranger
    redis
    rtv
    sc-im
    scc
    shellcheck
    sl
    smartmontools
    spark
    speedtest-cli
    spotifox
    starship
    sttr
    taskell
    tesseract
    tesseract-lang
    testdisk
    thefuck
    tmate
    tmuxinator
    toolong
    tpp
    translate-shell
    tree
    ueberzugpp
    unzip
    w3m
    watch
    wdiff
    websocat
    whistle
    wifi-password
    wtf
    wtfutil
    xpdf
    yarn
    you-get
    yt-dlp
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
  backup_then_symlink "$config_dir/conda" ~/.config/conda
  backup_then_symlink "$config_dir/gitui" ~/.config/gitui
  backup_then_symlink "$config_dir/htop" ~/.config/htop
  backup_then_symlink "$config_dir/kitty" ~/.config/kitty
  backup_then_symlink "$config_dir/lf" ~/.config/lf
  backup_then_symlink "$config_dir/starship/starship.toml" ~/.config/starship.toml
}

brew_cleanup()
{
  brew cleanup
}

brew_bundle_cleanup()
{
  brew bundle dump && brew bundle --force cleanup
}
