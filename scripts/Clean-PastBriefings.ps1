param([string]$Only)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
$logPath = Join-Path $outputDir 'clean-past-briefings.log'
. (Join-Path $PSScriptRoot 'ClaudeCommon.ps1')

function Write-Log {
    param([string]$Message)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" | Tee-Object -FilePath $logPath -Append
}

# Same keyword set used to scope this cleanup in the first place. A file with
# zero hits either never had stock content or was already cleaned by an
# earlier run of this script -- either way, skip it without spending a call.
$stockPattern = '주가|코스피|나스닥.*지수|외국인.*순매|기관.*순매|개인.*순매|자사주|목표주가|투자의견|시가총액|신고가|신저가|상한가|하한가'

function Test-HasStockContent([string]$Path) {
    $hits = Select-String -LiteralPath $Path -Pattern $stockPattern -AllMatches
    return @($hits).Count
}

# 2026-09-24 is excluded: it already complies (its 3 keyword hits are the
# file's own meta-notes explaining what was excluded, not real stock content
# -- confirmed by manual review), so it must not be re-edited.
$files = Get-ChildItem -LiteralPath $outputDir -Filter '*-briefing.md' -File |
    Where-Object { $_.BaseName -match '^\d{4}-\d{2}-\d{2}-briefing$' -and $_.BaseName -ne '2026-09-24-briefing' } |
    Sort-Object Name
if ($Only) { $files = $files | Where-Object { $_.Name -eq $Only } }

$needsReview = @()
foreach ($file in $files) {
    $before = Test-HasStockContent $file.FullName
    if ($before -eq 0) {
        Write-Log "SKIP $($file.Name) (no stock-market keywords found)"
        continue
    }

    Write-Log "CLEAN $($file.Name) (found $before stock-market keyword hit(s))"
    $relPath = "output/$($file.Name)"
    $prompt = "Read $relPath. This project's AGENTS.md now has a '증시 내용 금지' rule (added 2026-09-24) excluding stock-market content: stock prices, price percentage changes, new highs/lows, market cap, KOSPI/NASDAQ index movements, foreign/institutional/individual net buying-selling, treasury stock buybacks or cancellations as a market-support action, dividends, target prices, brokerage investment opinions, and narrative like '반도체주 상승' or '투자심리 개선'. This file predates that rule and contains such content somewhere in its '3줄 총평', '누적 인사이트', 'Kakao Summary', article bodies, or glossary table. Remove all of it and rewrite the surrounding sentences so they read cleanly, with no gaps, dangling references, or leftover transition words that assumed the removed content. Two important exceptions -- do NOT remove these even though they share keywords with excluded content: (1) DRAM/NAND/HBM spot or contract PRODUCT prices (판매가격, e.g. TrendForce spot price data) -- these are product prices, not stock prices; (2) 자사주 used in an employee-compensation or labor-relations context (e.g. 성과급을 자사주로 지급, PS 지급 방식을 둘러싼 노사 갈등) -- this is organizational/labor content, not a stock-buyback market signal, and is valuable GSM interview material that must stay. A passing mention of 실적·주가 inside an otherwise legitimate non-market insight (e.g. a labor-relations point) does not require deleting the whole sentence -- only remove content whose actual subject is the stock price movement itself. If an entire bullet or sentence's sole subject was stock moves, delete that bullet/sentence entirely rather than leaving a stub. Do not change the filename, the date in the title, or any unrelated content. Save the edited file back to the exact same path: $relPath."

    Push-Location $projectRoot
    try {
        $ok = Invoke-ClaudeTask -Prompt $prompt -ExpectedOutputPath $file.FullName -OutputDir $outputDir -LogPrefix "clean-$($file.BaseName)" -AllowedTools 'Read,Edit'
    } finally {
        Pop-Location
    }

    if (-not $ok) {
        Write-Log "FAIL $($file.Name) -- Invoke-ClaudeTask reported failure after retries"
        $needsReview += $file.Name
        continue
    }

    $after = Test-HasStockContent $file.FullName
    if ($after -eq 0) {
        Write-Log "OK $($file.Name) (0 hits remaining)"
    } else {
        Write-Log "PARTIAL $($file.Name) ($after hit(s) still remain -- needs manual review)"
        $needsReview += $file.Name
    }
}

Write-Log "DONE. $($needsReview.Count) file(s) need manual review: $($needsReview -join ', ')"
