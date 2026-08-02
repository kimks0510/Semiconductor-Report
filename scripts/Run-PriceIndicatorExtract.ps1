Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
. (Join-Path $PSScriptRoot 'CodexCommon.ps1')

$outPath = Join-Path $outputDir 'price-indicators.csv'

Push-Location $projectRoot
try {
    $prompt = "Read every output/*-briefing.md file in this project. Extract every explicit price, supply, capacity, or demand data point mentioned (spot price, contract price, LTA terms, capacity expansion, shortage/oversupply commentary, CapEx figures tied to a specific company). Overwrite output/price-indicators.csv from scratch with a header row and columns: report_date,product,indicator,value,unit,trend,source_tier. product is one of DRAM, NAND, HBM, GPU, CapEx, Foundry, Other. trend is one of up, down, flat, unclear. source_tier matches this project's AGENTS.md source-tier labels (1차 원문, 산업 데이터, 주요 보도). Only include rows backed by an actual number or an explicit qualitative statement in the source report; never invent a number. Use en dash, not tilde, for ranges. Save the file as output/price-indicators.csv."
    $ok = Invoke-CodexTask -Prompt $prompt -ExpectedOutputPath $outPath -OutputDir $outputDir -LogPrefix 'price-indicators'
    if (-not $ok) { throw "Price indicator extraction failed after retries. See output/price-indicators-*.err.log" }
} finally {
    Pop-Location
}
Write-Host "Price indicators saved to $outPath"
