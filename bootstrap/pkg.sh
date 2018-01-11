installCommonPackages()
{
  installNpmPackages
  installGemPackages
  installPipPackages
  installCpanPackages
  installOtherPackages
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
    @angular/cli
    @storybook/cli
    azure-functions-core-tools@core
    bower
    clipboard-cli
    coinmon
    commitizen
    create-dmg
    create-react-app
    create-react-native-app
    depcheck
    egghead-downloader
    ember-cli
    english-dictionary-cli
    express-generator
    flow-typed
    gatsby-cli
    gulp-cli
    hexo-cli
    http-server
    leetcode-cli
    localtunnel
    loopback-cli
    nativescript
    nls
    now
    ntl
    opn-cli
    pm2
    react-devtools
    react-native-cli
    react-vr-cli
    semantic-release-cli
    serve
    serverless
    tldr
    trash
    ts-node
    typescript
    updtr
    vue-cli
    weinre
    yo
  )

  for pkg in "${pkgs[@]}"; do
    npm install -g $pkg
  done

  echo 'Done.'
}

installPipPackages()
{
  echo 'Installing pip packages...'

  local pkgs=(
    cppman
    glances
    httpstat
    ici
    powerline-status
    pygments
    rainbowstream
    rdbtools
    rtv
    thefuck
  )

  for pkg in "${pkgs[@]}"; do pip install -U "$pkg"; done
}

installCpanPackages()
{
  echo 'Installing CPAN packages...'

  local pkgs=(
    Mozilla::CA
    JSON
  )

  sudo cpanm install `join ' ' "${pkgs[@]}"`
}

installOtherPackages()
{
  installAnyScript md2resume https://raw.githubusercontent.com/there4/markdown-resume/master/bin/md2resume
  installAnyScript hls-fetch https://raw.githubusercontent.com/osklil/hls-fetch/master/hls-fetch
}

installAnyScript()
{
  printf "Installing $1 to $HOME/bin... "
  curl -s "$2" > "$HOME/bin/$1"
  chmod +x "$HOME/bin/$1"
  echo 'Done.'
}
