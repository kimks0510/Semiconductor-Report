Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$guard = (Resolve-Path (Join-Path $PSScriptRoot 'Keep-SystemAwakeForReports.ps1')).Path
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$guard`""
# 2026-08-02 live test: a single WakeToRun moment only produced a
# sub-second Modern Standby flicker (exit+re-entry within the same
# second, 4 times over ~1.5 min) before the process could even launch
# (0x80070001 / 0xC0000142 -- process init failures, not script errors).
# Firing repeatedly over a window gives more chances to land on a
# moment the system actually stays up. MultipleInstances=IgnoreNew
# means once one attempt succeeds and starts the keep-awake loop,
# later repeats in the window are skipped rather than stacking.
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Thursday -At '07:45' `
    -RepetitionInterval (New-TimeSpan -Minutes 2) -RepetitionDuration (New-TimeSpan -Minutes 14)
$settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 3) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'Daily Report Wake Guard' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Wake repeatedly 07:45-07:59 and keep the system active through daily report generation.' -Force | Out-Null
Write-Output 'Daily Report Wake Guard registered: 07:45-07:59, every 2 min, first stable attempt wins.'
