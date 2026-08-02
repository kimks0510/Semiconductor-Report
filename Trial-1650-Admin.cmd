@echo off
setlocal
set "SCRIPT=%~dp0scripts\Register-DynamicWakeTrial.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File %SCRIPT% -MinutesFromNow 4' -Wait"
if errorlevel 1 (
    echo Wake trial registration failed or UAC was cancelled.
    pause
    exit /b 1
)
echo Wake trial registered.
type "%~dp0output\wake-trial-registration.txt"
pause
exit /b 0
