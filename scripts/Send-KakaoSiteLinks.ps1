Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'KakaoCommon.ps1')

function ConvertFrom-CodePoints([int[]]$Points) {
    return -join ($Points | ForEach-Object { [char]$_ })
}

# Keep this Windows PowerShell 5.1 script ASCII-only to prevent Korean mojibake.
$semi = ConvertFrom-CodePoints @(0xBC18,0xB3C4,0xCCB4,0x20,0xB370,0xC77C,0xB9AC,0x20,0xB9AC,0xD3EC,0xD2B8)
$air = ConvertFrom-CodePoints @(0xB300,0xD55C,0xD56D,0xACF5,0x20,0xB370,0xC77C,0xB9AC,0x20,0xB9AC,0xD3EC,0xD2B8)
$semiUrl = 'https://kimks0510.github.io/Semiconductor-Report/'
$airUrl = 'https://kimks0510.github.io/Korea-Airline-Scrap/'
$message = "$semi`n$semiUrl`n`n$air`n$airUrl"

$template = @{
    object_type = 'text'
    text = $message
    link = @{ web_url = $semiUrl; mobile_web_url = $semiUrl }
    button_title = $semi
} | ConvertTo-Json -Depth 5 -Compress
$headers = @{ Authorization = "Bearer $(Get-KakaoAccessToken)" }
Invoke-RestMethod -Method Post -Uri 'https://kapi.kakao.com/v2/api/talk/memo/default/send' -Headers $headers -Body @{ template_object = $template } -ContentType 'application/x-www-form-urlencoded;charset=utf-8' | Out-Null
Write-Output 'Both site links sent to KakaoTalk My Chat.'
