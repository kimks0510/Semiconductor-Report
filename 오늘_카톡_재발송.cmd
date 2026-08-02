@echo off
setlocal
set "ROOT=%~dp0"
set "DATE=2026-07-25"
set "SEMI=%ROOT%output\%DATE%-briefing.md"
set "AIR=%ROOT%Korea_Airline_Scrap\output\%DATE%-korean-air.md"

echo Sending semiconductor report...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\Send-KakaoBriefing.ps1" -BriefingPath "%SEMI%"
if errorlevel 1 goto fail

echo Sending Korean Air report...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Korea_Airline_Scrap\scripts\Send-KakaoLink.ps1" -ReportDate "%DATE%" -BriefingPath "%AIR%"
if errorlevel 1 goto fail

echo Both reports were sent successfully.
pause
exit /b 0

:fail
echo Kakao delivery failed. Review the error above.
pause
exit /b 1
