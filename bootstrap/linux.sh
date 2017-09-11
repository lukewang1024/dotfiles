# Use LinuxBrew for latest version of tools
installLinuxBrew()
{
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install)"
  # Make sure brew can be found right after installation
  PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
}

installLinuxBrewPackages()
{
  local pkgs=(
    gcc
    aria2
    awscli
    cloc
    fish
    git
    git-flow-avh
    git-lfs
    go
    htop
    httpie
    imagemagick
    irssi
    jq
    kubectl
    mc
    mosh
    mutt
    mycli
    nano
    nmap
    offlineimap
    openssh
    pandoc
    ranger
    rsync
    shellcheck
    tig
    the_silver_searcher
    tmux
    vim
  )
  brew install `join ' ' "${pkgs[@]}"`
}

condaSetup()
{
  if [ $(uname -m) == x86_64 ]; then
    curl https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh | bash
  else
    curl https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86.sh | bash
  fi

  echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.rc.custom
}

fixENOSPC()
{
  echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
}

# Make sure default locale is available
fixLocale()
{
  sudo localedef -i en_US -f UTF-8 en_US.UTF-8
}
