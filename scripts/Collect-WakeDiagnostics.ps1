Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$p = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated (Administrator) PowerShell window.'
}

$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$outFile = Join-Path $outputDir "diagnostics-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').txt"

function Section($title) { "`n===== $title =====" }

$report = @()
$report += Section 'Scheduled Tasks'
foreach ($name in 'Daily Report Wake Guard','Semiconductor Daily Report','Korean Air Daily Scrap') {
    $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if (-not $task) { $report += "$name : NOT REGISTERED"; continue }
    $info = Get-ScheduledTaskInfo -TaskName $name
    $report += "--- $name ---"
    $report += "State: $($task.State)"
    $report += "Principal: $($task.Principal.UserId) LogonType=$($task.Principal.LogonType) RunLevel=$($task.Principal.RunLevel)"
    $report += "Triggers: $($task.Triggers | ForEach-Object {
        $startBoundary = if ($_.PSObject.Properties.Match('StartBoundary').Count -gt 0) { $_.StartBoundary } else { '' }
        $daysOfWeek = if ($_.PSObject.Properties.Match('DaysOfWeek').Count -gt 0) { $_.DaysOfWeek } else { '' }
        "$($_.CimClass.CimClassName) Start=$startBoundary DaysOfWeek=$daysOfWeek"
    } | Out-String)"
    $report += "Settings: WakeToRun=$($task.Settings.WakeToRun) StartWhenAvailable=$($task.Settings.StartWhenAvailable) RunOnlyIfNetworkAvailable=$($task.Settings.RunOnlyIfNetworkAvailable)"
    $report += "LastRunTime: $($info.LastRunTime) LastTaskResult: $($info.LastTaskResult) NextRunTime: $($info.NextRunTime)"
}

$report += Section 'powercfg /a (available sleep states)'
$report += (powercfg /a | Out-String)

$report += Section 'powercfg /waketimers (currently armed wake timers)'
$report += (powercfg /waketimers | Out-String)

$report += Section 'powercfg /lastwake (what woke the PC last)'
$report += (powercfg /lastwake | Out-String)

$report += Section 'powercfg /requests (active power requests right now)'
$report += (powercfg /requests | Out-String)

$report += Section 'RTCWAKE setting (AC/DC)'
$report += (powercfg /q SCHEME_CURRENT SUB_SLEEP RTCWAKE | Out-String)

$sleepStudyPath = Join-Path $outputDir 'sleepstudy.html'
powercfg /sleepstudy /output $sleepStudyPath | Out-Null
$report += Section 'sleepstudy report'
$report += "Saved to $sleepStudyPath (open in a browser; not embedded here)"

$report += Section 'TaskScheduler Operational log status'
$tsLog = Get-WinEvent -ListLog 'Microsoft-Windows-TaskScheduler/Operational' -ErrorAction SilentlyContinue
if ($tsLog) {
    $report += "Enabled: $($tsLog.IsEnabled)"
    if (-not $tsLog.IsEnabled) {
        $tsLog.IsEnabled = $true
        $tsLog.SaveChanges()
        $report += 'Enabled it now. Re-run this script after the next wake test to capture events.'
    } else {
        $events = Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 100 -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -match 'Semiconductor Daily Report|Daily Report Wake Guard|Korean Air Daily Scrap' }
        $report += ($events | Select-Object TimeCreated, Id, Message | Format-List | Out-String)
    }
} else {
    $report += 'Could not access the TaskScheduler operational log.'
}

$report += Section 'Kernel-Power sleep/wake events (last 20)'
$kp = Get-WinEvent -FilterHashtable @{ LogName='System'; ProviderName='Microsoft-Windows-Kernel-Power'; Id=42,506,507,1,724 } -MaxEvents 20 -ErrorAction SilentlyContinue
$report += ($kp | Select-Object TimeCreated, Id, Message | Format-List | Out-String)

$report | Out-File -LiteralPath $outFile -Encoding UTF8
Write-Host "Diagnostics written to $outFile"
Write-Host 'No secrets were read or written by this script.'
