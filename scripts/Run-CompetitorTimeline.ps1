Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
. (Join-Path $PSScriptRoot 'CodexCommon.ps1')

$outPath = Join-Path $outputDir 'competitor-timeline.md'

Push-Location $projectRoot
try {
    $prompt = "Read every output/*-briefing.md file in this project. Build a Korean chronological timeline comparing Samsung Electronics, SK hynix, and Micron: earnings/conference-call statements, contracts and LTAs, capacity or CapEx announcements, and product/roadmap claims (HBM, DRAM, NAND). Group entries by date, tag each with the company name and source tier (per this project's AGENTS.md), and end each entry with a one-line note on what it means for competitive positioning from a GSM (Global Sales & Marketing) sales angle. Overwrite output/competitor-timeline.md from scratch. Use en dash, not tilde, for numeric ranges. Do not invent statements not present in the source reports."
    $ok = Invoke-CodexTask -Prompt $prompt -ExpectedOutputPath $outPath -OutputDir $outputDir -LogPrefix 'competitor-timeline'
    if (-not $ok) { throw "Competitor timeline generation failed after retries. See output/competitor-timeline-*.err.log" }
} finally {
    Pop-Location
}
Write-Host "Competitor timeline saved to $outPath"
