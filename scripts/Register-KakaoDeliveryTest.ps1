Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$briefing = Join-Path $root ("output\{0}-briefing.md" -f (Get-Date -Format 'yyyy-MM-dd'))
if (-not (Test-Path -LiteralPath $briefing)) { throw "Today's briefing does not exist: $briefing" }

$runner = (Resolve-Path (Join-Path $PSScriptRoot 'Send-KakaoBriefing.ps1')).Path
$taskName = 'Kakao Delivery Test 1900'
$runAt = (Get-Date).Date.AddHours(19)
if ($runAt -le (Get-Date)) { throw '19:00 has already passed today; edit this script or run Send-KakaoBriefing.ps1 directly instead.' }

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$runner`" -BriefingPath `"$briefing`""
$trigger = New-ScheduledTaskTrigger -Once -At $runAt
$settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -RunOnlyIfNetworkAvailable -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 5) -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'One-time test: does a scheduled task successfully send todays KakaoTalk briefing' -Force | Out-Null

Write-Output "Registered: $taskName"
Write-Output "Run time: $($runAt.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Output "Target briefing: $briefing"
Write-Output 'This task self-deletes nothing -- remove it afterward with:'
Write-Output "  Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false"
