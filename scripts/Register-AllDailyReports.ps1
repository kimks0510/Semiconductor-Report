Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent

# Explicitly enable scheduled-task wake timers for both AC and battery power.
# WakeToRun alone is not sufficient when the active power plan disables RTC wakes.
& powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1
if ($LASTEXITCODE -ne 0) { throw "Failed to enable AC wake timers: $LASTEXITCODE" }
& powercfg.exe /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1
if ($LASTEXITCODE -ne 0) { throw "Failed to enable battery wake timers: $LASTEXITCODE" }
& powercfg.exe /SETACTIVE SCHEME_CURRENT
if ($LASTEXITCODE -ne 0) { throw "Failed to activate updated power scheme: $LASTEXITCODE" }

& (Join-Path $PSScriptRoot 'Register-ReportWakeGuard.ps1')
& (Join-Path $PSScriptRoot 'Register-DailyTask.ps1')
& (Join-Path $root 'Korea_Airline_Scrap\scripts\Register-DailyTask.ps1')

Write-Output ''
Write-Output 'Daily report automation registered:'
Write-Output '- 07:50 Daily Report Wake Guard'
Write-Output '- 08:00 Semiconductor Daily Report'
Write-Output '- 08:20 Korean Air Daily Scrap'
Write-Output ''
Write-Output 'Sleep/Modern Standby can wake when firmware wake timers are enabled.'
Write-Output 'A fully shut down PC cannot run Windows Scheduled Tasks.'
