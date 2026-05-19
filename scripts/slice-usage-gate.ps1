param(
  [ValidateSet("codex", "claude")]
  [string] $Agent = "codex",
  [string] $ClaudeUsagePath = "$HOME\.claude\usage.json",
  [double] $ClaudeFiveHourThreshold = 85,
  [double] $ClaudeSevenDayThreshold = 80
)

$ErrorActionPreference = "Stop"

function Write-Result {
  param(
    [string] $AgentName,
    [string] $Decision,
    [string] $Reason,
    [object] $Details = $null
  )

  $payload = [ordered]@{
    agent = $AgentName
    decision = $Decision
    reason = $Reason
    details = $Details
  }

  $payload | ConvertTo-Json -Depth 8
}

if ($Agent -eq "codex") {
  $output = & usage-gate guard --provider codex --json 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Result -AgentName "codex" -Decision "unavailable" -Reason "usage-gate command failed" -Details @{ output = ($output -join "`n") }
    exit 3
  }

  try {
    $json = $output | ConvertFrom-Json
  } catch {
    Write-Result -AgentName "codex" -Decision "unavailable" -Reason "usage-gate returned invalid JSON" -Details @{ output = ($output -join "`n") }
    exit 3
  }

  if ($json.decision -eq "continue") {
    Write-Result -AgentName "codex" -Decision "continue" -Reason "usage gate allows next slice" -Details $json
    exit 0
  }

  Write-Result -AgentName "codex" -Decision "pause" -Reason "usage gate does not allow next slice" -Details $json
  exit 2
}

if (-not (Test-Path -LiteralPath $ClaudeUsagePath)) {
  Write-Result -AgentName "claude" -Decision "unavailable" -Reason "Claude usage file not found" -Details @{ path = $ClaudeUsagePath }
  exit 3
}

try {
  $usage = Get-Content -LiteralPath $ClaudeUsagePath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
  Write-Result -AgentName "claude" -Decision "unavailable" -Reason "Claude usage file is not valid JSON" -Details @{ path = $ClaudeUsagePath }
  exit 3
}

$fiveHour = $usage.rate_limits.five_hour.used_percentage
$sevenDay = $usage.rate_limits.seven_day.used_percentage

if ($null -eq $fiveHour -or $null -eq $sevenDay) {
  Write-Result -AgentName "claude" -Decision "unavailable" -Reason "Claude usage fields are missing or null" -Details @{ path = $ClaudeUsagePath }
  exit 3
}

if ([double]$fiveHour -ge $ClaudeFiveHourThreshold -or [double]$sevenDay -ge $ClaudeSevenDayThreshold) {
  Write-Result -AgentName "claude" -Decision "pause" -Reason "Claude usage reached threshold" -Details @{
    five_hour_used_percentage = [double]$fiveHour
    seven_day_used_percentage = [double]$sevenDay
    five_hour_threshold = $ClaudeFiveHourThreshold
    seven_day_threshold = $ClaudeSevenDayThreshold
  }
  exit 2
}

Write-Result -AgentName "claude" -Decision "continue" -Reason "Claude usage is below thresholds" -Details @{
  five_hour_used_percentage = [double]$fiveHour
  seven_day_used_percentage = [double]$sevenDay
  five_hour_threshold = $ClaudeFiveHourThreshold
  seven_day_threshold = $ClaudeSevenDayThreshold
}
exit 0
