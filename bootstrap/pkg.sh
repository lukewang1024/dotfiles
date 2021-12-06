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
    wurl
  )

  cargo install `join ' ' "${pkgs[@]}"`

  echo 'Done.'
}

install_gem_packages()
{
  echo 'Installing gems...'

  local pkgs=(
    boom
    gas
    iStats
    mdless
  )

  gem install `join ' ' "${pkgs[@]}"`
  gem update

  echo 'Done.'
}

install_npm_packages()
{
  echo 'Installing global npm packages...'

  npm config set python python2.7

  local pkgs=(
    @angular/cli
    @squoosh/cli
    @vue/cli
    asar
    azure-functions-core-tools@core
    bower
    brightness-cli
    clipboard-cli
    coinmon
    commitizen
    create-dmg
    depcheck
    english-dictionary-cli
    expo-cli
    express-generator
    gatsby-cli
    git-file-history
    gulp-cli
    hexo-cli
    hiper
    http-server
    import-sort-cli
    is-website-vulnerable
    leetcode-cli
    localtunnel
    loopback-cli
    madge
    majestic
    mermaid.cli
    nativefier
    nativescript
    neovim
    nls
    npkill
    npm-check
    npm-check-updates
    npm-quick-run
    nrm
    open-cli
    pangu
    pm2
    pnpm
    react-devtools
    readability-cli
    serve
    serverless
    source-map-explorer
    svgexport
    taskbook
    terminalizer
    textlint
    ts-node
    typescript
    updtr
    vercel
    weinre
    whistle
    workbox-cli
    yo
    zx
  )

  npm install -g `join ' ' "${pkgs[@]}"`

  echo 'Done.'
}

install_pip_packages()
{
  echo 'Installing pip packages...'

  local pkgs=(
    argcomplete
    cppman
    ici
    myqr
    powerline-status
    present
    pygments
    pywal
    rainbowstream
    rdbtools
  )

  pip install --upgrade `join ' ' "${pkgs[@]}"`

  echo 'Done.'
}

install_cpan_packages()
{
  echo 'Installing CPAN packages...'

  local pkgs=(
    Mozilla::CA
    JSON
  )

  sudo cpanm install `join ' ' "${pkgs[@]}"`

  echo 'Done.'
}

install_other_packages()
{
  backup_then_symlink "$util_dir/shell/find-and-replace" ~/bin/find-and-replace
  backup_then_symlink "$util_dir/shell/killbp" ~/bin/killbp
  backup_then_symlink "$util_dir/shell/mann" ~/bin/mann
  backup_then_symlink "$util_dir/shell/md2resume" ~/bin/md2resume
  backup_then_symlink "$util_dir/shell/pretty-csv" ~/bin/pretty-csv
  install_any_script hls-fetch https://raw.githubusercontent.com/osklil/hls-fetch/master/hls-fetch
}

install_any_script()
{
  printf "Installing $1 to $HOME/bin... "
  curl -s "$2" > "$HOME/bin/$1"
  chmod +x "$HOME/bin/$1"
  echo 'Done.'
}
