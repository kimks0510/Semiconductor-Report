param([Parameter(Mandatory=$true)][string]$BriefingPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputRoot = Join-Path $projectRoot 'output'
$docsRoot = Join-Path $projectRoot 'docs'
$reportsRoot = Join-Path $docsRoot 'reports'
New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null

$resolvedBriefing = (Resolve-Path -LiteralPath $BriefingPath).Path
if (-not $resolvedBriefing.StartsWith((Resolve-Path -LiteralPath $outputRoot).Path, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Briefing must be located inside the output directory.'
}

Get-ChildItem -LiteralPath $outputRoot -Filter '*-briefing.md' -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $reportsRoot $_.Name) -Force
}

$entries = @(Get-ChildItem -LiteralPath $reportsRoot -Filter '*-briefing.md' -File | ForEach-Object {
    if ($_.Name -match '^(\d{4}-\d{2}-\d{2})-briefing\.md$') {
        [ordered]@{ date=$Matches[1]; file=$_.Name }
    }
} | Sort-Object date -Descending)
ConvertTo-Json -InputObject $entries -Depth 3 | Set-Content -LiteralPath (Join-Path $docsRoot 'reports.json') -Encoding UTF8
Write-Host "Mobile site index updated with $($entries.Count) report(s)."
