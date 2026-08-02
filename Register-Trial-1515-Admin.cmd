@echo off
setlocal
set "TRIAL_SCRIPT=%~dp0scripts\Register-ReportTrial-1515.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File %TRIAL_SCRIPT%' -Wait"
if errorlevel 1 (
    echo Trial registration failed or UAC was cancelled.
    pause
    exit /b 1
)
echo Trial registration completed. You can put the PC to sleep.
pause
exit /b 0
