Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'KakaoCommon.ps1')

$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
$weeklyDir = Join-Path $outputDir 'weekly'
$baseUrl = 'https://kimks0510.github.io/Semiconductor-Report/'

function Get-SectionText([string[]]$Lines, [string[]]$HeadingKeywords) {
    # AGENTS.md-style headings vary in exact wording (e.g. a sparse-data week
    # writes "## 한눈에 보는 제한적 결론" instead of "## 주간 결론"), so match by
    # keyword-in-heading rather than exact string, and fall back to the first
    # paragraph under the first H2 if no keyword heading is found at all.
    $idx = -1
    foreach ($kw in $HeadingKeywords) {
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            $line = $Lines[$i].Trim()
            if ($line -match '^## ' -and $line -like "*$kw*") { $idx = $i; break }
        }
        if ($idx -ge 0) { break }
    }
    if ($idx -lt 0) {
        for ($i = 0; $i -lt $Lines.Count; $i++) { if ($Lines[$i].Trim() -match '^## ') { $idx = $i; break } }
    }
    if ($idx -lt 0) { return $null }
    for ($i = $idx + 1; $i -lt $Lines.Count; $i++) {
        $t = $Lines[$i].Trim()
        if ($t -and $t -notmatch '^#') { return $t }
    }
    return $null
}

$messages = @()

# 1. Term glossary
$termsPath = Join-Path $outputDir 'terms.md'
if (Test-Path -LiteralPath $termsPath) {
    $count = (Get-Content -LiteralPath $termsPath -Encoding UTF8 | Where-Object { $_ -match '^\|' -and $_ -notmatch '용어.*뜻' -and $_ -notmatch '^\|---' }).Count
    $messages += @{ text = "[GSM 용어사전]`n누적 $count 개 용어 정리 완료."; id = 'terms' }
}

# 2. Price indicators
$pricePath = Join-Path $outputDir 'price-indicators.csv'
if (Test-Path -LiteralPath $pricePath) {
    $rows = (Get-Content -LiteralPath $pricePath -Encoding UTF8).Count - 1
    $messages += @{ text = "[가격.공급 지표]`n$rows 개 데이터포인트 추출 완료."; id = 'price-indicators' }
}

# 3. Competitor timeline
$competitorPath = Join-Path $outputDir 'competitor-timeline.md'
if (Test-Path -LiteralPath $competitorPath) {
    $entries = (Get-Content -LiteralPath $competitorPath -Encoding UTF8 | Where-Object { $_ -match '^### ' }).Count
    $messages += @{ text = "[경쟁사 타임라인]`n삼성.SK하이닉스.마이크론 $entries 건 정리."; id = 'competitor-timeline' }
}

# 4. Latest weekly rollup
$latestRollup = Get-ChildItem -LiteralPath $weeklyDir -Filter '*-rollup.md' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
if ($latestRollup) {
    $weekKey = $latestRollup.BaseName -replace '-rollup$', ''
    $lines = Get-Content -LiteralPath $latestRollup.FullName -Encoding UTF8
    $line = Get-SectionText -Lines $lines -HeadingKeywords @('면접용', '결론')
    if ($line) {
        $text = "[주간 GSM 롤업 $weekKey]`n$line"
        if ($text.Length -gt 200) { $text = $text.Substring(0, 197) + '...' }
        $messages += @{ text = $text; id = "weekly-$weekKey" }
    }
}

# 5. Latest interview Q&A
$latestQA = Get-ChildItem -LiteralPath $weeklyDir -Filter '*-interview-qa.md' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
if ($latestQA) {
    $qaWeekKey = $latestQA.BaseName -replace '-interview-qa$', ''
    $qaLines = Get-Content -LiteralPath $latestQA.FullName -Encoding UTF8
    $qCount = ($qaLines | Where-Object { $_ -match '^## \d+\.' }).Count
    $firstQ = ($qaLines | Where-Object { $_ -match '^## \d+\.' } | Select-Object -First 1) -replace '^## \d+\.\s*', ''
    $text = "[모의 면접 Q&A $qaWeekKey]`n$qCount 문항+모범답안. 1번: $firstQ"
    if ($text.Length -gt 200) { $text = $text.Substring(0, 197) + '...' }
    $messages += @{ text = $text; id = "interview-$qaWeekKey" }
}

if ($messages.Count -eq 0) { throw 'No knowledge artifacts found to send. Run the generator scripts first.' }

$headers = @{ Authorization = "Bearer $(Get-KakaoAccessToken)" }
foreach ($message in $messages) {
    if ($message.text.Length -gt 200) { throw "Message exceeds 200 chars: $($message.text)" }
    $url = "$baseUrl#$($message.id)"
    $template = @{
        object_type = 'text'
        text = $message.text
        link = @{ web_url = $url; mobile_web_url = $url }
        buttons = @(@{ title = '전체 보기'; link = @{ web_url = $url; mobile_web_url = $url } })
    } | ConvertTo-Json -Depth 5 -Compress
    $response = Invoke-RestMethod -Method Post -Uri 'https://kapi.kakao.com/v2/api/talk/memo/default/send' -Headers $headers -ContentType 'application/x-www-form-urlencoded;charset=utf-8' -Body @{ template_object = $template }
    if ($response.result_code -ne 0) { throw "Kakao send failed: $($response | ConvertTo-Json -Compress)" }
    Start-Sleep -Milliseconds 500
}
Write-Host "Sent $($messages.Count) knowledge digest messages to KakaoTalk."
