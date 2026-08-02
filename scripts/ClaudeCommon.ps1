Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-ClaudeTask {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string]$ExpectedOutputPath,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][string]$LogPrefix,
        [string]$AllowedTools = 'WebSearch,WebFetch,Read,Write,Edit,Glob,Grep',
        [int]$MaxAttempts = 3
    )
    $runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $stdoutLog = Join-Path $OutputDir "$LogPrefix-$runStamp-attempt-$attempt.out.log"
        $stderrLog = Join-Path $OutputDir "$LogPrefix-$runStamp-attempt-$attempt.err.log"
        Write-Host "Claude attempt $attempt of $MaxAttempts ($LogPrefix)"

        $savedErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & claude -p $Prompt --permission-mode bypassPermissions --allowedTools $AllowedTools 1>> $stdoutLog 2>> $stderrLog
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $savedErrorActionPreference
        }
        Write-Host "Claude attempt $attempt exit code: $exitCode"

        if ($exitCode -eq 0 -and (Test-Path -LiteralPath $ExpectedOutputPath)) { return $true }
        if ($attempt -lt $MaxAttempts) { Start-Sleep -Seconds 60 }
    }
    return $false
}
