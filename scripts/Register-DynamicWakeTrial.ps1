param([int]$MinutesFromNow = 15)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($MinutesFromNow -lt 2) { throw 'MinutesFromNow must be at least 2.' }

$root = Split-Path $PSScriptRoot -Parent
$wakeAt = (Get-Date).AddMinutes($MinutesFromNow)
$runAt = $wakeAt.AddMinutes(1)
$stamp = $wakeAt.ToString('yyyyMMdd-HHmmss')
$wakeTaskName = "Report Wake Trial Guard $stamp"
$runTaskName = "Report Wake Trial Delivery $stamp"

& powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1
if ($LASTEXITCODE -ne 0) { throw "Failed to enable AC wake timers: $LASTEXITCODE" }
& powercfg.exe /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1
if ($LASTEXITCODE -ne 0) { throw "Failed to enable battery wake timers: $LASTEXITCODE" }
& powercfg.exe /SETACTIVE SCHEME_CURRENT
if ($LASTEXITCODE -ne 0) { throw "Failed to activate updated power scheme: $LASTEXITCODE" }

$guard = (Resolve-Path (Join-Path $PSScriptRoot 'Keep-SystemAwakeForReports.ps1')).Path
$guardAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$guard`""
$wakeTrigger = New-ScheduledTaskTrigger -Once -At $wakeAt
$wakeSettings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)
$systemPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $wakeTaskName -Action $guardAction -Trigger $wakeTrigger -Settings $wakeSettings -Principal $systemPrincipal -Description 'One-time Modern Standby wake validation' -Force | Out-Null

$runner = (Resolve-Path (Join-Path $PSScriptRoot 'Run-ReportTrial.ps1')).Path
$runAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$runner`""
$runTrigger = New-ScheduledTaskTrigger -Once -At $runAt
$runSettings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -RunOnlyIfNetworkAvailable -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 5) -ExecutionTimeLimit (New-TimeSpan -Hours 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$userPrincipal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $runTaskName -Action $runAction -Trigger $runTrigger -Settings $runSettings -Principal $userPrincipal -Description 'One-time sequential report delivery after wake validation' -Force | Out-Null

$info = @(
    "Registered wake trial at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "SYSTEM wake: $($wakeAt.ToString('yyyy-MM-dd HH:mm:ss'))",
    "Report delivery: $($runAt.ToString('yyyy-MM-dd HH:mm:ss'))",
    'AC wake timers: enabled',
    'Battery wake timers: enabled'
)
$info | Set-Content -LiteralPath (Join-Path $root 'output\wake-trial-registration.txt') -Encoding UTF8
$info | ForEach-Object { Write-Output $_ }
