installCommonPackages()
{
  installNpmPackages
  installGemPackages
  installPipPackages
}

installGemPackages()
{
  echo 'Installing gems...'

  local pkgs=(
    boom
    gas
    lolcat
    sass
    tmuxinator
  )

  for gem in "${pkgs[@]}"; do
    gem list -i $gem &> /dev/null || gem install $gem
  done

  gem update `join ' ' "${pkgs[@]}"`

  echo 'Done.'
}

installNpmPackages()
{
  echo 'Installing global npm packages...'

  local pkgs=(
    bower
    clipboard-cli
    create-react-app
    create-react-native-app
    egghead-downloader
    ember-cli
    english-dictionary-cli
    gulp-cli
    hexo-cli
    leetcode-cli
    localtunnel
    nativescript
    node-inspector
    now
    ntl
    pm2
    react-native-cli
    semantic-release-cli
    tldr
    trash
    typescript
    updtr
    vue-cli
    weinre
    yo
  )

  npm install -g `join ' ' "${pkgs[@]}"`

  echo 'Done.'
}

installPipPackages()
{
  echo 'Installing pip packages...'

  local pkgs=(
    httpstat
    ici
    powerline-status
    pygments
    rainbowstream
    rtv
    thefuck
  )

  for pkg in "${pkgs[@]}"; do
    pip install --user "$pkg"
  done
}
