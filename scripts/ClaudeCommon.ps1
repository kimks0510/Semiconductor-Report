Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-ClaudeTask {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string]$ExpectedOutputPath,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][string]$LogPrefix,
        [string]$AllowedTools = 'WebSearch,WebFetch,Read,Write,Edit,Glob,Grep',
        [int]$MaxAttempts = 3,
        # Default to Sonnet, not Opus. This automation shares its quota with
        # interactive chat sessions, and the 2026-09-17 runs (3 failed
        # attempts x up to 3 retries, on the default Opus model) burned most
        # of a day's quota before a single briefing succeeded.
        [string]$Model = 'sonnet'
    )
    $runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    # The briefing prompt fans out to background research agents. In -p mode
    # the CLI only waits 600s for them and then kills the run ("Background
    # tasks still running after 600s; terminating"), which failed the
    # 2026-09-17 attempt. Wait up to 30 minutes instead of forever so a stuck
    # agent still can't pin the run.
    $env:CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS = '1800000'

    # Keep the machine out of idle sleep while Claude is working. Modern
    # Standby suspended the 2026-09-13 and 2026-09-17 runs for hours. This
    # does not stop a closed lid or a manual sleep.
    if (-not ('ReportAwake' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class ReportAwake {
    [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);
}
'@
    }
    # PowerShell reads 0x80000001 as a negative Int32, so pass the flags in
    # decimal: ES_CONTINUOUS | ES_SYSTEM_REQUIRED.
    [void][ReportAwake]::SetThreadExecutionState([uint32]2147483649)

    try {
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $stdoutLog = Join-Path $OutputDir "$LogPrefix-$runStamp-attempt-$attempt.out.log"
        $stderrLog = Join-Path $OutputDir "$LogPrefix-$runStamp-attempt-$attempt.err.log"
        Write-Host "Claude attempt $attempt of $MaxAttempts ($LogPrefix)"

        $savedErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & claude -p $Prompt --model $Model --permission-mode bypassPermissions --allowedTools $AllowedTools 1>> $stdoutLog 2>> $stderrLog
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $savedErrorActionPreference
        }
        Write-Host "Claude attempt $attempt exit code: $exitCode"

        if ($exitCode -eq 0 -and (Test-Path -LiteralPath $ExpectedOutputPath)) { return $true }

        # An expired CLI login (2026-09-03, 2026-09-24) can't be fixed by
        # retrying -- it only burns two more 60s waits every hourly sweep.
        # Bail out so the caller's failure alert goes out immediately.
        if (Select-String -LiteralPath $stdoutLog -SimpleMatch 'Failed to authenticate' -Quiet) {
            Write-Host 'Claude CLI is not logged in; skipping remaining attempts.'
            return $false
        }
        if ($attempt -lt $MaxAttempts) { Start-Sleep -Seconds 60 }
    }
    return $false
    } finally {
        [void][ReportAwake]::SetThreadExecutionState([uint32]2147483648)
    }
}
