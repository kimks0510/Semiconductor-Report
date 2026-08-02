Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskName = 'Semiconductor Report One-Time 2026-07-25'
$runner = (Resolve-Path (Join-Path $PSScriptRoot 'Run-DailyReport.ps1')).Path
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$runner`""
$trigger = New-ScheduledTaskTrigger -Once -At ([datetime]'2026-07-25 08:00:00')
$settings = New-ScheduledTaskSettingsSet `
    -WakeToRun `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 10) `
    -ExecutionTimeLimit (New-TimeSpan -Hours 3) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description 'One-time semiconductor briefing for Saturday 2026-07-25 at 08:00 KST' `
    -Force | Out-Null

$task = Get-ScheduledTask -TaskName $taskName
$info = Get-ScheduledTaskInfo -TaskName $taskName
Write-Host "Registered: $($task.TaskName)"
Write-Host "Next run:  $($info.NextRunTime)"
Write-Host "WakeToRun: $($task.Settings.WakeToRun)"
