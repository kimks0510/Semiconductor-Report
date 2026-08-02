param([Parameter(Mandatory=$true)][string]$BriefingPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$resolvedProject = (Resolve-Path -LiteralPath $projectRoot).Path
$resolvedBriefing = (Resolve-Path -LiteralPath $BriefingPath).Path
if (-not $resolvedBriefing.StartsWith((Join-Path $resolvedProject 'output'), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Only briefing files inside the project output directory may be published.'
}

Push-Location $projectRoot
try {
    $relativePath = $resolvedBriefing.Substring($resolvedProject.Length + 1).Replace('\', '/')
    & (Join-Path $PSScriptRoot 'Build-MobileSite.ps1') -BriefingPath $resolvedBriefing
    & git add -- $relativePath docs
    & git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        & git commit -m "Publish $([IO.Path]::GetFileNameWithoutExtension($BriefingPath))"
        if ($LASTEXITCODE -ne 0) { throw "git commit exit code: $LASTEXITCODE" }
    }
    & git push origin HEAD:main
    if ($LASTEXITCODE -ne 0) { throw "git push exit code: $LASTEXITCODE" }
} finally {
    Pop-Location
}
