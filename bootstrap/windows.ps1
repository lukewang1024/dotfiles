
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
