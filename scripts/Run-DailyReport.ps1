param([switch]$Force)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
$errorLog = Join-Path $outputDir 'errors.log'
$date = Get-Date -Format 'yyyy-MM-dd'
$briefing = Join-Path $outputDir "$date-briefing.md"

# Cycle gate. The scheduled task now fires on every logon/unlock rather than
# at a fixed 08:00 (repeated live tests showed a time trigger fires during
# Modern Standby, where the process can't actually make progress and gets
# killed). So this decides whether *this* wake-up is one that should run.
#
# Anchors are Monday and Thursday. Run only if no briefing has been produced
# since the most recent anchor. That gives the deferral behaviour directly:
# skip Monday and Tuesday's first unlock runs it; once it has run for that
# cycle, later unlocks do nothing until the next anchor comes round.
function Get-CycleAnchor([datetime]$Now) {
    for ($i = 0; $i -lt 7; $i++) {
        $d = $Now.Date.AddDays(-$i)
        if ($d.DayOfWeek -eq [DayOfWeek]::Monday -or $d.DayOfWeek -eq [DayOfWeek]::Thursday) { return $d }
    }
    return $Now.Date
}

if (-not $Force) {
    $anchor = Get-CycleAnchor (Get-Date)
    $latestBriefingDate = Get-ChildItem -LiteralPath $outputDir -Filter '*-briefing.md' -ErrorAction SilentlyContinue |
        ForEach-Object { $_.BaseName -replace '-briefing$', '' } |
        Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' } |
        Sort-Object -Descending | Select-Object -First 1
    if ($latestBriefingDate -and ([datetime]$latestBriefingDate) -ge $anchor) {
        # Already covered this Mon/Thu cycle. Exit before creating any log
        # files -- this path runs on every unlock, many times a day.
        exit 0
    }
}

$runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runLog = Join-Path $outputDir "run-$runStamp.log"
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
. (Join-Path $PSScriptRoot 'ClaudeCommon.ps1')

function Write-RunLog {
    param([string]$Message)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" |
        Tee-Object -FilePath $runLog -Append
}

$mutex = New-Object System.Threading.Mutex($false, 'Global\SemiconductorDailyReport')
if (-not $mutex.WaitOne(0)) {
    Write-RunLog 'SKIP another Run-DailyReport.ps1 instance already holds the lock; exiting'
    exit 0
}
$stopwatch = [Diagnostics.Stopwatch]::StartNew()

try {
    Write-RunLog "START daily semiconductor report for $date (PID $PID)"
    if (Test-Path -LiteralPath $briefing) {
        Write-RunLog "Briefing already exists; skipping generation and resuming publish/send"
    } else {
        Push-Location $projectRoot
        try {
        $priorBriefingDate = Get-ChildItem -LiteralPath $outputDir -Filter '*-briefing.md' -ErrorAction SilentlyContinue |
            ForEach-Object { $_.BaseName -replace '-briefing$', '' } |
            Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' -and $_ -lt $date } |
            Sort-Object -Descending | Select-Object -First 1
        if ($priorBriefingDate) {
            $sinceDate = ([datetime]$priorBriefingDate).AddDays(1).ToString('yyyy-MM-dd')
            $newsWindowInstruction = "The previous successful briefing covered through $priorBriefingDate. Collect and cover news from $sinceDate through $date inclusive so no day is skipped, not just the last 24-48 hours. If that gap exceeds 5 days, summarize the interim period concisely in the cumulative insights section instead of writing a full per-day breakdown for every missed day."
        } else {
            $newsWindowInstruction = 'No prior briefing was found; cover news from the last 48 hours through today.'
        }

        # "Read every prior report" for cumulative insights doesn't scale --
        # it grows with total report count and was the likely cause of the
        # 2026-08-06 run still not finishing after 24+ minutes. Pre-digest
        # the last 30 days from the already-extracted structured data
        # (pipeline/, no LLM cost) instead, same pattern already used for
        # the weekly rollup.
        $cumulativeContext = ''
        $pipelineDir = Join-Path $projectRoot 'pipeline'
        if (Test-Path -LiteralPath (Join-Path $pipelineDir 'weekly_context.py')) {
            $since30 = ([datetime]$date).AddDays(-30).ToString('yyyy-MM-dd')
            Push-Location $pipelineDir
            try {
                $cumulativeContext = (& python weekly_context.py $since30 $date) -join "`n"
            } catch {
                $cumulativeContext = ''
            } finally {
                Pop-Location
            }
        }
        $cumulativeInstruction = if ($cumulativeContext.Trim()) {
            "For the 7-day and 30-day cumulative insights, use this pre-extracted structured data covering the last 30 days as your primary source instead of reopening every prior output/*-briefing.md file:`n`n$cumulativeContext`n`nOnly open specific prior briefing files if you need narrative context (an exact quote, fuller explanation) the structured data above doesn't capture."
        } else {
            'Read prior output reports for cumulative insights (no pre-extracted structured data was available).'
        }

        $prompt = "Follow AGENTS.md and create today's detailed Korean briefing for $date at output/$date-briefing.md. Verify current news on the web. $newsWindowInstruction Prioritize company IR/newsrooms, filings, regulators, official technical sources, established market-research firms, and Reuters/Bloomberg/FT/WSJ/Nikkei Asia/Yonhap-class reporting. Cross-check interview-worthy claims and label source tiers, estimates, and unconfirmed reports. Do not rely on blogs, communities, or unattributed aggregation. $cumulativeInstruction Place evidence-based 7-day and 30-day cumulative insights near the beginning. For beginners, explain every English acronym and product code on first use with its full name, plain Korean definition, and market significance. Add the required Korean glossary table at the end."
        $ok = Invoke-ClaudeTask -Prompt $prompt -ExpectedOutputPath $briefing -OutputDir $outputDir -LogPrefix 'claude'
        if (-not $ok) {
            throw "Claude failed after 3 attempts. See output/claude-*.err.log"
        }
        } finally {
            Pop-Location
        }
    }
    if (-not (Test-Path -LiteralPath $briefing)) { throw "Briefing was not created: $briefing" }
    Write-RunLog 'Publishing briefing to GitHub'
    & (Join-Path $PSScriptRoot 'Publish-GitHub.ps1') -BriefingPath $briefing
    Write-RunLog 'Sending KakaoTalk summary'
    & (Join-Path $PSScriptRoot 'Send-KakaoBriefing.ps1') -BriefingPath $briefing
    Write-RunLog "SUCCESS daily semiconductor report (elapsed $($stopwatch.Elapsed))"
} catch {
    $errorMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ERROR $($_.Exception.Message)"
    $errorMessage | Add-Content -LiteralPath $errorLog -Encoding UTF8
    Write-RunLog "$errorMessage (elapsed $($stopwatch.Elapsed))"
    throw
} finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
