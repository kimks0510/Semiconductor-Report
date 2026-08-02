Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$p = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated (Administrator) PowerShell window.'
}

& powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1
if ($LASTEXITCODE -ne 0) { throw "Failed to enable AC wake timers: $LASTEXITCODE" }
& powercfg.exe /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1
if ($LASTEXITCODE -ne 0) { throw "Failed to enable battery wake timers: $LASTEXITCODE" }
& powercfg.exe /SETACTIVE SCHEME_CURRENT
if ($LASTEXITCODE -ne 0) { throw "Failed to activate updated power scheme: $LASTEXITCODE" }

$guard = (Resolve-Path (Join-Path $PSScriptRoot 'Keep-SystemAwakeForReports.ps1')).Path
$wakeAt = (Get-Date).Date.AddHours(18).AddMinutes(57)
if ($wakeAt -le (Get-Date)) { $wakeAt = (Get-Date).AddMinutes(2) }

$taskName = 'System Wake Test 1857'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$guard`""
$trigger = New-ScheduledTaskTrigger -Once -At $wakeAt
$settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'One-time SYSTEM wake test ahead of the 19:00 Kakao delivery trial' -Force | Out-Null

Write-Output "Registered: $taskName"
Write-Output "Wake time: $($wakeAt.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Output 'AC/battery wake timers: enabled'
Write-Output 'Now go to sleep before this time, then wait for the 19:00 Kakao Delivery Test to fire.'
