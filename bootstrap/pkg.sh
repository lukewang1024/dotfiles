install_common_packages()
{
  # Core contains cross-project daily drivers. The default installs the full
  # curated set; project linters/build dependencies stay out of core.
  local level=${1:-all}

  case $level in
    core)
      install_cargo_packages core
      install_npm_packages core
      install_gem_packages core
      install_pip_packages core
      ;;
    all)
      install_cargo_packages
      install_npm_packages
      install_gem_packages
      install_pip_packages
      install_ai_agent_tools
      install_other_packages
      ;;
    *)
      echo "Unknown package level: $level (expected core)" >&2
      return 1
      ;;
  esac
}

install_ai_agent_tools()
{
  echo 'Installing AI coding agents...'

  # Claude Code - native installer (recommended; auto-updates in background)
  curl -fsSL https://claude.ai/install.sh | bash

  # Codex CLI - standalone installer (recommended; rerun to upgrade)
  curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh

  echo 'Done.'
}

install_cargo_packages()
{
  local level=${1:-all}
  echo "Installing $level crates..."

  local core_pkgs=(
    wurl                              # WebSocket CLI for developers
  )
  local extra_pkgs=()
  local pkgs=()
  case $level in
    core) pkgs=("${core_pkgs[@]}") ;;
    all) pkgs=("${core_pkgs[@]}" "${extra_pkgs[@]}") ;;
    *)
      echo "Unknown Cargo package level: $level" >&2
      return 1
      ;;
  esac

  cargo install `join ' ' "${pkgs[@]}"`

  echo 'Done.'
}

install_gem_packages()
{
  local level=${1:-all}
  echo "Installing $level gems..."

  local core_pkgs=(
    mdless                            # A pager like less, but for Markdown files
  )
  local extra_pkgs=(
    iStats                            # Stats for your mac
  )
  local pkgs=()
  case $level in
    core) pkgs=("${core_pkgs[@]}") ;;
    all) pkgs=("${core_pkgs[@]}" "${extra_pkgs[@]}") ;;
    *)
      echo "Unknown Ruby package level: $level" >&2
      return 1
      ;;
  esac

  gem install --no-document `join ' ' "${pkgs[@]}"`

  echo 'Done.'
}

install_uv()
{
  if exists uv; then
    return 0
  fi

  echo 'Installing uv...'
  if exists brew && brew install uv; then
    export PATH="$(brew --prefix)/bin:$PATH"
  else
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$bin_dir" sh -
  fi
  export PATH="$bin_dir:$PATH"
  command -v uv >/dev/null 2>&1 || {
    echo "uv installation did not place an executable in $bin_dir" >&2
    return 1
  }
}

install_pnpm()
{
  if exists pnpm; then
    return 0
  fi

  local pnpm_home="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
  mkdir -p "$pnpm_home"

  if exists brew && brew install pnpm; then
    export PATH="$(brew --prefix)/bin:$PATH"
  elif is_macos && [ "$(uname -m)" = x86_64 ]; then
    # pnpm 11's standalone POSIX installer does not support Intel macOS.
    # Keep the pinned fallback only when Homebrew is unavailable or fails.
    curl -fsSL https://get.pnpm.io/install.sh |
      PNPM_VERSION=10.25.0 PNPM_HOME="$pnpm_home" sh -
  else
    curl -fsSL https://get.pnpm.io/install.sh |
      PNPM_HOME="$pnpm_home" sh -
  fi

  export PNPM_HOME="$pnpm_home"
  export PATH="$pnpm_home:$bin_dir:$PATH"
  command -v pnpm >/dev/null 2>&1 || {
    echo 'pnpm installation did not produce a usable executable.' >&2
    return 1
  }
}

install_npm_packages()
{
  install_npm_cli_packages "${1:-all}"
  install_npm_gui_packages "${1:-all}"
}

install_npm_cli_packages()
{
  local level=${1:-all}
  install_pnpm
  echo "Installing global pnpm packages ($level)..."

  local extra_pkgs=(
    commitizen                        # Git commit, but play nice with conventions
    depcheck                          # Check dependencies in your node module
    hexo-cli                          # Command-line interface for Hexo, the fast and simple static blog framework
    is-website-vulnerable             # Security tool that checks if a website has known vulnerabilities in its frontend JavaScript libraries
    madge                             # Dependency graph visualization tool for JavaScript projects
    npm-check                         # Check for outdated, incorrect, and unused dependencies
    npm-check-updates                 # Find newer versions of dependencies than what your package.json allows
    npm-quick-run                     # Quickly run NPM script by prefix without typing the full name
    pm2                               # Production process manager for Node.JS applications with a built-in load balancer
    svgexport                         # Command-line utility for converting SVG files to PNG, JPEG, PDF and other formats
    terminalizer                      # Tool for recording and sharing terminal sessions as animated GIF files or web players
    textlint                          # Pluggable linting tool for text and markup that helps maintain consistent writing style and catch errors
    updtr                             # Tool for updating npm dependencies interactively, allowing you to review and selectively update packages
    vercel                            # Deployment platform and CLI for frontend frameworks and static sites with global CDN and serverless functions
    yo                                # Scaffolding tool that runs Yeoman generators to quickly create project boilerplates and code templates
  )

  local core_pkgs=(
    git-file-history                  # Browse the git history of a specific file
    happy                             # Mobile and Web client for Claude Code and Codex
    http-server                       # Simple static file server
    localtunnel                       # Expose localhost through a secure tunnel
    mcporter                          # CLI for configured Model Context Protocol servers
    musicn                            # Download music from the command line
    neovim                            # Nvim msgpack API client and remote plugin provider
    nls                               # Inspect npm packages
    npkill                            # Find node_modules directories and inspect their size
    nrm                               # npm registry manager
    open-cli                          # Open URLs, files, and executables
    pangu                             # Improve spacing between CJK and half-width text
    readability-cli                   # Extract and format readable web content
    serve                             # Static file server
    skills                            # Open agent skills ecosystem CLI
    taskbook                          # Terminal task and note manager
    zx                                # Write shell scripts in JavaScript/TypeScript
  )
  local pkgs=()
  if [ "$level" = core ]; then
    pkgs=("${core_pkgs[@]}")
  elif [ "$level" = all ]; then
    pkgs=("${core_pkgs[@]}" "${extra_pkgs[@]}")
  else
    echo "Unknown Node package level: $level (expected core)" >&2
    return 1
  fi

  pnpm add -g `join ' ' "${pkgs[@]}"`

  echo 'Done.'
}

install_npm_gui_packages()
{
  local level=${1:-all}
  install_pnpm
  echo "Installing global GUI/desktop pnpm packages ($level)..."

  local core_pkgs=(
    brightness-cli
    clipboard-cli
  )
  local extra_pkgs=(
    @electron/asar
    @mermaid-js/mermaid-cli
    create-dmg
    nativefier
    open-computer-use
  )
  local pkgs=()
  case $level in
    core) pkgs=("${core_pkgs[@]}") ;;
    all) pkgs=("${core_pkgs[@]}" "${extra_pkgs[@]}") ;;
    *)
      echo "Unknown GUI Node package level: $level" >&2
      return 1
      ;;
  esac

  pnpm add -g `join ' ' "${pkgs[@]}"`
  echo 'Done.'
}

install_pip_packages()
{
  install_uv
  local level=${1:-all}
  echo "Installing $level Python CLI tools with uv..."

  local core_pkgs=(
    poetry                            # Dependency management and packaging tool for Python projects
    powerline-status                  # Statusline plugin for vim, zsh, bash, tmux and other shells
  )
  local extra_pkgs=(
    cppman                            # C++ manual pages for Linux/MacOS with support for both C++98 and C++11/14/17 standards
    ici                               # Interactive shell for Python that provides enhanced REPL functionality with better introspection
    myqr                              # Python library for generating artistic QR codes with customizable styles and embedded images
    present                           # Terminal-based presentation tool that renders markdown slides in the command line
    pygments                          # Syntax highlighting library for Python supporting hundreds of programming languages and markup formats
    pywal                             # Tool that generates and changes color schemes for various applications based on image color palettes
  )
  local pkgs=()
  case $level in
    core) pkgs=("${core_pkgs[@]}") ;;
    all) pkgs=("${core_pkgs[@]}" "${extra_pkgs[@]}") ;;
    *)
      echo "Unknown Python package level: $level (expected core)" >&2
      return 1
      ;;
  esac

  local pkg
  for pkg in "${pkgs[@]}"; do
    uv tool install --upgrade "$pkg"
  done

  echo 'Done.'
}

install_other_packages()
{
  backup_then_symlink "$util_dir/shell/find-and-replace" "$bin_dir/find-and-replace"
  backup_then_symlink "$util_dir/shell/killbp" "$bin_dir/killbp"
  backup_then_symlink "$util_dir/shell/mann" "$bin_dir/mann"
  backup_then_symlink "$util_dir/shell/md2resume" "$bin_dir/md2resume"
  backup_then_symlink "$util_dir/shell/npm-token" "$bin_dir/npm-token"
  backup_then_symlink "$util_dir/shell/pretty-csv" "$bin_dir/pretty-csv"
  # theme-sync / theme-push-remotes / tmux-appearance-fallback moved to
  # util_setup (bootstrap/env.sh) so `./init sync` reconciles the light/dark
  # relay on a plain pull, not only on a full provision.
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
