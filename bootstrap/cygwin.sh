source "$partial_dir/env.sh"

# Make sure we only proceed if the Cygwin terminal has enough previllege
checkAdmin()
{
  id -G | grep -qE '\<(544|0)\>'
  if [[ $? != 0 ]]; then
    echo 'Please run the script again in a run-as-administrator Cygwin instance. Exiting...'
    exit 1
  fi
}

setupCygwinEnv()
{
  echo 'Setting common Cygwin environment...'

  printf 'Get rid of the /cygdrive/ prefix for Windows drives... '
  sed -i.bak 's|none /cygdrive cygdrive binary,posix=0,user 0 0|none / cygdrive binary,posix=0,user 0 0|g' /etc/fstab
  echo 'Done.'

  # Create initial /etc/passwd profile
  mkpasswd -c | sed -e 'sX/bashX/zshX' | tee -a /etc/passwd

  printf 'Create sudo wrapper for Cygwin... '
  cp "$util_dir/cygwin/sudo" ~/bin/sudo
  chmod +x ~/bin/sudo
  echo 'Done.'

  printf 'Making Cygwin ~ and Windows native USERPROFILE the same one... '
  mkpasswd -l -d -p "$(cygpath -H)" > /etc/passwd
  mkgroup -l -d > /etc/group
  echo 'Done.'
}

installSage()
{
  sageDir="$HOME/.sage"
  if [ -d $sageDir ]; then
    echo 'sage already installed, try upgrade...'
    cd "$sageDir"
    git pull
  else
    echo 'Install sage...'
    git clone https://github.com/svnpenn/sage.git "$sageDir"
    cd "$sageDir"
    ./install.sh
  fi
  cd - &> /dev/null
  unset sageDir
  echo 'Done.'
}

installCygwinPackages()
{
  sage update

  pkgs=(
    curl
    cygport
    cygutils-extra
    fish
    fortune-mod
    git
    ImageMagick
    ImageMagick-doc
    inetutils
    irssi
    mosh
    mutt
    nano
    nc
    ncurses
    openssh
    openssl
    perl
    php
    python
    python-setuptools
    python3
    python3-setuptools
    ruby
    the_silver_searcher
    tig
    tmux
    vim
    w3m
    zip
    zsh
  )

  sage install `join ' ' "${pkgs[@]}"`
  unset pkgs
}
