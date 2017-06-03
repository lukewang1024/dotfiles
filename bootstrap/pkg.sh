installCommonPackages()
{
  installNpmPackages
  installGemPackages
  installPipPackages
}

installGemPackages()
{
  echo 'Installing gems...'

  pkgs=(
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
  unset pkgs

  echo 'Done.'
}

installNpmPackages()
{
  echo 'Installing global npm packages...'

  pkgs=(
    bower
    clipboard-cli
    create-react-app
    create-react-native-app
    egghead-downloader
    english-dictionary-cli
    gulp-cli
    hexo-cli
    leetcode-cli
    localtunnel
    nativescript
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
  unset pkgs

  echo 'Done.'
}

installPipPackages()
{
  echo 'Installing pip packages...'

  pkgs=(
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

  unset pkgs
}
