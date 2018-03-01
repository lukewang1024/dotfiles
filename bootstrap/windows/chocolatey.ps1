. $PSScriptRoot\util.ps1

function installChocolatey
{
  blankLines
  'Install Chocolatey...'

  if ((Get-Command 'chocolatey' -ErrorAction SilentlyContinue) -eq $null)
  {
    Set-ExecutionPolicy AllSigned
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
  }
  else
  {
    'Chocolatey already exists.'
  }
}

function installChocoPackages
{
  blankLines
  'Install packages using Chocolatey...'

  cinst -y `
    7zip.install `
    altdrag `
    awscli `
    caesium.install `
    camstudio `
    charles `
    chocolatey `
    chocolateygui `
    clover `
    docker-for-windows `
    docker-toolbox `
    dropbox `
    f.lux `
    fiddler4 `
    googlechrome `
    googledrive `
    intellijidea-community `
    path-copy-copy `
    pdfsam `
    pngoptimizer `
    potplayer `
    resilio-sync-home `
    skype `
    spacesniffer `
    spotify `
    strokesplus `
    switcheroo `
    virtualbox `
    vnc-connect `
    vnc-viewer `
    xnviewmp `
    you-get `

    # Keep a blank line
}

installChocolatey
installChocoPackages
