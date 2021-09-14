. $PSScriptRoot\util.ps1

function install_scoop
{
  Set-ExecutionPolicy RemoteSigned -scope CurrentUser

  if (Get-Command scoop -errorAction SilentlyContinue) {
    scoop update
  } else {
    iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
  }
}

function install_scoop_packages
{
  scoop bucket add `
    extras `
    java `
    versions `
    nerd-fonts `
    nirsoft `
    nonportable `

  scoop bucket add customize https://github.com/ChinLong/scoop-customize.git

  scoop install `
    7zip `
    adb `
    ag `
    alacritty `
    android-sdk `
    android-studio `
    atom `
    autohotkey `
    azure-cli `
    broot `
    calibre `
    carnac `
    ccleaner `
    chromium `
    cloc `
    concfg `
    copyq `
    cowsay `
    cpu-z `
    deno `
    ditto `
    dosbox `
    dosbox-x `
    doublecmd `
    duf `
    everything `
    far `
    fd `
    filezilla `
    firefox `
    foobar2000 `
    foxit-reader `
    fzf `
    gcloud `
    git `
    git-lfs `
    gow `
    gping `
    hain `
    handbrake `
    heidisql `
    hexchat `
    hub `
    hwmonitor `
    irfanview `
    joplin `
    jq `
    kdiff3 `
    keepass `
    kitematic `
    kitty `
    kubectl `
    lazydocker `
    lazygit `
    lf `
    licecap `
    ln `
    losslesscut `
    lxrunoffline `
    mc `
    miniconda3 `
    mobaxterm `
    nimbleset `
    nimbletext `
    nmap `
    nodejs `
    nodejs-lts `
    now-cli `
    nvm `
    openhardwaremonitor `
    openssh `
    oraclejdk `
    pandoc `
    phantomjs `
    pshazz `
    putty `
    qutebrowser `
    robo3t `
    rufus `
    runat `
    say `
    sbt `
    screentogif `
    shadowsocks `
    shasum `
    slack `
    snipaste `
    steam `
    sublime-merge `
    sublime-text `
    sudo `
    sumatrapdf `
    synctrayzor `
    sysinternals `
    telegram `
    touch `
    translucent-tb `
    unlocker `
    v2rayn `
    vagrant `
    vcxsrv `
    vim `
    vimtutor `
    vscode `
    whatsapp `
    win-dynamic-desktop `
    windirstat `
    windows-terminal `
    winscp `
    wireshark `
    wox `
    wsltty `
    xming `
    yarn `
    zeal `

  scoop install 'https://raw.githubusercontent.com/acdzh/zpt/master/bucket/pasteex.json'

  # Make git work with openssh
  [environment]::setenvironmentvariable('GIT_SSH', (resolve-path (scoop which ssh)), 'USER')

  # Solarized theme
  concfg import solarized small

  # Make `source activate` work in powershell
  conda install -n root -c pscondaenvs pscondaenvs

  sudo scoop install `
    SourceCodePro-NF `

  # Keep a blank line
}

install_scoop
install_scoop_packages
