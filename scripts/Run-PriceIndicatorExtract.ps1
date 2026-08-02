Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
$outPath = Join-Path $outputDir 'price-indicators.csv'

Push-Location (Join-Path $projectRoot 'pipeline')
try {
    & python extract_price_indicators.py
    if ($LASTEXITCODE -ne 0) { throw "extract_price_indicators.py failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}
& (Join-Path $PSScriptRoot 'Publish-GitHub.ps1') -BriefingPath $outPath
