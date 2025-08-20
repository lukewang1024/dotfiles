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
    diff-so-fancy                     # Good-lookin' diffs with diff-highlight and more
    fd                                # Simple, fast and user-friendly alternative to find
    fx                                # Terminal JSON viewer
    fzf                               # Command-line fuzzy finder written in Go
    git                               # Distributed revision control system
    htop                              # Improved top (interactive process viewer)
    httpie                            # User-friendly cURL replacement (command-line HTTP client)
    jq                                # Lightweight and flexible command-line JSON processor
    less                              # Pager program similar to more
    lsd                               # Clone of ls with colorful output, file type icons, and more
    openssh                           # OpenBSD freely-licensed SSH connectivity tools
    pamac-cli                         # Command-line package manager for Arch Linux
    peco                              # Simplistic interactive filtering tool
    prettyping                        # Wrapper to colorize and simplify ping's output
    privoxy                           # Advanced filtering web proxy
    procs                             # Modern replacement for ps written in Rust
    ripgrep                           # Search tool like grep and The Silver Searcher
    rsync                             # Utility that provides fast incremental file transfer
    tealdeer                          # Very fast implementation of tldr in Rust
    the_silver_searcher               # Code-search similar to ack
    tig                               # Text interface for Git repositories
    tmux                              # Terminal multiplexer
    trash-cli                         # Command-line interface to the freedesktop.org trashcan
    unarchiver                        # Command-line unarchiving tools
    vim                               # Vi 'workalike' with many additional features
    wget                              # Internet file retriever
    yay                               # AUR helper for Arch Linux
    yazi                              # Blazing fast terminal file manager written in Rust
    zoxide                            # Shell extension to navigate your filesystem faster
    zsh                               # UNIX shell (command interpreter)
  )
  pacman_install_pkgs

  # Set some configs for yay
  yay --save --nocleanmenu --nodiffmenu --noupgrademenu --noremovemake

  pkgs=(
    find-the-command                  # Find which package provides a command
    lf-bin                            # Terminal file manager
    navi                              # Interactive cheatsheet tool for the command-line
    urlview                           # URL extractor/launcher
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
    android-tools                     # Android SDK platform tools for device communication
    aria2                             # Multi-protocol download utility with parallel downloading
    autossh                           # Automatically restart SSH sessions and tunnels
    axel                              # Light UNIX download accelerator
    bat                               # Clone of cat(1) with syntax highlighting and Git integration
    broot                             # New way to see and navigate directory trees
    calcurse                          # Text-based personal organizer
    checkbashisms                     # Checks for bashisms in shell scripts
    cloc                              # Count Lines of Code - counts source code lines
    cmake                             # Cross-platform make
    cmatrix                           # Console Matrix
    cmus                              # Music player with an ncurses based interface
    cowsay                            # Configurable speaking/thinking cow
    cpanminus                         # Get, unpack, build, and install modules from CPAN
    cpulimit                          # CPU usage limiter
    dnsmasq                           # Lightweight DNS forwarder and DHCP server
    docker                            # Pack, ship and run any application as a lightweight container
    docker-compose                    # Tool for defining and running multi-container Docker applications
    dog                               # Command-line DNS client
    dstat                             # System resource statistics tool
    duf                               # Disk Usage/Free Utility - a better 'df' alternative
    ebtables                          # Ethernet bridge frame table administration
    ffmpeg                            # Play, record, convert, and stream audio and video
    ffmpegthumbnailer                 # Create thumbnails for your video files
    figlet                            # Banner-like program prints strings as ASCII art
    fish                              # User-friendly command-line shell for UNIX-like operating systems
    flatpak                           # Linux application distribution framework
    fortune-mod                       # Fortune cookie program with fortune database
    fq                                # jq for binary formats
    frogmouth                         # Terminal browser for Markdown documents
    gdu                               # Disk usage analyzer with console interface written in Go
    gifsicle                          # GIF image/animation creator/editor
    git-delta                         # Syntax-highlighting pager for git and diff output
    git-lfs                           # Git extension for versioning large files
    github-cli                        # GitHub command-line tool
    gitui                             # Blazing fast terminal-ui for git written in rust
    glances                           # Alternative to top/htop
    glow-bin                          # Render markdown on the CLI
    go                                # Open source programming language to build simple/reliable/efficient software
    gping                             # Ping, but with a graph
    graphviz                          # Graph visualization software from AT&T and Bell Labs
    haproxy                           # Reliable, high performance TCP/HTTP load balancer
    hashcat                           # World's fastest and most advanced password recovery utility
    helix                             # Post-modern modal text editor
    hexyl                             # Command-line hex viewer
    hub                               # Add GitHub support to git on the command-line
    hyperfine                         # Command-line benchmarking tool
    iftop                             # Display an interface's bandwidth usage
    imagemagick                       # Tools and libraries to manipulate images in many formats
    iptables-nft                      # Linux kernel packet control tool
    irssi                             # Modular IRC client
    jdk-openjdk                       # Open Java Development Kit
    jless                             # Command-line pager for JSON data
    jpegoptim                         # Utility to optimize JPEG files
    kubectl                           # Kubernetes command-line interface
    lazygit                           # Simple terminal UI for git commands
    libvirt                           # API for controlling virtualization engines
    lolcat                            # Rainbows and unicorns in your console!
    mc                                # Midnight Commander - visual file manager
    mediainfo                         # Unified display of technical and tag data for audio/video
    micro                             # Modern and intuitive terminal-based text editor
    minikube                          # Run a Kubernetes cluster locally
    mpc                               # Command-line music player client for mpd
    mpd                               # Music Player Daemon
    mps-youtube                       # Terminal based YouTube player and downloader
    mpv                               # Media player based on MPlayer and mplayer2
    multitail                         # Tail multiple files in one terminal simultaneously
    musikcube-bin                     # Terminal-based audio engine, library, player and server
    mutt                              # Mongrel of mail user agents
    ncdu                              # NCurses Disk Usage
    ncmpcpp                           # Ncurses-based client for the Music Player Daemon
    neovim                            # Ambitious Vim-fork focused on extensibility and agility
    nghttp2                           # HTTP/2 C library and tools
    ntfysh-bin                        # Send push notifications to your phone or desktop
    nyancat                           # Renders an animated, color, ANSI-text loop of the Poptart Cat
    offlineimap                       # Synchronizes emails between two repositories
    oha                               # HTTP load generator, inspired by rakyll/hey with tui animation
    onefetch                          # Command-line Git information tool
    optipng                           # PNG file optimizer
    p7zip                             # 7-Zip (high compression file archiver) implementation
    pamixer                           # PulseAudio command-line mixer
    pandoc-cli                        # Swiss-army knife of markup format conversion
    perl-image-exiftool               # Perl lib for reading and writing EXIF metadata
    pkgfile                           # Search files from packages in the official repositories
    playerctl                         # Command-line utility for controlling media players
    pngquant                          # PNG image optimizing utility
    poppler                           # PDF rendering library
    progress                          # Coreutils progress viewer
    proxychains-ng                    # Hook preloader
    qemu                              # Machine emulator and virtualizer
    ranger                            # File browser
    shellcheck                        # Static analysis and lint tool, for (ba)sh scripts
    sl                                # Prints a steam locomotive if you type sl instead of ls
    snapd                             # Service and tools for management of snap packages
    sniffnet                          # Cross-platform application to monitor your network traffic
    starship                          # Cross-shell prompt for astronauts
    toolong                           # Terminal log file viewer
    translate-shell                   # Command-line translator using Google Translate and more
    transmission-cli                  # Command-line BitTorrent client
    tree                              # Display directories as trees (with optional color/HTML output)
    unrar                             # RAR decompression program
    unzip                             # Extraction utility for .zip compressed archives
    v2ray                             # Platform for building proxies to bypass network restrictions
    v2ray-domain-list-community       # Community managed domain list for V2Ray
    v2ray-geoip                       # GeoIP for V2Ray
    vagrant                           # Tool for building and managing virtual machine environments
    w3m                               # Pager/text based browser
    websocat                          # Command-line client for WebSockets
    wtf                               # Translate common Internet acronyms
    xan                               # CSV CLI magician written in Rust
    you-get                           # Dumb downloader that scrapes the web
    yt-dlp                            # Feature-rich command-line audio/video downloader
    zip                               # Create, modify and extract files from ZIP archives
  )
  pacman_install_pkgs

  # Set some configs for yay
  yay --save --nocleanmenu --nodiffmenu --noupgrademenu --noremovemake

  pkgs=(
    cheat-bin                         # Create and view interactive cheat sheets for *nix commands
    dive                              # Tool for exploring each layer in a docker image
    downgrader                        # Downgrade packages on Arch Linux
    fpp                               # CLI program that accepts piped input and presents files for selection
    fswatch                           # Monitor a directory for changes and run a shell command
    git-bug-bin                       # Distributed bug tracker embedded in git
    git-quick-stats                   # Simple and efficient way to access statistics in git
    gitflow-avh                       # AVH edition of git-flow
    go-musicfox-bin                   # Music player in terminal
    google-cloud-cli                  # Google Cloud Command Line Interface
    icdiff                            # Improved colored diff
    lazydocker-bin                    # Lazier way to manage everything docker
    lazynpm                           # NPM scripts runner
    miniconda3                        # Minimal installer for conda
    mons                              # POSIX Shell script to quickly manage monitors on X
    mycli                             # CLI for MySQL with auto-completion and syntax highlighting
    nb                                # Command-line and local web note-taking, bookmarking, and archiving
    ocrmypdf                          # Adds an OCR text layer to scanned PDF files
    pdfsandwich                       # Generate sandwich OCR PDFs from scanned file
    pgcli                             # CLI for Postgres with auto-completion and syntax highlighting
    powershell-bin                    # Command-line shell and scripting language
    sc-im                             # Spreadsheet program for the terminal, using ncurses
    sparklines-git                    # Sparklines for the shell
    touchpad-state-git                # Script to check the state of the touchpad
    ttf-weather-icons                 # Weather icon font
    ueberzugpp                        # Command line tool for displaying images
    xdg-ninja                         # Check your $HOME for unwanted files and directories
  )
  aur_install_pkgs

  extra_env_setup

  sudo systemctl enable --now snapd.socket # enable snapd
}

prepare_arch_env_gui_core()
{
  pkgs=(
    alacritty                         # GPU-accelerated terminal emulator
    appmenu-gtk-module                # GTK module for exporting application menus
    arandr                            # Visual front end for XRandR
    autorandr                         # Auto-switch the display configuration
    blueman                           # GTK+ Bluetooth Manager
    dmenu                             # Dynamic menu for X
    dunst                             # Customizable and lightweight notification-daemon
    fcitx                             # Flexible Input Method Framework
    fcitx-configtool                  # Configuration tool for Fcitx
    fcitx-im                          # Input method module for Fcitx
    fcitx-rime                        # Rime input method engine for Fcitx
    feh                               # Fast and light imlib2-based image viewer
    firefox                           # Standalone web browser from mozilla.org
    flameshot                         # Powerful yet simple to use screenshot software
    foliate                           # Simple and modern GTK eBook reader
    galculator                        # GTK+ based scientific calculator
    gsimplecal                        # Simple and lightweight GTK calendar
    i3-wm                             # Improved tiling window manager
    libdbusmenu-glib                  # GLib library that implements the DBusMenu protocol
    libdbusmenu-gtk2                  # GTK2 library that implements the DBusMenu protocol
    libdbusmenu-gtk3                  # GTK3 library that implements the DBusMenu protocol
    lxappearance                      # Feature-rich GTK+ theme switcher
    lxsession                         # Standard-compliant X11 session manager
    lxtask                            # Lightweight task manager for LXDE
    maim                              # Utility to take a screenshot using imlib2
    network-manager-applet            # NetworkManager connection editor and applet
    noto-fonts                        # Google Noto TTF fonts
    noto-fonts-cjk                    # Google Noto CJK fonts
    noto-fonts-emoji                  # Google Noto emoji fonts
    pa-applet                         # PulseAudio system tray applet
    parcellite                        # Lightweight GTK+ clipboard manager
    picom                             # X compositor that may fix tearing issues
    polybar                           # Fast and easy-to-use status bar
    python-pywal                      # Generate and change colorschemes on the fly
    redshift                          # Adjusts the color temperature of your screen
    rofi                              # Window switcher, application launcher and dmenu replacement
    rofi-scripts                      # Collection of scripts for rofi
    thunar                            # Modern file manager for Xfce
    thunar-archive-plugin             # Archive plugin for Thunar
    thunar-media-tags-plugin          # Media tags plugin for Thunar
    thunar-shares-plugin              # Shares plugin for Thunar
    thunar-volman                     # Thunar volume manager
    ttf-font-awesome                  # Iconic font designed for Bootstrap
    ttf-meslo-nerd                    # Patched font Meslo from nerd fonts library
    ttf-sarasa-gothic                 # CJK programming font based on Iosevka and Source Han Sans
    ttf-sourcecodepro-nerd            # Patched font Source Code Pro from nerd fonts library
    tumbler                           # D-Bus service for applications to request thumbnails
    udiskie                           # Removable disk automounter using udisks
    vala-panel-appmenu-xfce-git       # Application menu plugin for vala-panel
    wqy-zenhei                        # Chinese outline font
    xautomation                       # Control X from the command line for scripts, and do "visual scraping"
    xbindkeys                         # Associates a combination of keys or mouse buttons with a shell command
    xcape                             # Configure modifier keys to act as other keys when pressed and released
    xclip                             # Command line interface to the X11 clipboard
    xorg-apps                         # Collection of various X.Org applications
    xscreensaver                      # Screen saver and locker for the X Window System
    xsecurelock                       # X11 screen lock utility with security in mind
    xsel                              # Command-line program for getting and setting the contents of the X selection
    xss-lock                          # Use external locker as X screen saver
    zathura                           # Minimalistic document viewer with vim-like keybindings
    zathura-cb                        # ComicBook support for Zathura
    zathura-djvu                      # DjVu support for Zathura
    zathura-pdf-mupdf                 # PDF support for Zathura (MuPDF backend)
    zathura-ps                        # PostScript support for Zathura
  )
  pacman_install_pkgs

  pkgs=(
    betterlockscreen                  # Screen locker based on i3lock
    gluqlo-git                        # Fliqlo for Linux
    i3ass                             # Collection of scripts for i3 window manager
    jumpapp                           # Run or focus applications in i3
    nerd-fonts-fira-code              # Iconic font aggregator, collection, and patcher
    sublime-merge                     # Git client, done Sublime
    sublime-text-4                    # Sophisticated text editor for code, markup and prose
    visual-studio-code-bin            # Visual Studio Code (binary)
    xgetres                           # Get X resources
    xinit-xsession                    # Allow xinit to function like xdm
  )
  aur_install_pkgs

  install_st
  set_default_apps
}

prepare_arch_env_gui_extra()
{
  pkgs=(
    android-file-transfer             # Reliable MTP client with minimalistic UI
    arc-gtk-theme                     # Flat theme with transparent elements for GTK
    arc-icon-theme                    # Arc icon theme
    chromium                          # Web browser built for speed, simplicity, and security
    copyq                             # Clipboard manager with searchable and editable history
    drawing                           # Simple image editor for Linux
    file-roller                       # Archive manager for GNOME
    freerdp                           # Free implementation of the Remote Desktop Protocol (RDP)
    handbrake                         # Video transcoder
    hardinfo                          # System information and benchmark tool
    kdiff3                            # File comparison and merge tool
    keepassxc                         # Cross-platform community-driven port of Keepass password manager
    kitty                             # Modern, hackable, featureful, OpenGL based terminal emulator
    materia-gtk-theme                 # Material Design theme for GNOME/GTK based desktop environments
    neofetch                          # CLI system information tool written in BASH
    pdfarranger                       # Helps merge or split PDF documents and rotate, crop and rearrange pages
    qutebrowser                       # Keyboard-focused browser with a minimal GUI
    remmina                           # Remote access screen and file sharing to your desktop
    rxvt-unicode                      # Unicode enabled rxvt-clone terminal emulator
    scrcpy                            # Display and control of Android devices connected on USB
    sqlitebrowser                     # High quality, visual, open source tool to create, design, and edit database files
    telegram-desktop                  # Official Telegram Desktop client
    termite                           # Minimal VTE-based terminal emulator
    tilda                             # GTK based drop down terminal for Linux and Unix
    virt-manager                      # Desktop tool for managing virtual machines via libvirt
    virtualbox                        # Powerful x86 virtualization for enterprise as well as home use
    winetricks                        # Script to install some Windows programs and libraries in Wine
    wkhtmltopdf                       # Command line tools to render HTML into PDF and various image formats
    xcursor-simpleandsoft             # Simple and Soft X cursor theme
    zeal                              # Offline documentation browser
  )
  pacman_install_pkgs

  pkgs=(
    android-sdk                       # Android software development kit
    android-sdk-platform-tools        # Platform-Tools for Google Android SDK
    android-studio                    # IDE for Android development
    corplink-bin                      # Corporate VPN client
    cursor-bin                        # AI-powered code editor
    deepin-wine-tim                   # Tencent QQ/TIM on Deepin Wine
    deepin-wine-wechat                # Tencent WeChat on Deepin Wine
    dropbox                           # Cloud backup and synchronization service
    feedreader                        # Modern desktop RSS reader built with GTK+
    feishu-bin                        # ByteDance's collaboration platform
    genymotion                        # Complete set of tools that provide a virtual environment for Android
    git-cola                          # Powerful GUI for Git
    google-chrome                     # Popular web browser by Google
    joplin                            # Note taking and to-do application with synchronisation capabilities
    kitematic                         # Visual Docker Container Management on Mac & PC
    losslesscut                       # Cross platform GUI tool for lossless trimming/cutting of videos
    mailspring                        # Beautiful, fast email client
    marktext-bin                      # Simple and elegant markdown editor
    microsoft-edge-stable-bin         # Fast and secure browser that helps you protect your data
    musixmatch-bin                    # Lyrics for your music
    qqmusic-bin                       # Tencent QQ Music
    rslsync                           # Resilio Sync: fast, reliable file and folder synchronization
    screenkey                         # Screencast tool to display your keys inspired by Screenflick
    slack-desktop                     # Slack Desktop for Linux
    spotify                           # Proprietary music streaming service
    thorium-bin                       # Chromium fork named after radioactive element No. 90
    ttf-ms-fonts                      # Microsoft TrueType fonts
    urxvt-fullscreen                  # Urxvt fullscreen toggle
    urxvt-resize-font-git             # Perl extension to resize the font size in urxvt
    v2raya-bin                        # Web GUI client of Project V
    wechat-uos                        # WeChat desktop with full functionality
    whatsapp-for-linux                # WhatsApp desktop client for Linux
  )
  aur_install_pkgs
}

setup_arch_gaming()
{
  pkgs=(
    desmume                           # Nintendo DS emulator
    dosbox                            # Emulator with DOS for running legacy games
    higan                             # Multi-system emulator focused on accuracy
    mame                              # Port of the popular Multiple Arcade Machine Emulator
    openra                            # Real-time strategy game engine supporting early Westwood games
    pcsx2                             # Sony PlayStation 2 emulator
    ppsspp                            # Sony PSP emulator written in C++
    snes9x-gtk                        # Super Nintendo Entertainment System emulator
    steam                             # Digital distribution platform for PC gaming
    vbam-wx                           # Game Boy Advance emulator with wxWidgets GUI
  )
  pacman_install_pkgs

  pkgs=(
    dosbox-x                          # Enhanced fork of DOSBox DOS emulator with additional features
  )
  aur_install_pkgs
}

set_default_apps()
{
  xdg-mime default firefox.desktop text/html
  xdg-mime default firefox.desktop x-scheme-handler/http
  xdg-mime default firefox.desktop x-scheme-handler/https
  xdg-mime default Thunar.desktop inode/directory
}
