Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
$glossaryPath = Join-Path $outputDir 'terms.md'

$terms = [ordered]@{}
Get-ChildItem -LiteralPath $outputDir -Filter '*-briefing.md' | Sort-Object Name | ForEach-Object {
    $reportDate = $_.BaseName -replace '-briefing$', ''
    $lines = Get-Content -LiteralPath $_.FullName -Encoding UTF8
    $inTable = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*\|.*용어.*\|.*뜻.*\|') { $inTable = $true; continue }
        if ($inTable -and $line -match '^\s*\|\s*[-:]+\s*\|') { continue }
        if ($inTable -and $line -notmatch '^\s*\|') { $inTable = $false; continue }
        if (-not $inTable) { continue }
        $cols = ($line.Trim().Trim('|')) -split '\|' | ForEach-Object { $_.Trim() }
        if ($cols.Count -lt 2 -or [string]::IsNullOrWhiteSpace($cols[0])) { continue }
        $term = $cols[0] -replace '\*\*', ''
        $meaning = $cols[1]
        if (-not $terms.Contains($term)) {
            $terms[$term] = [ordered]@{ meaning = $meaning; dates = @() }
        }
        $terms[$term].dates += $reportDate
    }
}

$out = @('# 누적 용어 사전', '', "생성 시각: $(Get-Date -Format 'yyyy-MM-dd HH:mm')", '', '| 용어 | 쉬운 뜻 | 등장 날짜 |', '|---|---|---|')
foreach ($term in $terms.Keys) {
    $t = $terms[$term]
    $out += "| $term | $($t.meaning) | $($t.dates -join ', ') |"
}
$out -join "`n" | Set-Content -LiteralPath $glossaryPath -Encoding UTF8
Write-Host "$($terms.Count)개 용어를 $glossaryPath 에 저장했습니다."
