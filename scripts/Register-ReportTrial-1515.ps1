Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskName = 'Daily Reports Sleep Trial 2026-07-25 1515'
$runner = (Resolve-Path (Join-Path $PSScriptRoot 'Run-ReportTrial.ps1')).Path
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$runner`""
$trigger = New-ScheduledTaskTrigger -Once -At ([datetime]'2026-07-25 15:15:00')
$settings = New-ScheduledTaskSettingsSet `
    -WakeToRun `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -RestartCount 2 `
    -RestartInterval (New-TimeSpan -Minutes 5) `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description 'One-time sleep wake and sequential Kakao delivery trial' `
    -Force | Out-Null

Write-Output "Registered: $taskName"
Write-Output 'Run time: 2026-07-25 15:15 KST'
Write-Output 'WakeToRun: True'
