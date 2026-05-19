param(
  [string] $ProjectRoot = (Get-Location).Path,
  [switch] $Strict,
  [switch] $RequireHistory,
  [switch] $Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$progressCandidates = @(
  "docs\PROGRESS.md",
  "docs\进度.md",
  "PROGRESS.md",
  "进度.md",
  "docs\status.md",
  "STATUS.md"
)

$historyCandidates = @(
  "docs\PROGRESS_HISTORY.md",
  "PROGRESS_HISTORY.md",
  "docs\进度历史.md",
  "进度历史.md"
)

function Find-FirstExisting {
  param([string[]] $RelativePaths)
  foreach ($relative in $RelativePaths) {
    $path = Join-Path $root $relative
    if (Test-Path -LiteralPath $path) {
      return $path
    }
  }
  return $null
}

$progressPath = Find-FirstExisting -RelativePaths $progressCandidates
$historyPath = Find-FirstExisting -RelativePaths $historyCandidates

if (-not $progressPath) {
  $errors.Add("No progress file found. Expected one of: $($progressCandidates -join ', ')")
} else {
  $content = Get-Content -LiteralPath $progressPath -Raw -Encoding UTF8
  if ($Strict) {
    $requiredPatterns = [ordered]@{
      "Latest/current section" = "(?im)^##\s+(Latest|最新|当前|Current)"
      "Current progress" = "(?i)(Current Progress|当前进度|当前阶段|已完成)"
      "Next plan" = "(?i)(Next Plan|下一步|后续计划)"
      "Verification" = "(?i)(Verification|验证|测试)"
      "Changed files" = "(?i)(Changed Files|变更文件|修改文件)"
    }

    foreach ($name in $requiredPatterns.Keys) {
      if ($content -notmatch $requiredPatterns[$name]) {
        $errors.Add("Progress file is missing required section: $name")
      }
    }
  }

  if ($content.Length -gt 20000) {
    $warnings.Add("Progress file is longer than 20000 characters; consider moving older records to history.")
  }
}

if ($RequireHistory -and -not $historyPath) {
  $errors.Add("No progress history file found. Expected one of: $($historyCandidates -join ', ')")
}

$result = [ordered]@{
  ok = ($errors.Count -eq 0)
  project_root = $root
  progress_file = $progressPath
  history_file = $historyPath
  errors = @($errors)
  warnings = @($warnings)
}

if ($Json) {
  $result | ConvertTo-Json -Depth 5
} else {
  if ($errors.Count -eq 0) {
    Write-Output "Progress check passed."
    if ($progressPath) { Write-Output "Progress: $progressPath" }
    if ($historyPath) { Write-Output "History: $historyPath" }
    foreach ($warning in $warnings) { Write-Warning $warning }
  } else {
    Write-Error ($errors -join "`n")
  }
}

if ($errors.Count -gt 0) { exit 1 }
exit 0
