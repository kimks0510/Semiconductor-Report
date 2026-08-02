Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
$weeklyDir = Join-Path $outputDir 'weekly'
. (Join-Path $PSScriptRoot 'ClaudeCommon.ps1')

$latestRollup = Get-ChildItem -LiteralPath $weeklyDir -Filter '*-rollup.md' -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $latestRollup) { throw 'No weekly rollup found. Run Run-WeeklyRollup.ps1 first.' }
$weekKey = $latestRollup.BaseName -replace '-rollup$', ''
$outPath = Join-Path $weeklyDir "$weekKey-interview-qa.md"

if (Test-Path -LiteralPath $outPath) {
    Write-Host "Interview Q&A already exists: $outPath"
    return
}

Push-Location $projectRoot
try {
    $prompt = "Read output/weekly/$weekKey-rollup.md and, for supporting detail, the underlying output/*-briefing.md reports for that same week. Generate 6-10 likely SK hynix GSM (Global Sales & Marketing) job interview questions in Korean that a hiring manager could ask based on this week's semiconductor industry developments. After each question, write a strong 3-5 sentence Korean model answer draft for a candidate transitioning from Samsung Electronics MX division overseas sales, grounded in this week's specific facts, numbers, and dates -- not generic career-fair answers. Save the result to output/weekly/$weekKey-interview-qa.md."
    $ok = Invoke-ClaudeTask -Prompt $prompt -ExpectedOutputPath $outPath -OutputDir $weeklyDir -LogPrefix 'interview-qa'
    if (-not $ok) { throw "Interview Q&A generation failed after retries. See $weeklyDir\interview-qa-*.err.log" }
} finally {
    Pop-Location
}
Write-Host "Interview Q&A saved to $outPath"
& (Join-Path $PSScriptRoot 'Publish-GitHub.ps1') -BriefingPath $outPath
