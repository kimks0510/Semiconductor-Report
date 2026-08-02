Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ReportPowerGuard {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
}
'@

$ES_CONTINUOUS = [uint32]0x80000000
$ES_SYSTEM_REQUIRED = [uint32]0x00000001
$result = [ReportPowerGuard]::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED)
if ($result -eq 0) { throw 'Failed to create system-required power request.' }

try {
    $end = (Get-Date).Date.AddHours(10).AddMinutes(30)
    if ($end -le (Get-Date)) { $end = (Get-Date).AddMinutes(160) }
    while ((Get-Date) -lt $end) { Start-Sleep -Seconds 30 }
}
finally {
    [void][ReportPowerGuard]::SetThreadExecutionState($ES_CONTINUOUS)
}
