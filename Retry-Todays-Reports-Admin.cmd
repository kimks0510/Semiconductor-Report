@echo off
setlocal
set "SCRIPT=%~dp0scripts\Retry-TodaysScheduledReports.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File %SCRIPT%' -Wait"
if errorlevel 1 (
    echo Retry failed or UAC was cancelled.
    pause
    exit /b 1
)
echo Today report retry was started.
pause
exit /b 0
