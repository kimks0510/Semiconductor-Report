@echo off
setlocal
set "REGISTER_SCRIPT=%~dp0scripts\Register-AllDailyReports.ps1"

echo Step 1 of 2: Sign in to Codex CLI.
codex login
if errorlevel 1 (
    echo Codex CLI login failed. Tomorrow automation was not registered.
    pause
    exit /b 1
)

codex login status
if errorlevel 1 (
    echo Codex CLI is still not logged in.
    pause
    exit /b 1
)

echo Step 2 of 2: Register wake timers and daily report tasks.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File %REGISTER_SCRIPT%' -Wait"
if errorlevel 1 (
    echo Task registration failed or UAC was cancelled.
    pause
    exit /b 1
)

echo Tomorrow automation is ready.
echo 07:50 Wake Guard
echo 08:00 Semiconductor
echo 08:20 Korean Air after semiconductor success
pause
exit /b 0
