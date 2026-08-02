param([string]$RedirectUri = 'http://localhost:8766/oauth')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'KakaoCommon.ps1')

$restKey = Get-KakaoSetting 'KAKAO_REST_API_KEY'
$secret = [Environment]::GetEnvironmentVariable('KAKAO_CLIENT_SECRET', 'User')
if ([string]::IsNullOrWhiteSpace($secret)) { $secret = [Environment]::GetEnvironmentVariable('KAKAO_CLIENT_SECRET', 'Process') }

$listener = [System.Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 8766)
$listener.Server.SetSocketOption([Net.Sockets.SocketOptionLevel]::Socket, [Net.Sockets.SocketOptionName]::ReuseAddress, $true)
$listener.Start()
$encodedRedirect = [uri]::EscapeDataString($RedirectUri)
$authorizeUrl = "https://kauth.kakao.com/oauth/authorize?client_id=$restKey&redirect_uri=$encodedRedirect&response_type=code&scope=talk_message"
Write-Host 'Complete Kakao login and talk_message consent in the browser.'
Start-Process $authorizeUrl

try {
    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()
    $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
    $requestLine = $reader.ReadLine()
    while (-not [string]::IsNullOrEmpty($reader.ReadLine())) { }
    if ($requestLine -notmatch '^GET\s+(\S+)\s+HTTP/') { throw 'Invalid OAuth callback request.' }
    $callbackUri = [Uri]("http://localhost:8766" + $Matches[1])
    Add-Type -AssemblyName System.Web
    $query = [System.Web.HttpUtility]::ParseQueryString($callbackUri.Query)
    $code = $query['code']
    $errorCode = $query['error']
    $message = if ($code) { 'Authorization complete. You may close this window.' } else { "Authorization failed: $errorCode" }
    $bytes = [Text.Encoding]::UTF8.GetBytes("<html><meta charset='utf-8'><body><h2>$message</h2></body></html>")
    $header = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n")
    $stream.Write($header, 0, $header.Length)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Close()
    $client.Close()
    if (-not $code) { throw "Kakao authorization code was not received: $errorCode" }
} finally {
    $listener.Stop()
}

$body = @{ grant_type='authorization_code'; client_id=$restKey; redirect_uri=$RedirectUri; code=$code }
if (-not [string]::IsNullOrWhiteSpace($secret)) { $body.client_secret = $secret }
$token = Invoke-RestMethod -Method Post -Uri 'https://kauth.kakao.com/oauth/token' -ContentType 'application/x-www-form-urlencoded;charset=utf-8' -Body $body
$stored = [ordered]@{
    access_token = $token.access_token
    refresh_token = $token.refresh_token
    expires_at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + [int64]$token.expires_in
    scope = $token.scope
}
Save-KakaoToken $stored
Write-Host "Kakao authorization complete. Token saved to $(Get-KakaoTokenPath)."
