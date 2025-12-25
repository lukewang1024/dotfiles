install_nix_brew_runtimes()
{
  local pkgs=(
    anyenv                            # All in one for **env
    deno                              # Secure runtime for JavaScript and TypeScript
    go                                # Open source programming language to build simple/reliable/efficient software
    node                              # Platform built on V8 to build network applications
    php                               # General-purpose scripting language
    pipx                              # Execute binaries from Python packages in isolated environments
    pnpm                              # Fast, disk space efficient package manager
    python                            # Interpreted, interactive, object-oriented programming language
    python-tk                         # Python interface to Tcl/Tk
    ruby                              # Powerful, clean, object-oriented scripting language
    uv                                # Extremely fast Python package installer and resolver, written in Rust
    yarn                              # JavaScript package manager
  )
  brew install `join ' ' "${pkgs[@]}"`
}

install_nix_brew_core_packages()
{
  brew tap beeftornado/rmtree

  local pkgs=(
    btop                              # Resource monitor. C++ version and continuation of bashtop and bpytop
    diff-so-fancy                     # Good-lookin' diffs with diff-highlight and more
    docker                            # Pack, ship and run any application as a lightweight container
    docker-buildx                     # Docker CLI plugin for extended build capabilities with BuildKit
    docker-compose                    # Isolated development environments using Docker
    fd                                # Simple, fast and user-friendly alternative to find
    findutils                         # Collection of GNU find, xargs, and locate
    fx                                # Terminal JSON viewer
    fzf                               # Command-line fuzzy finder written in Go
    git                               # Distributed revision control system
    httpie                            # User-friendly cURL replacement (command-line HTTP client)
    jq                                # Lightweight and flexible command-line JSON processor
    lazydocker                        # Lazier way to manage everything docker
    lazygit                           # Simple terminal UI for git commands
    less                              # Pager program similar to more
    lf                                # Terminal file manager
    lsd                               # Clone of ls with colorful output, file type icons, and more
    navi                              # Interactive cheatsheet tool for the command-line
    openssh                           # OpenBSD freely-licensed SSH connectivity tools
    peco                              # Simplistic interactive filtering tool
    prettyping                        # Wrapper to colorize and simplify ping's output
    procs                             # Modern replacement for ps written in Rust
    ripgrep                           # Search tool like grep and The Silver Searcher
    rsync                             # Utility that provides fast incremental file transfer
    tealdeer                          # Very fast implementation of tldr in Rust
    the_silver_searcher               # Code-search similar to ack
    tig                               # Text interface for Git repositories
    tmux                              # Terminal multiplexer
    trash-cli                         # Command-line interface to the freedesktop.org trashcan
    unar                              # Command-line unarchiving tools supporting multiple formats
    urlview                           # URL extractor/launcher
    vim                               # Vi 'workalike' with many additional features
    wget                              # Internet file retriever
    yazi                              # Blazing fast terminal file manager written in Rust, based on async I/O
    zoxide                            # Shell extension to navigate your filesystem faster
    zsh                               # UNIX shell (command interpreter)
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
    ansifilter                        # Strip or convert ANSI codes into HTML, (La)Tex, RTF, or BBCode
    aria2                             # Download with resuming and segmented downloading
    ata                               # ChatGPT in the terminal
    autossh                           # Automatically restart SSH sessions and tunnels
    axel                              # Light UNIX download accelerator
    bash                              # Bourne-Again SHell, a UNIX command interpreter
    bash-completion                   # Programmable completion for Bash 3.2
    bat                               # Clone of cat(1) with syntax highlighting and Git integration
    binutils                          # GNU binary tools for native development
    broot                             # New way to see and navigate directory trees
    c2048                             # Console version of 2048
    calcurse                          # Text-based personal organizer
    cheat                             # Create and view interactive cheat sheets for *nix commands
    checkbashisms                     # Checks for bashisms in shell scripts
    cmake                             # Cross-platform make
    cmatrix                           # Console Matrix
    cmus                              # Music player with an ncurses based interface
    coreutils                         # GNU File, Shell, and Text utilities
    cowsay                            # Apjanke's fork of the classic cowsay project
    cpanminus                         # Get, unpack, build, and install modules from CPAN
    cpulimit                          # CPU usage limiter
    ddgr                              # DuckDuckGo from the terminal
    diffutils                         # File comparison utilities
    dive                              # Tool for exploring each layer in a docker image
    dog                               # Command-line DNS client
    duf                               # Disk Usage/Free Utility - a better 'df' alternative
    dum                               # Npm scripts runner written in Rust
    ed                                # Classic UNIX line editor
    emscripten                        # LLVM bytecode to JavaScript compiler
    exiftool                          # Perl lib for reading and writing EXIF metadata
    extract_url                       # Perl script to extracts URLs from emails or plain text
    ffmpeg                            # Play, record, convert, and stream audio and video
    ffmpegthumbnailer                 # Create thumbnails for your video files
    figlet                            # Banner-like program prints strings as ASCII art
    file-formula                      # Utility to determine file types
    fish                              # User-friendly command-line shell for UNIX-like operating systems
    fpp                               # CLI program that accepts piped input and presents files for selection
    fq                                # Brokered message queue optimized for performance
    frogmouth                         # Terminal browser for markdown documents
    fswatch                           # Monitor a directory for changes and run a shell command
    gawk                              # GNU awk utility
    gdu                               # Disk usage analyzer with console interface written in Go
    gh                                # GitHub command-line tool
    ghi                               # Work on GitHub issues on the command-line
    gifsicle                          # GIF image/animation creator/editor
    gist                              # Command-line utility for uploading Gists
    git-appraise                      # Distributed code review system for Git repos
    git-delta                         # Syntax-highlighting pager for git and diff output
    git-extras                        # Small git utilities
    git-filter-repo                   # Quickly rewrite git repository history
    git-flow-avh                      # AVH edition of git-flow
    git-lfs                           # Git extension for versioning large files
    git-quick-stats                   # Simple and efficient way to access statistics in git
    gitui                             # Blazing fast terminal-ui for git written in rust
    glances                           # Alternative to top/htop
    glow                              # Render markdown on the CLI
    gnu-indent                        # C code prettifier
    gnu-sed                           # GNU implementation of the famous stream editor
    gnu-tar                           # GNU version of the tar archiving utility
    gnu-which                         # GNU implementation of which utility
    gnutls                            # GNU Transport Layer Security (TLS) Library
    go-musicfox                       # Music player in terminal (special tap)
    googler                           # Google search from terminal (special tap)
    gping                             # Ping, but with a graph
    graphviz                          # Graph visualization software from AT&T and Bell Labs
    grep                              # GNU grep, egrep and fgrep
    gzip                              # Popular GNU data compression program
    haproxy                           # Reliable, high performance TCP/HTTP load balancer
    hashcat                           # World's fastest and most advanced password recovery utility
    helix                             # Post-modern modal text editor
    hexyl                             # Command-line hex viewer
    htop                              # Improved top (interactive process viewer)
    httpstat                          # Curl statistics made simple
    hub                               # Add GitHub support to git on the command-line
    hyperfine                         # Command-line benchmarking tool
    icdiff                            # Improved colored diff
    iftop                             # Display an interface's bandwidth usage
    imagemagick                       # Tools and libraries to manipulate images in many formats
    inetutils                         # GNU utilities for networking
    irssi                             # Modular IRC client
    jless                             # Command-line pager for JSON data
    jpegoptim                         # Utility to optimize JPEG files
    kubernetes-cli                    # Kubernetes command-line interface
    lazynpm                           # NPM scripts runner (special tap)
    lolcat                            # Rainbows and unicorns in your console!
    mailsy                            # Quickly generate a temporary email address
    make                              # Utility for directing compilation
    media-info                        # Unified display of technical and tag data for audio/video
    micro                             # Modern and intuitive terminal-based text editor
    midnight-commander                # Terminal-based visual file manager
    minikube                          # Run a Kubernetes cluster locally
    mkcert                            # Simple tool to make locally trusted development certificates
    mosh                              # Remote terminal application
    mpc                               # Command-line music player client for mpd
    mpd                               # Music Player Daemon
    mps-youtube                       # Terminal based YouTube player and downloader
    mpv                               # Media player based on MPlayer and mplayer2
    multitail                         # Tail multiple files in one terminal simultaneously
    musikcube                         # Terminal-based audio engine, library, player and server
    mutt                              # Mongrel of mail user agents (part elm, pine, mush, mh, etc.)
    mycli                             # CLI for MySQL with auto-completion and syntax highlighting
    nb                                # Command-line and local web note-taking, bookmarking, and archiving
    ncdu                              # NCurses Disk Usage
    ncmpcpp                           # Ncurses-based client for the Music Player Daemon
    neofetch                          # Fast, highly customisable system info script
    neovim                            # Ambitious Vim-fork focused on extensibility and agility
    netcat                            # Utility for managing network connections
    nmap                              # Port scanning utility for large networks
    nnn                               # Tiny, lightning fast, feature-packed file manager
    ntfy                              # Send push notifications to your phone or desktop via PUT/POST
    nyancat                           # Renders an animated, color, ANSI-text loop of the Poptart Cat
    ocrmypdf                          # Adds an OCR text layer to scanned PDF files
    offlineimap                       # Synchronizes emails between two repositories
    oha                               # HTTP load generator, inspired by rakyll/hey with tui animation
    onefetch                          # Command-line Git information tool
    open-mpi                          # High performance message passing library
    optipng                           # PNG file optimizer
    p7zip                             # 7-Zip (high compression file archiver) implementation
    pandoc                            # Swiss-army knife of markup format conversion
    pdfsandwich                       # Generate sandwich OCR PDFs from scanned file
    pgcli                             # CLI for Postgres with auto-completion and syntax highlighting
    pngquant                          # PNG image optimizing utility
    polipo                            # Lightweight web proxy (package unavailable)
    poppler                           # PDF rendering library (based on the xpdf-3.0 code base)
    privoxy                           # Advanced filtering web proxy
    progress                          # Coreutils progress viewer
    proxychains-ng                    # Hook preloader
    qpdf                              # Tools for and transforming and inspecting PDF files
    ranger                            # File browser
    redis                             # Persistent key-value database, with built-in net interface
    resvg                             # SVG rendering tool and library
    rtv                               # Reddit terminal viewer (package unavailable)
    sc-im                             # Spreadsheet program for the terminal, using ncurses
    scc                               # Fast and accurate code counter with complexity and COCOMO estimates
    sevenzip                          # 7-Zip is a file archiver with a high compression ratio
    shellcheck                        # Static analysis and lint tool, for (ba)sh scripts
    sl                                # Prints a steam locomotive if you type sl instead of ls
    smartmontools                     # SMART hard drive monitoring
    sniffnet                          # Cross-platform application to monitor your network traffic
    spark                             # Sparklines for the shell
    speedtest-cli                     # Command-line interface for https://speedtest.net bandwidth tests
    spotifox                          # Spotify player (special tap)
    starship                          # Cross-shell prompt for astronauts
    sttr                              # CLI to perform various operations on string
    taskell                           # Command-line Kanban board/task manager with support for Trello
    tesseract                         # OCR (Optical Character Recognition) engine
    tesseract-lang                    # Enables extra languages support for Tesseract
    testdisk                          # Powerful free data recovery utility
    thefuck                           # Programmatically correct mistyped console commands
    tmate                             # Instant terminal sharing
    tmuxinator                        # Manage complex tmux sessions easily
    toolong                           # Terminal log viewer (special tap)
    tpp                               # Terminal presentation tool (special tap)
    translate-shell                   # Command-line translator using Google Translate and more
    tree                              # Display directories as trees (with optional color/HTML output)
    ueberzugpp                        # Command line tool for displaying images (special tap)
    unzip                             # Extraction utility for .zip compressed archives
    w3m                               # Pager/text based browser
    watch                             # Executes a program periodically, showing output fullscreen
    wdiff                             # Display word differences between text files
    websocat                          # Command-line client for WebSockets
    whistle                           # HTTP, HTTP2, HTTPS, Websocket debugging proxy
    wifi-password                     # Show the current WiFi network password
    wtf                               # Translate common Internet acronyms
    wtfutil                           # Personal information dashboard for your terminal
    xan                               # CSV CLI magician written in Rust
    xdg-ninja                         # Check your $HOME for unwanted files and directories
    xpdf                              # PDF viewer
    you-get                           # Dumb downloader that scrapes the web
    yt-dlp                            # Feature-rich command-line audio/video downloader
    zsh-completions                   # Additional completion definitions for zsh
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
  backup_then_symlink "$config_dir/percol" ~/.config/percol
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
