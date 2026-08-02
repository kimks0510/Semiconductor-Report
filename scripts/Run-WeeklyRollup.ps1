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
$mondayStr = $monday.ToString('yyyy-MM-dd')
$fridayStr = $friday.ToString('yyyy-MM-dd')
$weekKey = $mondayStr
$outPath = Join-Path $weeklyDir "$weekKey-rollup.md"

if (Test-Path -LiteralPath $outPath) {
    Write-Host "Weekly rollup already exists: $outPath"
    return
}

# Pre-digest: pull only this week's rows out of the already-extracted
# structured artifacts (cheap local filtering, no LLM) so Claude gets a
# compact, curated slice instead of reopening every raw daily briefing.
$priceContext = ''
$pricePath = Join-Path $outputDir 'price-indicators.csv'
if (Test-Path -LiteralPath $pricePath) {
    $rows = @(Import-Csv -LiteralPath $pricePath | Where-Object { $_.report_date -ge $mondayStr -and $_.report_date -le $fridayStr })
    if ($rows.Count -gt 0) {
        $lines = $rows | ForEach-Object { "- $($_.report_date) [$($_.product)] $($_.indicator): $($_.value) $($_.unit) ($($_.trend), $($_.source_tier))" }
        $priceContext = "### Price/supply indicators for this week`n" + ($lines -join "`n")
    }
}

$competitorContext = ''
$competitorPath = Join-Path $outputDir 'competitor-timeline.md'
if (Test-Path -LiteralPath $competitorPath) {
    $lines = Get-Content -LiteralPath $competitorPath -Encoding UTF8
    $sectionLines = New-Object System.Collections.Generic.List[string]
    $inRange = $false
    foreach ($line in $lines) {
        if ($line -match '^## (\d{4}-\d{2}-\d{2})') {
            $inRange = ($Matches[1] -ge $mondayStr -and $Matches[1] -le $fridayStr)
        }
        if ($inRange) { $sectionLines.Add($line) }
    }
    if ($sectionLines.Count -gt 0) {
        $competitorContext = "### Competitor timeline entries for this week`n" + ($sectionLines -join "`n")
    }
}

$structuredContext = @($priceContext, $competitorContext) | Where-Object { $_ } | ForEach-Object { $_ }
$structuredBlock = if ($structuredContext) { ($structuredContext -join "`n`n") } else { '(no pre-extracted structured data available for this week yet)' }

Push-Location $projectRoot
try {
    $prompt = "Write a Korean weekly rollup for a Samsung Electronics MX division overseas sales employee preparing to move into SK hynix's GSM (Global Sales & Marketing) role, covering $mondayStr through $fridayStr. Use the following pre-extracted structured data as your primary source -- it is already curated from this week's reports, so prefer it over reopening raw files:`n`n$structuredBlock`n`nOnly read the underlying output/*-briefing.md files for this week if the structured data above is empty or you need specific narrative context (e.g. an exact quote) that isn't captured in it -- do not read raw reports as a matter of course. Map this week's news to concrete GSM competencies: pricing/negotiation, demand forecasting, customer allocation, competitive positioning. For each competency give 1-3 bullet points grounded in specific facts and dates, not generic statements. Follow this project's AGENTS.md conventions: cite source tiers, separate confirmed facts from estimates, explain acronyms on first use, use an en dash for numeric ranges (never a tilde). End with a one-sentence interview soundbite under the heading '## 면접용 한 문장'. Save the result to output/weekly/$weekKey-rollup.md. If the structured data above is empty and there are fewer than 2 daily reports this week, state that data is too sparse for a full rollup and summarize what is available instead of inventing trends."
    $ok = Invoke-ClaudeTask -Prompt $prompt -ExpectedOutputPath $outPath -OutputDir $weeklyDir -LogPrefix 'weekly-rollup'
    if (-not $ok) { throw "Weekly rollup failed after retries. See $weeklyDir\weekly-rollup-*.err.log" }
} finally {
    Pop-Location
}
Write-Host "Weekly rollup saved to $outPath"
& (Join-Path $PSScriptRoot 'Publish-GitHub.ps1') -BriefingPath $outPath
