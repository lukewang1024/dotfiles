# Bootstrap source/interpreter only. No package lists, tasks, or reporting logic.
$ErrorActionPreference = 'Stop'
$rawArgs = @($args)
$proxyValue = $null
$bootstrapArgs = @()
for ($index = 0; $index -lt $rawArgs.Count; $index++) {
  $argument = [string]$rawArgs[$index]
  if ($argument -ieq '--proxy' -or $argument -ieq '--bootstrap-proxy') {
    if ($index + 1 -ge $rawArgs.Count) { throw "Missing value for $argument" }
    $proxyValue = [string]$rawArgs[++$index]
    continue
  }
  if ($argument -like '--proxy=*') {
    $proxyValue = $argument.Substring('--proxy='.Length)
    continue
  }
  if ($argument -like '--bootstrap-proxy=*') {
    $proxyValue = $argument.Substring('--bootstrap-proxy='.Length)
    continue
  }
  $bootstrapArgs += $argument
}
if ($bootstrapArgs.Count -eq 0) { Write-Host 'Usage: init.ps1 [--proxy <http://host:port>] <basic|core|all|sync|run|...> [options]'; exit 2 }
$env:PYTHONDONTWRITEBYTECODE = '1'
$repoDir = $PSScriptRoot
$mainScript = Join-Path $repoDir 'bootstrap/main.py'
$inspection = @($bootstrapArgs | Where-Object { $_ -in @('--dry-run', '--list-tasks', '-h', '--help') }).Count -gt 0
$proxy = $null

if ($proxyValue) {
  $proxyText = $proxyValue.Trim()
  if ($proxyText -notmatch '^[a-z][a-z0-9+.-]*://') { $proxyText = "http://$proxyText" }
  try { $proxyUri = [Uri]$proxyText } catch { throw "Invalid proxy URL: $proxyValue" }
  if (!$proxyUri.IsAbsoluteUri -or $proxyUri.Scheme -notin @('http', 'https') -or !$proxyUri.Host -or $proxyUri.Port -le 0) {
    throw "Proxy must be an HTTP URL with a host and port: $proxyValue"
  }
  $proxy = [pscustomobject]@{
    Url = $proxyUri.AbsoluteUri.TrimEnd('/')
    Scoop = $proxyUri.Authority
  }
}

function Add-ScoopShims {
  $scoopRoot = $env:SCOOP
  if (!$scoopRoot) { $scoopRoot = Join-Path $env:USERPROFILE 'scoop' }
  $shims = Join-Path $scoopRoot 'shims'
  if ((Test-Path -LiteralPath $shims) -and !($env:Path -split ';' -contains $shims)) {
    $env:Path = "$shims;$env:Path"
  }
}

function Configure-ScoopProxy {
  param([string]$ScoopPath, [pscustomobject]$Proxy)
  if (!$Proxy) { return }
  & $ScoopPath config proxy $Proxy.Scoop
  if ($LASTEXITCODE -ne 0) { throw "Failed to configure Scoop proxy" }
  foreach ($name in @('HTTP_PROXY', 'HTTPS_PROXY')) {
    if (!(Get-Item -Path "Env:$name" -ErrorAction SilentlyContinue)) {
      Set-Item -Path "Env:$name" -Value $Proxy.Url
    }
  }
  Write-Host 'Configured Scoop to use the proxy supplied on the command line.'
}

function Ensure-Scoop {
  param([pscustomobject]$Proxy)
  Add-ScoopShims
  $scoop = Get-Command scoop -ErrorAction SilentlyContinue
  if (!$scoop) {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    $installer = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-scoop-' + [guid]::NewGuid().ToString('N') + '.ps1')
    try {
      $downloadArgs = @('-UseBasicParsing', '-Uri', 'https://get.scoop.sh', '-OutFile', $installer)
      if ($Proxy) { $downloadArgs += @('-Proxy', $Proxy.Url) }
      Invoke-WebRequest @downloadArgs
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer
      if ($LASTEXITCODE -ne 0) { throw "Scoop installer exited with status $LASTEXITCODE" }
    } finally {
      Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
    }
    Add-ScoopShims
    $scoop = Get-Command scoop -ErrorAction SilentlyContinue
  }
  if (!$scoop) { throw 'Scoop is unavailable after installation' }
  Configure-ScoopProxy $scoop.Source $Proxy
  return $scoop.Source
}

function Invoke-Scoop {
  param([string]$ScoopPath, [string[]]$Arguments)
  & $ScoopPath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Scoop command failed with status ${LASTEXITCODE}: $($Arguments -join ' ')"
  }
}

function Get-ScoopPython {
  param([string]$ScoopPath)
  $prefix = (& $ScoopPath prefix python 2>$null | Select-Object -Last 1)
  if (!$prefix) { return $null }
  $python = Join-Path ([string]$prefix).Trim() 'python.exe'
  if (Test-Path -LiteralPath $python) { return $python }
  return $null
}

# A downloaded standalone launcher obtains a complete Git checkout first.
if (!(Test-Path -LiteralPath $mainScript)) {
  if ($inspection) { throw 'Download or clone the complete dotfiles checkout before inspecting it.' }
  $scoopPath = Ensure-Scoop $proxy
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (!$git -or $git.Source -like '*WindowsApps*') {
    Invoke-Scoop $scoopPath @('install', 'git')
    Add-ScoopShims
  }
  $configRoot = $env:XDG_CONFIG_HOME
  if (!$configRoot) { $configRoot = Join-Path $env:USERPROFILE '.config' }
  $repoDir = Join-Path $configRoot 'dotfiles'
  $mainScript = Join-Path $repoDir 'bootstrap/main.py'
  if (!(Test-Path -LiteralPath $mainScript)) {
    if (Test-Path -LiteralPath $repoDir) { throw "Refusing to overwrite incomplete checkout: $repoDir" }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (!$git) {
      throw 'Git is required to fetch the checkout. Install Git, then rerun this launcher.'
    }
    & $git.Source clone --depth 1 https://github.com/lukewang1024/dotfiles $repoDir
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}

if ($inspection) {
  foreach ($name in @('python3', 'python', 'py')) {
    $candidate = Get-Command $name -ErrorAction SilentlyContinue
    if (!$candidate -or $candidate.Source -like '*WindowsApps*') { continue }
    $prefix = @()
    if ($name -eq 'py') { $prefix = @('-3') }
    & $candidate.Source @prefix -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>$null
    if ($LASTEXITCODE -eq 0) {
      & $candidate.Source @prefix $mainScript @bootstrapArgs
      exit $LASTEXITCODE
    }
  }
  throw 'Python 3.10+ is required for inspection. Run init.ps1 core to prepare the Scoop-managed runtime.'
}
$scoopPath = Ensure-Scoop $proxy
$python = Get-ScoopPython $scoopPath
if (!$python) {
  Write-Host 'Preparing latest managed Python through Scoop...'
  Invoke-Scoop $scoopPath @('install', 'python')
  Add-ScoopShims
  $python = Get-ScoopPython $scoopPath
}
if (!$python) { throw 'Scoop installed Python but python.exe is unavailable' }
Write-Host "Python runtime ready: $python"
& $python $mainScript @bootstrapArgs
exit $LASTEXITCODE
