Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$date = Get-Date -Format 'yyyy-MM-dd'
$trialLog = Join-Path $root "output\trial-$((Get-Date).ToString('yyyyMMdd-HHmmss')).log"

function Write-TrialLog {
    param([string]$Message)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" |
        Tee-Object -FilePath $trialLog -Append
}

Write-TrialLog 'START sleep/wake delivery trial'

Write-TrialLog 'Starting semiconductor report delivery'
$semiOk = $false
try {
    & (Join-Path $PSScriptRoot 'Run-DailyReport.ps1')
    $semiOk = $true
    Write-TrialLog 'Semiconductor delivery completed'
} catch {
    Write-TrialLog "Semiconductor delivery failed: $($_.Exception.Message)"
}

Write-TrialLog 'Starting Korean Air report delivery'
$airOk = $false
try {
    & (Join-Path $root 'Korea_Airline_Scrap\scripts\Run-DailyScrap.ps1')
    $airOk = $true
    Write-TrialLog 'Korean Air delivery completed'
} catch {
    Write-TrialLog "Korean Air delivery failed: $($_.Exception.Message)"
}

if ($semiOk -and $airOk) {
    Write-TrialLog 'SUCCESS sleep/wake delivery trial'
    exit 0
}

Write-TrialLog 'ERROR one or both trial deliveries failed'
exit 1
