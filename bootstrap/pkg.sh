install_common_packages()
{
  install_cargo_packages
  install_npm_packages
  install_gem_packages
  install_pip_packages
  install_cpan_packages
  install_other_packages
}

install_cargo_packages()
{
  echo 'Installing crates...'

  local pkgs=(
    wurl                              # WebSocket CLI for developers
  )

  cargo install `join ' ' "${pkgs[@]}"`

  echo 'Done.'
}

install_gem_packages()
{
  echo 'Installing gems...'

  local pkgs=(
    boom                              # boom lets you access text snippets over your command line
    gas                               # Manage your git author accounts
    iStats                            # Stats for your mac
    mdless                            # A pager like less, but for Markdown files
  )

  gem install `join ' ' "${pkgs[@]}"`
  gem update

  echo 'Done.'
}

install_npm_packages()
{
  echo 'Installing global npm packages...'

  local pkgs=(
    @angular/cli                      # CLI tool for Angular
    @anthropic-ai/claude-code         # Use Claude, Anthropic's AI assistant, right from your terminal
    @google/gemini-cli                # Gemini CLI
    @openai/codex                     # OpenAI Codex CLI
    @squoosh/cli                      # A CLI for Squoosh (image compression and optimization tool)
    @vue/cli                          # Command line interface for rapid Vue.js development
    asar                              # Creating Electron app packages
    bower                             # The browser package manager
    brightness-cli                    # Change the screen brightness
    clipboard-cli                     # Access the system clipboard (copy/paste)
    coinmon                           # Cryptocurrency price monitoring tool (package unpublished)
    commitizen                        # Git commit, but play nice with conventions
    create-dmg                        # Create a good-looking DMG for your macOS app in seconds
    depcheck                          # Check dependencies in your node module
    english-dictionary-cli            # English Dictionary from the command line
    expo-cli                          # The command-line tool for creating and publishing Expo apps
    express-generator                 # Express' application generator
    gatsby-cli                        # Command-line interface for Gatsby, the React-based static site generator
    git-file-history                  # Command-line tool to quickly browse the git history of a specific file
    gulp-cli                          # Command-line interface for Gulp, the JavaScript toolkit and task runner
    hexo-cli                          # Command-line interface for Hexo, the fast and simple static blog framework
    hiper                             # Performance profiling tool to get statistics about page load performance
    http-server                       # Simple, zero-configuration command-line HTTP server for serving static files
    import-sort-cli                   # Command-line tool to automatically sort and organize ES6 import statements
    is-website-vulnerable             # Security tool that checks if a website has known vulnerabilities in its frontend JavaScript libraries
    leetcode-cli                      # Command-line interface for LeetCode platform to browse and submit coding problems
    localtunnel                       # Tool to expose your localhost to the world via secure tunnels
    loopback-cli                      # Command-line interface for LoopBack, the Node.js API framework
    madge                             # Dependency graph visualization tool for JavaScript projects
    majestic                          # Zero-config GUI for Jest testing framework with test coverage and watch mode
    memlab                            # Memory leak detection and heap analysis tool for JavaScript applications
    mermaid.cli                       # Command-line interface for Mermaid, the diagramming and charting tool
    musicn                            # Download music in your command line
    nativefier                        # Wrap web apps natively
    nativescript                      # Command-line interface for building NativeScript projects
    neovim                            # Nvim msgpack API client and remote plugin provider
    nls                               # Missing inspector for npm packages
    npkill                            # List any node_modules directories in your system, as well as the space they take up
    npm-check                         # Check for outdated, incorrect, and unused dependencies
    npm-check-updates                 # Find newer versions of dependencies than what your package.json allows
    npm-quick-run                     # Quickly run NPM script by prefix without typing the full name
    nrm                               # npm registry manager can help you switch different npm registries easily and quickly
    open-cli                          # Open stuff like URLs, files, executables. Cross-platform
    pangu                             # Paranoid text spacing for good readability, to automatically insert whitespace between CJK and half-width characters
    pm2                               # Production process manager for Node.JS applications with a built-in load balancer
    pnpm                              # Fast, disk space efficient package manager
    react-devtools                    # Use react-devtools outside of the browser
    readability-cli                   # Command-line tool that extracts and formats the main readable content from web pages
    serve                             # Static file server that serves files from a directory via HTTP
    serverless                        # Framework for building and deploying serverless applications to cloud providers
    source-map-explorer               # Tool that analyzes JavaScript bundles using source maps to show which files contribute to bundle size
    svgexport                         # Command-line utility for converting SVG files to PNG, JPEG, PDF and other formats
    taskbook                          # Command-line task management tool for creating, organizing, and tracking tasks and notes in the terminal
    terminalizer                      # Tool for recording and sharing terminal sessions as animated GIF files or web players
    textlint                          # Pluggable linting tool for text and markup that helps maintain consistent writing style and catch errors
    ts-node                           # TypeScript execution environment for Node.js that compiles TypeScript on-the-fly without pre-compilation
    typescript                        # Microsoft's typed superset of JavaScript that compiles to plain JavaScript
    updtr                             # Tool for updating npm dependencies interactively, allowing you to review and selectively update packages
    vercel                            # Deployment platform and CLI for frontend frameworks and static sites with global CDN and serverless functions
    weinre                            # Web Inspector Remote debugger for remotely debugging web pages on mobile devices and other targets
    workbox-cli                       # Command-line interface for Google's Workbox library, used to add service workers and offline functionality
    yo                                # Scaffolding tool that runs Yeoman generators to quickly create project boilerplates and code templates
    zx                                # Tool for writing shell scripts in JavaScript/TypeScript with better ergonomics than traditional bash scripting
  )

  npm install -g `join ' ' "${pkgs[@]}"`

  echo 'Done.'
}

install_pip_packages()
{
  echo 'Installing pip packages...'

  local pkgs=(
    argcomplete                       # Shell tab completion support for Python argparse command-line programs
    cppman                            # C++ manual pages for Linux/MacOS with support for both C++98 and C++11/14/17 standards
    ici                               # Interactive shell for Python that provides enhanced REPL functionality with better introspection
    myqr                              # Python library for generating artistic QR codes with customizable styles and embedded images
    poetry                            # Modern dependency management and packaging tool for Python projects with lock file support
    powerline-status                  # Statusline plugin for vim, zsh, bash, tmux, IPython, Awesome and i3 providing informative segments
    present                           # Terminal-based presentation tool that renders markdown slides in the command line
    superclaude                       # SuperClaude Framework Management Hub
    pygments                          # Syntax highlighting library for Python supporting hundreds of programming languages and markup formats
    pywal                             # Tool that generates and changes color schemes for various applications based on image color palettes
    rainbowstream                     # Smart and nice Twitter client on terminal written in Python with real-time streaming
    rdbtools                          # Collection of utilities to parse, filter, and analyze Redis RDB files for memory optimization
    ruff                              # Extremely fast Python linter and code formatter written in Rust
  )

  pipx install `join ' ' "${pkgs[@]}"`

  echo 'Done.'
}

install_cpan_packages()
{
  echo 'Installing CPAN packages...'

  local pkgs=(
    Mozilla::CA                       # Mozilla's CA cert bundle in PEM format
    JSON                              # JSON (JavaScript Object Notation) encoder/decoder
  )

  sudo cpanm install `join ' ' "${pkgs[@]}"`

  echo 'Done.'
}

install_other_packages()
{
  backup_then_symlink "$util_dir/shell/find-and-replace" "$bin_dir/find-and-replace"
  backup_then_symlink "$util_dir/shell/git-newbranch" "$bin_dir/git-newbranch"
  backup_then_symlink "$util_dir/shell/killbp" "$bin_dir/killbp"
  backup_then_symlink "$util_dir/shell/mann" "$bin_dir/mann"
  backup_then_symlink "$util_dir/shell/md2resume" "$bin_dir/md2resume"
  backup_then_symlink "$util_dir/shell/pretty-csv" "$bin_dir/pretty-csv"
  backup_then_symlink "$util_dir/shell/vnc-connect" "$bin_dir/vnc-connect"
  install_any_script hls-fetch https://raw.githubusercontent.com/osklil/hls-fetch/master/hls-fetch
}

install_any_script()
{
  printf "Installing $1 to $bin_dir... "
  curl -s "$2" > "$bin_dir/$1"
  chmod +x "$bin_dir/$1"
  echo 'Done.'
}
