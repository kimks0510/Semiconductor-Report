Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-KakaoTokenPath {
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $stateDir = Join-Path $projectRoot '.secrets'
    if (-not (Test-Path -LiteralPath $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
    return Join-Path $stateDir 'kakao-token.json'
}

function Get-KakaoSetting([string]$Name) {
    $value = [Environment]::GetEnvironmentVariable($Name, 'User')
    if ([string]::IsNullOrWhiteSpace($value)) { $value = [Environment]::GetEnvironmentVariable($Name, 'Process') }
    if ([string]::IsNullOrWhiteSpace($value)) { throw "Required environment variable is missing: $Name" }
    return $value
}

function Save-KakaoToken($Token) {
    $Token | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Get-KakaoTokenPath) -Encoding UTF8
}

function Get-KakaoAccessToken {
    $tokenPath = Get-KakaoTokenPath
    if (-not (Test-Path -LiteralPath $tokenPath)) { throw 'Kakao token is missing. Run Initialize-Kakao.ps1 first.' }
    $token = Get-Content -LiteralPath $tokenPath -Encoding UTF8 -Raw | ConvertFrom-Json
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($token.expires_at -gt ($now + 300)) { return $token.access_token }

    $body = @{
        grant_type = 'refresh_token'
        client_id = Get-KakaoSetting 'KAKAO_REST_API_KEY'
        refresh_token = $token.refresh_token
    }
    $secret = [Environment]::GetEnvironmentVariable('KAKAO_CLIENT_SECRET', 'User')
    if ([string]::IsNullOrWhiteSpace($secret)) { $secret = [Environment]::GetEnvironmentVariable('KAKAO_CLIENT_SECRET', 'Process') }
    if (-not [string]::IsNullOrWhiteSpace($secret)) { $body.client_secret = $secret }

    $fresh = Invoke-RestMethod -Method Post -Uri 'https://kauth.kakao.com/oauth/token' -ContentType 'application/x-www-form-urlencoded;charset=utf-8' -Body $body
    $token.access_token = $fresh.access_token
    $token.expires_at = $now + [int64]$fresh.expires_in
    if ($fresh.PSObject.Properties.Name -contains 'refresh_token') { $token.refresh_token = $fresh.refresh_token }
    Save-KakaoToken $token
    return $token.access_token
}
