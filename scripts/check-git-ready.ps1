param(
  [string] $ProjectRoot = (Get-Location).Path,
  [switch] $SkipProgress
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$errors = New-Object System.Collections.Generic.List[string]

function Add-ErrorLines {
  param([string] $Header, [string[]] $Lines)
  if ($Lines.Count -gt 0) {
    $errors.Add($Header + "`n" + ($Lines -join "`n"))
  }
}

$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$conflictOutput = & git -C $root grep -n -E "^(<<<<<<<|=======|>>>>>>>)" -- . 2>$null
$gitGrepExitCode = $LASTEXITCODE
$ErrorActionPreference = $oldErrorActionPreference
if ($gitGrepExitCode -eq 0) {
  Add-ErrorLines -Header "Conflict markers found:" -Lines $conflictOutput
} elseif ($gitGrepExitCode -ne 1) {
  $errors.Add("Unable to scan for conflict markers.")
}

$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$diffCheck = & git -C $root diff --check 2>&1
$gitDiffExitCode = $LASTEXITCODE
$ErrorActionPreference = $oldErrorActionPreference
if ($gitDiffExitCode -ne 0) {
  Add-ErrorLines -Header "git diff --check failed:" -Lines $diffCheck
}

if (-not $SkipProgress) {
  $progressScript = Join-Path $PSScriptRoot "check-progress.ps1"
  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $progressOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $progressScript -ProjectRoot $root -Json 2>&1
  $progressExitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldErrorActionPreference
  if ($progressExitCode -ne 0) {
    $errors.Add(("Progress check failed or no progress file exists. If this repository intentionally has no progress file, rerun with -SkipProgress.`n{0}" -f ($progressOutput -join "`n")))
  }
}

if ($errors.Count -gt 0) {
  Write-Error ($errors -join "`n`n")
  exit 1
}

Write-Output "Git readiness check passed."
exit 0
