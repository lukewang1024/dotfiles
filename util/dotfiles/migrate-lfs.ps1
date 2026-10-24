# Native Windows entrypoint; the migration implementation is shared with POSIX.
$ErrorActionPreference = 'Stop'
try {
    $runtimes = @('python3', 'python')
    $runtime = $null
    foreach ($candidate in $runtimes) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if (-not $command) { continue }
        & $command.Source -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>$null
        if ($LASTEXITCODE -eq 0) { $runtime = $command.Source; break }
    }
    if (-not $runtime) { throw 'Python 3.10+ is required; install Python and retry.' }
    $local = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'migrate-lfs' } else { $null }
    if ($local -and (Test-Path -LiteralPath $local)) {
        $source = [IO.File]::ReadAllText($local)
    } else {
        $source = (Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/lukewang1024/dotfiles/main/util/dotfiles/migrate-lfs').Content
    }
    $match = [regex]::Match($source, "(?ms)<<'PY'\r?\n(.*?)^PY\r?$")
    if (-not $match.Success) { throw 'Downloaded migration program is incomplete.' }
    & $runtime -c ($match.Groups[1].Value) @args
    exit $LASTEXITCODE
} catch {
    Write-Error $_
    exit 1
}
