. $PSScriptRoot\util.ps1

function install_chocolatey
{
  blank_lines
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

function install_choco_packages
{
  blank_lines
  'Install packages using Chocolatey...'

  cinst -y `
    caesium.install `
    camstudio `
    pngoptimizer `

    # Keep a blank line
}

install_chocolatey
install_choco_packages
