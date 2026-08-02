Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Start-ScheduledTask -TaskName 'Semiconductor Daily Report'
Start-Sleep -Seconds 5
Start-ScheduledTask -TaskName 'Korean Air Daily Scrap'

Write-Output 'Today report tasks restarted: semiconductor first, Korean Air second.'
