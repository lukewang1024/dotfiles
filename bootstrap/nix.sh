install_nix_brew_runtimes()
{
  local pkgs=(
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
    bash
    broot
    diff-so-fancy
    dog
    fd
    findutils
    fzf
    git
    git-delta
    git-extras
    git-flow-avh
    htop
    httpie
    icdiff
    imagemagick
    jless
    jq
    less
    lf
    lsd
    micro
    navi
    neovim
    openssh
    peco
    prettyping
    procs
    ranger
    ripgrep
    rsync
    starship
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
    zoxide
    zsh
  )
  brew install `join ' ' "${pkgs[@]}"`
}

install_nix_brew_extra_packages()
{
  brew tap abhimanyu003/sttr     # sttr
  brew tap clangen/musikcube     # musikcube
  brew tap egoist/tap            # dum
  brew tap jesseduffield/lazynpm # lazynpm
  brew tap wader/tap             # fq
  brew tap xwmx/taps             # nb

  local pkgs=(
    ansifilter
    aria2
    axel
    bash-completion
    bat
    binutils
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
    helix
    hexyl
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
    musikcube
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
    privoxy
    progress
    proxychains-ng
    qpdf
    redis
    rtv
    sc-im
    scc
    shellcheck
    sl
    smartmontools
    spark
    sttr
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
    websocat
    wtf
    wtfutil
    xpdf
    yarn
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
