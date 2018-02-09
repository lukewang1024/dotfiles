param (
  [switch]$scoop = $false,
  [switch]$choco = $false,
  [switch]$all = $false
)

if (-not $all -and -not $scoop -and -not $choco) {
  'Possible arguments:'
  '-all: Install all'
  '-scoop: Install scoop packages'
  '-choco: Install choco packages'
  exit
}

if ($scoop -or $all) {
  'Installing packages with Scoop...'
  . $PSScriptRoot\windows\scoop.ps1
}

if ($choco -or $all) {
  'Installing packages with Chocolatey...'
  sudo $PSScriptRoot\windows\chocolatey.ps1
}

'Done'
