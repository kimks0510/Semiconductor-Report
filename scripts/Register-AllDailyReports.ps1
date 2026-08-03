Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent

# 2026-08-02/03: three separate live tests (single wake, 8x repeated wake,
# and the real Mon/Thu run) all confirm this hardware's Modern Standby does
# not deliver a stable wake from a Task Scheduler RTC timer -- it either
# produces no wake event at all for hours, or a sub-second flicker too brief
# for the process to finish launching. Chasing this further in software is
# not worth it. Decided approach instead: don't try to wake the machine.
# Rely on -StartWhenAvailable to catch the missed Mon/Thu trigger whenever
# the user next actually turns the machine on that day (a real boot/login,
# not a brief auto-wake, so the process has a stable session to run in).
# Run-DailyReport.ps1 already computes the news-gap window from whatever
# today's real date is when it actually runs, so a late catch-up still
# produces a correctly-dated, gap-free report.
& powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1
if ($LASTEXITCODE -ne 0) { throw "Failed to enable AC wake timers: $LASTEXITCODE" }
& powercfg.exe /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1
if ($LASTEXITCODE -ne 0) { throw "Failed to enable battery wake timers: $LASTEXITCODE" }
& powercfg.exe /SETACTIVE SCHEME_CURRENT
if ($LASTEXITCODE -ne 0) { throw "Failed to activate updated power scheme: $LASTEXITCODE" }

& (Join-Path $PSScriptRoot 'Register-DailyTask.ps1')

Write-Output ''
Write-Output 'Daily report automation registered:'
Write-Output '- Mon/Thu 08:00 Semiconductor Daily Report (runs at 08:00 if the PC is'
Write-Output '  already on; otherwise catches up the first time it is turned on that day)'
Write-Output ''
Write-Output 'Korean Air Daily Scrap is currently paused (Disable-ScheduledTask) and is'
Write-Output 'intentionally not re-registered here. Run'
Write-Output '  Korea_Airline_Scrap\scripts\Register-DailyTask.ps1'
Write-Output 'directly, then Enable-ScheduledTask, if it needs to resume.'
Write-Output ''
Write-Output 'Daily Report Wake Guard is retired -- see comment above for why.'
Write-Output 'A fully shut down PC still will not run anything until turned on.'
