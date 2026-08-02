Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-CodexTask {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string]$ExpectedOutputPath,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][string]$LogPrefix,
        [int]$MaxAttempts = 3
    )
    $runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $stdoutLog = Join-Path $OutputDir "$LogPrefix-$runStamp-attempt-$attempt.out.log"
        $stderrLog = Join-Path $OutputDir "$LogPrefix-$runStamp-attempt-$attempt.err.log"
        Write-Host "Codex attempt $attempt of $MaxAttempts ($LogPrefix)"

        # Windows PowerShell can promote a native program's normal stderr
        # banner to a terminating ErrorRecord; use the exit code as ground truth.
        $savedErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & codex --search --sandbox workspace-write --ask-for-approval never exec $Prompt 1>> $stdoutLog 2>> $stderrLog
            $codexExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $savedErrorActionPreference
        }
        Write-Host "Codex attempt $attempt exit code: $codexExitCode"

        if ($codexExitCode -eq 0 -and (Test-Path -LiteralPath $ExpectedOutputPath)) { return $true }
        if ($attempt -lt $MaxAttempts) { Start-Sleep -Seconds 60 }
    }
    return $false
}
