Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
. (Join-Path $PSScriptRoot 'ClaudeCommon.ps1')

$outPath = Join-Path $outputDir 'competitor-timeline.md'
$statePath = Join-Path $outputDir 'competitor-timeline-state.json'

# Incremental: the timeline groups entries by event date (which can differ
# from which report mentioned them), so we can't key off a simple max-date
# column like price-indicators.csv. Instead track which report files have
# already been fed to Claude for this artifact in a small sidecar state file.
$processedReports = if (Test-Path -LiteralPath $statePath) {
    @((Get-Content -LiteralPath $statePath -Encoding UTF8 -Raw | ConvertFrom-Json).processedReports)
} else { @() }

$newReports = @(Get-ChildItem -LiteralPath $outputDir -Filter '*-briefing.md' -File |
    Where-Object { $_.BaseName -match '^\d{4}-\d{2}-\d{2}-briefing$' } |
    Where-Object { $processedReports -notcontains $_.BaseName.Substring(0, 10) } |
    Sort-Object Name)

if ($newReports.Count -eq 0) {
    Write-Host "No new reports to add to the competitor timeline; skipping Claude call entirely."
} else {
    $fileList = ($newReports | ForEach-Object { "output/$($_.Name)" }) -join ', '
    Push-Location $projectRoot
    try {
        $prompt = "Read only these new report files: $fileList. Read the existing output/competitor-timeline.md if it exists. Build a Korean chronological timeline comparing Samsung Electronics, SK hynix, and Micron: earnings/conference-call statements, contracts and LTAs, capacity or CapEx announcements, and product/roadmap claims (HBM, DRAM, NAND). For each qualifying fact found in the new reports, add a new dated entry at the correct chronological position in output/competitor-timeline.md, tagged with the company name and source tier (per this project's AGENTS.md), ending with a one-line note on GSM (Global Sales & Marketing) competitive-positioning relevance. Skip a fact if an entry for the same date, company, and topic already exists in the file -- do not duplicate, rewrite, or remove existing entries. Use en dash, not tilde, for numeric ranges. Do not invent statements not present in the new reports. If the file does not exist yet, create it with a short header explaining the timeline's scope."
        $ok = Invoke-ClaudeTask -Prompt $prompt -ExpectedOutputPath $outPath -OutputDir $outputDir -LogPrefix 'competitor-timeline'
        if (-not $ok) { throw "Competitor timeline generation failed after retries. See output/competitor-timeline-*.err.log" }
    } finally {
        Pop-Location
    }
    $updatedProcessed = @($processedReports) + @($newReports | ForEach-Object { $_.BaseName.Substring(0, 10) }) | Sort-Object -Unique
    @{ processedReports = $updatedProcessed } | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
    Write-Host "Competitor timeline updated with $($newReports.Count) new report(s): $outPath"
}
& (Join-Path $PSScriptRoot 'Publish-GitHub.ps1') -BriefingPath $outPath
