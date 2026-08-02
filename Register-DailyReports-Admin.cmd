@echo off
setlocal
set "REGISTER_SCRIPT=%~dp0scripts\Register-AllDailyReports.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File %REGISTER_SCRIPT%' -Wait"
if errorlevel 1 (
    echo Registration failed or UAC was cancelled.
    pause
    exit /b 1
)
echo Registration completed.
pause
exit /b 0
