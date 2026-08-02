Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
$errorLog = Join-Path $outputDir 'errors.log'
$date = Get-Date -Format 'yyyy-MM-dd'
$briefing = Join-Path $outputDir "$date-briefing.md"
$runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runLog = Join-Path $outputDir "run-$runStamp.log"
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

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
        $prompt = "Follow AGENTS.md and create today's detailed Korean briefing for $date at output/$date-briefing.md. Verify current news on the web. $newsWindowInstruction Prioritize company IR/newsrooms, filings, regulators, official technical sources, established market-research firms, and Reuters/Bloomberg/FT/WSJ/Nikkei Asia/Yonhap-class reporting. Cross-check interview-worthy claims and label source tiers, estimates, and unconfirmed reports. Do not rely on blogs, communities, or unattributed aggregation. Read prior output reports and place evidence-based 7-day and 30-day cumulative insights near the beginning. For beginners, explain every English acronym and product code on first use with its full name, plain Korean definition, and market significance. Add the required Korean glossary table at the end."
        $codexSucceeded = $false
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            $stdoutLog = Join-Path $outputDir "codex-$runStamp-attempt-$attempt.out.log"
            $stderrLog = Join-Path $outputDir "codex-$runStamp-attempt-$attempt.err.log"
            Write-RunLog "Codex attempt $attempt of 3"

            # Windows PowerShell can promote a native program's normal stderr
            # banner to a terminating ErrorRecord. Keep strict handling for the
            # script, but temporarily make native stderr non-terminating and use
            # the program's actual exit code as the success criterion.
            $savedErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                & codex --search --sandbox workspace-write --ask-for-approval never exec $prompt 1>> $stdoutLog 2>> $stderrLog
                $codexExitCode = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $savedErrorActionPreference
            }
            Write-RunLog "Codex attempt $attempt exit code: $codexExitCode"

            if ($codexExitCode -eq 0 -and (Test-Path -LiteralPath $briefing)) {
                $codexSucceeded = $true
                break
            }

            if ($attempt -lt 3) {
                Write-RunLog 'Retrying in 60 seconds'
                Start-Sleep -Seconds 60
            }
        }
        if (-not $codexSucceeded) {
            throw "Codex failed after 3 attempts. See codex-$runStamp-attempt-*.err.log"
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
