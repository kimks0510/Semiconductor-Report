Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
$outPath = Join-Path $outputDir 'competitor-timeline.md'

Push-Location (Join-Path $projectRoot 'pipeline')
try {
    & python extract_competitor_events.py
    if ($LASTEXITCODE -ne 0) { throw "extract_competitor_events.py failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}
& (Join-Path $PSScriptRoot 'Publish-GitHub.ps1') -BriefingPath $outPath
