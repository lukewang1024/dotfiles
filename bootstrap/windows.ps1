#Requires -RunAsAdministrator

function installChocolatey
{
  if ((Get-Command "chocolatey" -ErrorAction SilentlyContinue) -eq $null)
  {
    Set-ExecutionPolicy AllSigned
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
  }
  else
  {
    'Chocolatey already exists.'
  }
}

function installChocolateyPackages
{
  $pkgs = @(
    '7zip',
    'ack',
    'aimp',
    'altdrag',
    'aria2',
    'atom',
    'autohotkey',
    'caesium.install',
    'calibre',
    'ccleaner',
    'charles',
    'chocolatey',
    'chocolateygui',
    'chromium',
    'docker',
    'doublecmd',
    'dropbox',
    'everything',
    'far',
    'fiddler4',
    'filezilla',
    'firefox',
    'foobar2000',
    'foxitreader',
    'git',
    'golang',
    'googlechrome',
    'googledrive',
    'gow',
    'hexchat',
    'intellijidea-community',
    'irfanview',
    'irfanviewplugins',
    'jdk8',
    'licecap',
    'meld',
    'miktex',
    'mobaxterm',
    'nimbletext',
    'nmap',
    'nodejs',
    'nvm',
    'paint.net',
    'pandoc',
    'phantomjs',
    'pngoptimizer',
    'postman',
    'potplayer',
    'putty',
    'python',
    'python2',
    'rescuetime',
    'ruby',
    'rufus',
    'sbt',
    'skype',
    'slack',
    'sourcecodepro',
    'sourcetree',
    'spacesniffer',
    'spotify',
    'strokesplus',
    'sublimetext3',
    'sumatrapdf',
    'switcheroo',
    'sysinternals',
    'telegram',
    'vagrant',
    'vcxsrv',
    'virtualbox',
    'visualstudiocode',
    'vnc-viewer',
    'whatsapp',
    'windirstat',
    'winscp',
    'wox',
    'xnviewmp',
    'yarn',
    'you-get'
  )
  $ofs = ' '
  cup -y all
  cinst -y "$pkgs"
}

function applyWindowsDefenderExclusions
{
  blankLines
  $exclusions = @(
    "$Env:LOCALAPPDATA\Yarn",
    "$Env:USERPROFILE\.atom",
    "$Env:USERPROFILE\.vscode\extensions"
  )

  'Exclude below paths from Windows Defender real time protection:'
  foreach ($path in $exclusions) {
    "... $path"
    Add-MpPreference -ExclusionPath "$path"
  }
  'Done.'
}

function blankLines($num = 3, $char = '.')
{
  for ($i=0; $i -lt $num; $i++) {
    $char
  }
}

applyWindowsDefenderExclusions
installChocolatey
installChocolateyPackages
