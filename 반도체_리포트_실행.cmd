@echo off
chcp 65001 >nul
title 반도체 Daily Report 실행

echo.
echo [반도체 Daily Report] 작업을 시작합니다.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Run-DailyReport.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo 작업이 정상적으로 완료되었습니다.
) else (
    echo 작업이 실패했습니다. 종료 코드: %EXIT_CODE%
    echo output\errors.log 파일을 확인해 주세요.
)
echo.
pause
exit /b %EXIT_CODE%
