Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
. (Join-Path $PSScriptRoot 'ClaudeCommon.ps1')

$outPath = Join-Path $outputDir 'price-indicators.csv'

# Incremental: only feed reports newer than what's already in the CSV, and
# append rather than re-read+rewrite everything every run. This is the
# dominant cost driver once more than a handful of daily reports exist.
$processedDates = if (Test-Path -LiteralPath $outPath) {
    @(Import-Csv -LiteralPath $outPath | ForEach-Object { $_.report_date } | Sort-Object -Unique)
} else { @() }
$maxProcessed = if ($processedDates.Count -gt 0) { $processedDates[-1] } else { $null }

$newReports = @(Get-ChildItem -LiteralPath $outputDir -Filter '*-briefing.md' -File |
    Where-Object { $_.BaseName -match '^\d{4}-\d{2}-\d{2}-briefing$' } |
    Where-Object { -not $maxProcessed -or ($_.BaseName.Substring(0, 10) -gt $maxProcessed) } |
    Sort-Object Name)

if ($newReports.Count -eq 0) {
    Write-Host "No new reports since $maxProcessed; skipping Claude call entirely."
} else {
    $fileList = ($newReports | ForEach-Object { "output/$($_.Name)" }) -join ', '
    Push-Location $projectRoot
    try {
        $prompt = "Read only these new report files: $fileList. Extract every explicit price, supply, capacity, or demand data point mentioned (spot price, contract price, LTA terms, capacity expansion, shortage/oversupply commentary, CapEx figures tied to a specific company). Do not read or re-process any other report files. Read the existing output/price-indicators.csv (if present) to see its exact column format and header: report_date,product,indicator,value,unit,trend,source_tier. product is one of DRAM, NAND, HBM, GPU, CapEx, Foundry, Other. trend is one of up, down, flat, unclear. source_tier matches this project's AGENTS.md source-tier labels (1차 원문, 산업 데이터, 주요 보도). Append new rows for the new reports only to the end of output/price-indicators.csv -- do not modify, reorder, or duplicate existing rows. If the file does not exist yet, create it with the header row first. Only include rows backed by an actual number or an explicit qualitative statement in the source report; never invent a number. Use en dash, not tilde, for ranges."
        $ok = Invoke-ClaudeTask -Prompt $prompt -ExpectedOutputPath $outPath -OutputDir $outputDir -LogPrefix 'price-indicators'
        if (-not $ok) { throw "Price indicator extraction failed after retries. See output/price-indicators-*.err.log" }
    } finally {
        Pop-Location
    }
    Write-Host "Price indicators updated with $($newReports.Count) new report(s): $outPath"
}
& (Join-Path $PSScriptRoot 'Publish-GitHub.ps1') -BriefingPath $outPath
