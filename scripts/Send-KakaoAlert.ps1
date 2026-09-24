param(
    [Parameter(Mandatory)][string]$Message,
    [string]$ThrottleKey = 'default',
    [switch]$IgnoreThrottle
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'KakaoCommon.ps1')

$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'output'
if (-not (Test-Path -LiteralPath $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }

# The scheduled task fires on every logon/unlock, so a failing pipeline would
# otherwise send an alert on every single unlock. One alert per key per day is
# enough to notice; the run log keeps the full history.
$stateFile = Join-Path $outputDir 'alert-state.json'
$today = Get-Date -Format 'yyyy-MM-dd'
$state = @{}
if (Test-Path -LiteralPath $stateFile) {
    try {
        $raw = Get-Content -LiteralPath $stateFile -Encoding UTF8 -Raw | ConvertFrom-Json
        foreach ($p in $raw.PSObject.Properties) { $state[$p.Name] = $p.Value }
    } catch { $state = @{} }
}
if (-not $IgnoreThrottle -and $state.ContainsKey($ThrottleKey) -and $state[$ThrottleKey] -eq $today) {
    Write-Host "Alert '$ThrottleKey' already sent today ($today); skipping."
    return
}

$text = "[반도체 브리핑 알림]`n$Message"
if ($text.Length -gt 200) { $text = $text.Substring(0, 197) + '...' }

$headers = @{ Authorization = "Bearer $(Get-KakaoAccessToken)" }
$template = @{
    object_type = 'text'
    text        = $text
    link        = @{ web_url = 'https://kimks0510.github.io/Semiconductor-Report/'; mobile_web_url = 'https://kimks0510.github.io/Semiconductor-Report/' }
} | ConvertTo-Json -Depth 5 -Compress

$response = Invoke-RestMethod -Method Post `
    -Uri 'https://kapi.kakao.com/v2/api/talk/memo/default/send' `
    -Headers $headers `
    -ContentType 'application/x-www-form-urlencoded;charset=utf-8' `
    -Body @{ template_object = $template }
if ($response.result_code -ne 0) { throw "Kakao alert send failed: $($response | ConvertTo-Json -Compress)" }

$state[$ThrottleKey] = $today
$state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $stateFile -Encoding UTF8
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ALERT [$ThrottleKey] $Message" |
    Add-Content -LiteralPath (Join-Path $outputDir 'kakao-send.log') -Encoding UTF8
Write-Host 'Alert sent to KakaoTalk My Chat.'
