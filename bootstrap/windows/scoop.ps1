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
    games `

  scoop bucket add customize https://github.com/ChinLong/scoop-customize.git

  scoop install `
    7zip `
    adb `
    ag `
    alacritty `
    altsnap `
    android-sdk `
    android-studio `
    aria2 `
    atom `
    autohotkey `
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
    delta `
    deno `
    ditto `
    dosbox `
    dosbox-x `
    dotnet3-sdk `
    dotnet5-sdk `
    dotnet6-sdk `
    doublecmd `
    dropit `
    duf `
    eartrumpet `
    everything `
    far `
    fd `
    filezilla `
    firefox `
    flux `
    foobar2000 `
    foobar2000-encoders `
    foxit-reader `
    fzf `
    git `
    git-lfs `
    googlechrome `
    gow `
    gping `
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
    marktext `
    mc `
    micro `
    miniconda3 `
    minikube `
    mobaxterm `
    nimbleset `
    nimbletext `
    nirlauncher `
    nmap `
    nodejs `
    nodejs-lts `
    now-cli `
    nvm `
    openark `
    openhardwaremonitor `
    openra `
    openssh `
    oraclejdk `
    pandoc `
    pdfarranger `
    pdfsam `
    phantomjs `
    potplayer `
    powertoys `
    processhacker `
    procs `
    pshazz `
    putty `
    python `
    quicklook `
    qutebrowser `
    robo3t `
    rufus `
    runat `
    say `
    sbt `
    screentogif `
    shadowsocks `
    shasum `
    skype `
    slack `
    smartmontools `
    snipaste `
    spacesniffer `
    spotify `
    steam `
    strokesplus `
    sublime-merge `
    sublime-text `
    sudo `
    sumatrapdf `
    switcheroo `
    switchhosts `
    synctrayzor `
    sysinternals `
    telegram `
    touch `
    trafficmonitor `
    translucent-tb `
    unlocker `
    v2rayn `
    vagrant `
    vcredist2015 `
    vcredist2017 `
    vcredist2019 `
    vcredist2022 `
    vcxsrv `
    vim `
    vncviewer `
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
    xnviewmp `
    yarn `
    zeal `

  # Keep a blank line

  scoop install 'https://raw.githubusercontent.com/acdzh/zpt/master/bucket/pasteex.json'

  # Make git work with openssh
  [environment]::setenvironmentvariable('GIT_SSH', (resolve-path (scoop which ssh)), 'USER')

  # Solarized theme
  concfg import solarized small

  # Make `source activate` work in powershell
  conda install -n root -c pscondaenvs pscondaenvs

  sudo scoop install `
    FiraCode-NF `
    Meslo-NF `
    SourceCodePro-NF `

  # Keep a blank line
}

install_scoop
install_scoop_packages
