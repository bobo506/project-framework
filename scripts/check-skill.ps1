param(
  [string] $SkillPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "SKILL.md"),
  [switch] $SkipGitDiffCheck
)

$ErrorActionPreference = "Stop"
$errors = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $SkillPath)) {
  Write-Error "SKILL.md not found: $SkillPath"
  exit 1
}

$resolvedSkill = (Resolve-Path -LiteralPath $SkillPath).Path
$content = Get-Content -LiteralPath $resolvedSkill -Raw -Encoding UTF8
$lines = Get-Content -LiteralPath $resolvedSkill -Encoding UTF8

if ($content -notmatch '(?s)\A---\s*\r?\n(?<frontmatter>.*?)\r?\n---') {
  $errors.Add("SKILL.md must start with YAML frontmatter.")
} else {
  $frontmatter = $Matches["frontmatter"]
  if ($frontmatter -notmatch '(?m)^name:\s*\S+') {
    $errors.Add("Frontmatter is missing required 'name'.")
  }
  if ($frontmatter -notmatch '(?m)^description:\s*.+') {
    $errors.Add("Frontmatter is missing required 'description'.")
  }
}

$conflictMarkers = $lines | Select-String -Pattern '^(<<<<<<<|=======|>>>>>>>)'
if ($conflictMarkers) {
  $errors.Add(("Conflict markers found:`n{0}" -f ($conflictMarkers -join "`n")))
}

$fenceCount = ($lines | Select-String -Pattern '^\s*```').Count
if (($fenceCount % 2) -ne 0) {
  $errors.Add("Markdown code fences are not balanced. Fence count: $fenceCount")
}

if (-not $SkipGitDiffCheck) {
  $repoRoot = Split-Path $resolvedSkill -Parent
  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $diffCheck = & git -C $repoRoot diff --check 2>&1
  $gitExitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldErrorActionPreference
  if ($gitExitCode -ne 0) {
    $errors.Add(("git diff --check failed:`n{0}" -f ($diffCheck -join "`n")))
  }
}

if ($errors.Count -gt 0) {
  Write-Error ($errors -join "`n`n")
  exit 1
}

Write-Output "Skill check passed."
exit 0
