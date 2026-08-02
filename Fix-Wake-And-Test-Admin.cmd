@echo off
setlocal
set "SCRIPT=%~dp0scripts\Register-DynamicWakeTrial.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File %SCRIPT% -MinutesFromNow 15' -Wait"
if errorlevel 1 (
    echo Wake timer setup failed or UAC was cancelled.
    pause
    exit /b 1
)
echo Wake timer enabled and a new trial was scheduled.
type "%~dp0output\wake-trial-registration.txt"
pause
exit /b 0
