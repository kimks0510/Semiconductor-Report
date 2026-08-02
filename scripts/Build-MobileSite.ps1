param([Parameter(Mandatory=$true)][string]$BriefingPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputRoot = Join-Path $projectRoot 'output'
$weeklyRoot = Join-Path $outputRoot 'weekly'
$docsRoot = Join-Path $projectRoot 'docs'
$reportsRoot = Join-Path $docsRoot 'reports'
New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null

$resolvedBriefing = (Resolve-Path -LiteralPath $BriefingPath).Path
if (-not $resolvedBriefing.StartsWith((Resolve-Path -LiteralPath $outputRoot).Path, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Briefing must be located inside the output directory.'
}

function ConvertTo-MarkdownTable([string]$CsvPath) {
    $rows = Import-Csv -LiteralPath $CsvPath
    if (-not $rows) { return '(no data)' }
    $cols = $rows[0].PSObject.Properties.Name
    $lines = @("| $($cols -join ' | ') |", "|$(($cols | ForEach-Object { '---' }) -join '|')|")
    foreach ($row in $rows) { $lines += "| $(($cols | ForEach-Object { $row.$_ }) -join ' | ') |" }
    return $lines -join "`n"
}

$entries = New-Object System.Collections.Generic.List[object]

# Daily briefings (semiconductor + Korean Air share the same viewer contract)
Get-ChildItem -LiteralPath $outputRoot -Filter '*-briefing.md' -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $reportsRoot $_.Name) -Force
    if ($_.Name -match '^(\d{4}-\d{2}-\d{2})-briefing\.md$') {
        $entries.Add([ordered]@{ id = $Matches[1]; file = $_.Name; type = 'daily'; label = $Matches[1]; date = $Matches[1] })
    }
}

# Term glossary
$termsPath = Join-Path $outputRoot 'terms.md'
if (Test-Path -LiteralPath $termsPath) {
    Copy-Item -LiteralPath $termsPath -Destination (Join-Path $reportsRoot 'terms.md') -Force
    $entries.Add([ordered]@{ id = 'terms'; file = 'terms.md'; type = 'glossary'; label = 'GSM 누적 용어 사전'; date = (Get-Item $termsPath).LastWriteTime.ToString('yyyy-MM-dd') })
}

# Competitor timeline
$competitorPath = Join-Path $outputRoot 'competitor-timeline.md'
if (Test-Path -LiteralPath $competitorPath) {
    Copy-Item -LiteralPath $competitorPath -Destination (Join-Path $reportsRoot 'competitor-timeline.md') -Force
    $entries.Add([ordered]@{ id = 'competitor-timeline'; file = 'competitor-timeline.md'; type = 'competitor-timeline'; label = '경쟁사 타임라인'; date = (Get-Item $competitorPath).LastWriteTime.ToString('yyyy-MM-dd') })
}

# Price indicators (CSV -> rendered as a markdown table)
$pricePath = Join-Path $outputRoot 'price-indicators.csv'
if (Test-Path -LiteralPath $pricePath) {
    $md = "# 가격.공급 지표`n`n" + (ConvertTo-MarkdownTable $pricePath)
    Set-Content -LiteralPath (Join-Path $reportsRoot 'price-indicators.md') -Value $md -Encoding UTF8
    $entries.Add([ordered]@{ id = 'price-indicators'; file = 'price-indicators.md'; type = 'price-indicators'; label = '가격.공급 지표'; date = (Get-Item $pricePath).LastWriteTime.ToString('yyyy-MM-dd') })
}

# Weekly rollups and interview Q&A
if (Test-Path -LiteralPath $weeklyRoot) {
    Get-ChildItem -LiteralPath $weeklyRoot -Filter '*-rollup.md' -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $reportsRoot $_.Name) -Force
        if ($_.Name -match '^(\d{4}-\d{2}-\d{2})-rollup\.md$') {
            $entries.Add([ordered]@{ id = "weekly-$($Matches[1])"; file = $_.Name; type = 'weekly-rollup'; label = "주간 GSM 롤업 $($Matches[1])"; date = $Matches[1] })
        }
    }
    Get-ChildItem -LiteralPath $weeklyRoot -Filter '*-interview-qa.md' -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $reportsRoot $_.Name) -Force
        if ($_.Name -match '^(\d{4}-\d{2}-\d{2})-interview-qa\.md$') {
            $entries.Add([ordered]@{ id = "interview-$($Matches[1])"; file = $_.Name; type = 'interview-qa'; label = "모의 면접 Q&A $($Matches[1])"; date = $Matches[1] })
        }
    }
}

$sorted = @($entries | Sort-Object date -Descending)
ConvertTo-Json -InputObject $sorted -Depth 3 | Set-Content -LiteralPath (Join-Path $docsRoot 'reports.json') -Encoding UTF8
Write-Host "Mobile site index updated with $($sorted.Count) entries."
