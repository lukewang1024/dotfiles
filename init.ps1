# Bootstrap source/interpreter only. No package lists, tasks, or reporting logic.
$ErrorActionPreference = 'Stop'
$bootstrapArgs = @($args)
if ($bootstrapArgs.Count -eq 0) { Write-Host 'Usage: init.ps1 <basic|core|all|sync|run|...> [options]'; exit 2 }
$env:PYTHONDONTWRITEBYTECODE = '1'
$repoDir = $PSScriptRoot
$mainScript = Join-Path $repoDir 'bootstrap/main.py'
$inspection = @($bootstrapArgs | Where-Object { $_ -in @('--dry-run', '--list-tasks', '-h', '--help') }).Count -gt 0

# A downloaded standalone launcher obtains a complete Git checkout first.
if (!(Test-Path -LiteralPath $mainScript)) {
  if ($inspection) { throw 'Download or clone the complete dotfiles checkout before inspecting it.' }
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

foreach ($name in @('python3', 'python', 'py', (Join-Path $env:USERPROFILE '.local/bin/python3.12.exe'))) {
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
if ($inspection) { throw 'Python 3.10+ is required for inspection. Run init.ps1 core to prepare the bootstrap runtime.' }
$stateRoot = $env:XDG_STATE_HOME
if (!$stateRoot) { $stateRoot = Join-Path $env:LOCALAPPDATA 'State' }
$dataRoot = $env:XDG_DATA_HOME
if (!$dataRoot) { $dataRoot = Join-Path $env:USERPROFILE '.local/share' }
$cacheRoot = $env:XDG_CACHE_HOME
if (!$cacheRoot) { $cacheRoot = Join-Path $env:LOCALAPPDATA 'Cache' }
$env:UV_INSTALL_DIR = Join-Path $env:USERPROFILE '.local/bin'
$env:UV_NO_MODIFY_PATH = '1'
$env:UV_PYTHON_INSTALL_DIR = Join-Path $dataRoot 'uv/python'
$env:UV_CACHE_DIR = Join-Path $cacheRoot 'uv'
$env:UV_PYTHON_BIN_DIR = $env:UV_INSTALL_DIR
$runtimeDir = Join-Path $stateRoot ('dotfiles/bootstrap/runtime-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
$runtimeLog = Join-Path $runtimeDir 'output.log'
Write-Host "Preparing Python runtime...`nLog: $runtimeLog"
# Windows PowerShell 5 treats redirected native stderr as ErrorRecords. Check
# the process exit code explicitly while preserving stderr diagnostics in the log.
function Invoke-RuntimeCommand {
  param([string]$Executable, [string[]]$Arguments, [switch]$Capture)
  $resolved = Get-Command $Executable -ErrorAction Stop
  $ErrorActionPreference = 'Continue'
  if ($Capture) {
    $value = & $resolved.Source @Arguments 2>> $runtimeLog
  } else {
    & $resolved.Source @Arguments *>> $runtimeLog
  }
  $code = $LASTEXITCODE
  if ($code -ne 0) { throw "Runtime command failed with exit code $code; see $runtimeLog" }
  if ($Capture) { return $value }
}
try {
  $uv = Get-Command uv -ErrorAction SilentlyContinue
  if ($uv) { $uvPath = $uv.Source } else { $uvPath = Join-Path $env:UV_INSTALL_DIR 'uv.exe' }
  if (!(Test-Path -LiteralPath $uvPath)) {
    $installer = Join-Path $runtimeDir 'install.ps1'
    Invoke-WebRequest -UseBasicParsing -Uri https://astral.sh/uv/install.ps1 -OutFile $installer
    Invoke-RuntimeCommand 'powershell.exe' @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer)
  }
  Invoke-RuntimeCommand $uvPath @('python', 'install', '3.12')
  $python = Invoke-RuntimeCommand $uvPath @('python', 'find', '--no-project', '--managed-python', '3.12') -Capture
} catch {
  $_ | Out-String | Add-Content -LiteralPath $runtimeLog
  Write-Error "Runtime setup failed. Details: $runtimeLog"
  exit 1
}
Write-Host 'Python runtime ready.'
& $python $mainScript @bootstrapArgs
exit $LASTEXITCODE
