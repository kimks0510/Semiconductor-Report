param([string]$TaskName = 'Semiconductor Daily Report')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Launch through wscript, not powershell.exe directly. The task fires hourly
# and on every unlock, and running powershell.exe flashed a console window and
# stole focus every single time -- dozens of times a day, almost always just to
# hit the cycle gate and exit. The .vbs shim runs the same script with window
# style 0 so those checks are silent, and still waits for it so the task's
# ExecutionTimeLimit and MultipleInstances settings keep applying.
$launcher = Join-Path $PSScriptRoot 'Run-DailyReport-Hidden.vbs'
$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$launcher`""

# No time trigger. Four separate live tests (2026-07-25, 08-02, 08-06, 08-13)
# all failed the same way: a Mon/Thu 08:00 trigger fires while the machine is
# in Modern Standby, where the process either can't finish launching or makes
# no real progress and gets killed at the execution-time limit. Waking the
# machine reliably is not achievable on this hardware.
#
# Instead, fire whenever the user is genuinely at the machine -- at logon and
# at every workstation unlock. Run-DailyReport.ps1's cycle gate decides
# whether that particular wake-up should actually do anything, so unlocks
# outside a due cycle cost ~nothing (it exits before writing any files).
# This is what produces the requested behaviour: it runs the first time the
# PC is really used on Mon/Thu, and if the PC isn't used that day it simply
# defers to the next day the user turns it on.
$me = "$env:COMPUTERNAME\$env:USERNAME"

$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $me
$logonTrigger.Delay = 'PT3M'

# -AtLogOn without -User, and the unlock trigger without UserId, both mean
# "any user" and require elevation to register; scoping to the current user
# keeps this runnable without an admin prompt.
$unlockClass = Get-CimClass -ClassName MSFT_TaskSessionStateChangeTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
$unlockTrigger = New-CimInstance -CimClass $unlockClass -ClientOnly
$unlockTrigger.StateChange = 8   # TASK_SESSION_UNLOCK
$unlockTrigger.UserId = $me
$unlockTrigger.Enabled = $true
$unlockTrigger.Delay = 'PT3M'

# Logon and unlock alone leave a real gap: if the machine is simply left
# logged in and unlocked across midnight -- which is exactly what happened on
# 2026-09-24 -- neither trigger ever fires again, so a due Thursday cycle sat
# there untouched. An hourly sweep closes that. It is free: the cycle gate
# exits immediately when nothing is due, and the window is hidden.
$hourlyTrigger = New-ScheduledTaskTrigger -Daily -At '00:05'
$hourlyTrigger.Repetition = (New-CimInstance -CimClass (Get-CimClass -ClassName MSFT_TaskRepetitionPattern -Namespace Root/Microsoft/Windows/TaskScheduler) -ClientOnly)
$hourlyTrigger.Repetition.Interval = 'PT1H'
$hourlyTrigger.Repetition.Duration = 'P1D'

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 3) `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 60) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($logonTrigger, $unlockTrigger, $hourlyTrigger) -Settings $settings -Principal $principal -Description 'Mon/Thu semiconductor briefing; hidden, runs on logon/unlock/hourly, defers to the next day the PC is used' -Force | Out-Null

$verify = Get-ScheduledTask -TaskName $TaskName
Write-Host "Scheduled task registered: $TaskName"
Write-Host "Launcher: $($verify.Actions[0].Execute) (hidden window)"
Write-Host "Triggers: $($verify.Triggers.Count) (logon + unlock + hourly sweep)"
Write-Host 'Runs on the first Mon/Thu the PC is used; silent on every other check.'
