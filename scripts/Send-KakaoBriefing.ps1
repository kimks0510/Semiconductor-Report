param(
    [Parameter(Mandatory=$false)][string]$BriefingPath,
    [switch]$ForceResend
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'KakaoCommon.ps1')

$projectRoot = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($BriefingPath)) {
    $BriefingPath = Join-Path $projectRoot ("output\{0}-briefing.md" -f (Get-Date -Format 'yyyy-MM-dd'))
}
if (-not (Test-Path -LiteralPath $BriefingPath)) { throw "Briefing file not found: $BriefingPath" }

function ConvertTo-HashtableDeep($InputObject) {
    if ($InputObject -is [System.Collections.IDictionary]) { return $InputObject }
    if ($InputObject -is [PSCustomObject]) {
        $ht = @{}
        foreach ($p in $InputObject.PSObject.Properties) { $ht[$p.Name] = ConvertTo-HashtableDeep $p.Value }
        return $ht
    }
    return $InputObject
}

$stateFile = Join-Path $projectRoot 'output\delivery-state.json'
$briefingHash = (Get-FileHash -LiteralPath $BriefingPath -Algorithm SHA256).Hash
$state = if (Test-Path -LiteralPath $stateFile) {
    ConvertTo-HashtableDeep (Get-Content -LiteralPath $stateFile -Encoding UTF8 -Raw | ConvertFrom-Json)
} else { @{} }
$reportKey = [IO.Path]::GetFileName($BriefingPath).Substring(0, 10)
if (-not $state.ContainsKey($reportKey) -or $state[$reportKey].hash -ne $briefingHash -or $ForceResend) {
    $state[$reportKey] = @{ hash = $briefingHash; parts = @{} }
}
function Save-DeliveryState {
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $stateFile -Encoding UTF8
}

$lines = Get-Content -LiteralPath $BriefingPath -Encoding UTF8
$summaryHeading = -1
for ($h = 0; $h -lt $lines.Count; $h++) {
    if ($lines[$h] -eq '## Kakao Summary') { $summaryHeading = $h; break }
}
$summary = @()
if ($summaryHeading -ge 0) {
    for ($i = $summaryHeading + 1; $i -lt $lines.Count -and $summary.Count -lt 3; $i++) {
        if ($lines[$i] -match '^\d+\.\s+(.+)$') { $summary += $Matches[1] }
    }
}
if ($summary.Count -eq 0) { $summary = @('The detailed daily briefing has been generated.') }

$date = [IO.Path]::GetFileName($BriefingPath).Substring(0, 10)
$reportUrl = "https://kimks0510.github.io/Semiconductor-Report/#$date"
if ($summary.Count -ne 3) { throw 'Kakao Summary must contain exactly three numbered sentences.' }
$messages = @()
for ($part = 0; $part -lt 3; $part++) {
    $message = "[$date Daily Report $($part + 1)/4]`n$($summary[$part])"
    if ($message.Length -gt 200) { throw "Kakao Summary item $($part + 1) exceeds the 200 character API limit." }
    $messages += $message
}
$linkMessage = "[$date Full Report 4/4]`n$reportUrl"
if ($linkMessage.Length -gt 200) { throw 'The GitHub report URL exceeds the 200 character API limit.' }
$messages += $linkMessage
$sentParts = $state[$reportKey].parts
$pending = @(for ($i = 0; $i -lt $messages.Count; $i++) { if (-not $sentParts.ContainsKey("$($i+1)")) { $i } })
if ($pending.Count -eq 0) {
    Write-Host "All 4 parts already sent for $reportKey (hash $briefingHash); nothing to do. Use -ForceResend to resend."
    return
}

$headers = @{ Authorization = "Bearer $(Get-KakaoAccessToken)" }
foreach ($i in $pending) {
    $partNumber = $i + 1
    $template = @{
        object_type = 'text'
        text = $messages[$i]
        link = @{ web_url = $reportUrl; mobile_web_url = $reportUrl }
        buttons = @(
            @{
                title = 'Open full report'
                link = @{ web_url = $reportUrl; mobile_web_url = $reportUrl }
            }
        )
    } | ConvertTo-Json -Depth 5 -Compress
    $response = Invoke-RestMethod -Method Post -Uri 'https://kapi.kakao.com/v2/api/talk/memo/default/send' -Headers $headers -ContentType 'application/x-www-form-urlencoded;charset=utf-8' -Body @{ template_object=$template }
    if ($response.result_code -ne 0) { throw "Kakao send failed on part $partNumber`: $($response | ConvertTo-Json -Compress)" }
    $sentParts["$partNumber"] = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Save-DeliveryState
}
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') SENT $BriefingPath" | Add-Content -LiteralPath (Join-Path $projectRoot 'output\kakao-send.log') -Encoding UTF8
Write-Host 'Briefing summary sent to KakaoTalk My Chat.'
