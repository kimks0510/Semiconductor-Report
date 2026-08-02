param([string]$WeekStart)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
$weeklyDir = Join-Path $outputDir 'weekly'
New-Item -ItemType Directory -Path $weeklyDir -Force | Out-Null
. (Join-Path $PSScriptRoot 'ClaudeCommon.ps1')

if ($WeekStart) {
    $monday = [datetime]$WeekStart
} else {
    $today = Get-Date
    $dow = [int]$today.DayOfWeek
    $offsetToMonday = if ($dow -eq 0) { -6 } else { 1 - $dow }
    $monday = $today.Date.AddDays($offsetToMonday)
}
$friday = $monday.AddDays(4)
$weekKey = $monday.ToString('yyyy-MM-dd')
$outPath = Join-Path $weeklyDir "$weekKey-rollup.md"

if (Test-Path -LiteralPath $outPath) {
    Write-Host "Weekly rollup already exists: $outPath"
    return
}

Push-Location $projectRoot
try {
    $prompt = "Read every output/*-briefing.md dated between $($monday.ToString('yyyy-MM-dd')) and $($friday.ToString('yyyy-MM-dd')) inclusive (skip any missing dates). Write a Korean weekly rollup for a Samsung Electronics MX division overseas sales employee preparing to move into SK hynix's GSM (Global Sales & Marketing) role. Map this week's news to concrete GSM competencies: pricing/negotiation, demand forecasting, customer allocation, competitive positioning. For each competency give 1-3 bullet points grounded in specific facts and dates from this week's reports, not generic statements. Follow this project's AGENTS.md conventions: cite source tiers, separate confirmed facts from estimates, explain acronyms on first use, use an en dash for numeric ranges (never a tilde). Save the result to output/weekly/$weekKey-rollup.md. If fewer than 2 daily reports exist for this week, state that data is too sparse for a full rollup and summarize what is available instead of inventing trends."
    $ok = Invoke-ClaudeTask -Prompt $prompt -ExpectedOutputPath $outPath -OutputDir $weeklyDir -LogPrefix 'weekly-rollup'
    if (-not $ok) { throw "Weekly rollup failed after retries. See $weeklyDir\weekly-rollup-*.err.log" }
} finally {
    Pop-Location
}
Write-Host "Weekly rollup saved to $outPath"
& (Join-Path $PSScriptRoot 'Publish-GitHub.ps1') -BriefingPath $outPath
