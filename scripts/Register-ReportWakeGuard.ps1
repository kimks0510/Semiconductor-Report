Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$guard = (Resolve-Path (Join-Path $PSScriptRoot 'Keep-SystemAwakeForReports.ps1')).Path
$taskName = 'Daily Report Wake Guard'

# 2026-08-02 live test: a single WakeToRun moment only produced a
# sub-second Modern Standby flicker (exit+re-entry within the same
# second, 4 times over ~1.5 min) before the process could even launch
# (0x80070001 / 0xC0000142 -- process init failures, not script errors).
# Firing repeatedly over a window gives more chances to land on a
# moment the system actually stays up. MultipleInstances=IgnoreNew
# means once one attempt succeeds and starts the keep-awake loop,
# later repeats in the window are skipped rather than stacking.
#
# New-ScheduledTaskTrigger does not accept -RepetitionInterval/
# -RepetitionDuration together with -Weekly (AmbiguousParameterSet),
# and its Repetition property can't be populated with a client-side
# CIM instance either ("Invalid class"). schtasks.exe natively
# supports the Weekly+repetition combination, so create the task that
# way and layer the remaining settings on with Set-ScheduledTask
# afterward -- both steps verified against a throwaway task first.
$action = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$guard`""
& schtasks.exe /create /tn $taskName /tr $action /sc weekly /d MON,THU /st 07:45 /ri 2 /du 0000:14 /ru SYSTEM /rl HIGHEST /f
if ($LASTEXITCODE -ne 0) { throw "schtasks /create failed with exit code $LASTEXITCODE" }

$task = Get-ScheduledTask -TaskName $taskName
$task.Settings.WakeToRun = $true
$task.Settings.StartWhenAvailable = $true
$task.Settings.DisallowStartIfOnBatteries = $false
$task.Settings.StopIfGoingOnBatteries = $false
$task.Settings.MultipleInstances = 'IgnoreNew'
$task.Settings.ExecutionTimeLimit = 'PT3H'
Set-ScheduledTask -InputObject $task | Out-Null

$verify = Get-ScheduledTask -TaskName $taskName
Write-Output "Registered: $taskName"
Write-Output "WakeToRun=$($verify.Settings.WakeToRun) MultipleInstances=$($verify.Settings.MultipleInstances)"
Write-Output "Repetition: every $($verify.Triggers[0].Repetition.Interval) for $($verify.Triggers[0].Repetition.Duration), starting $($verify.Triggers[0].StartBoundary)"
Write-Output 'Daily Report Wake Guard registered: 07:45-07:59, every 2 min, first stable attempt wins.'
