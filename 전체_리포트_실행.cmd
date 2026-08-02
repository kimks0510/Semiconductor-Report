@echo off
chcp 65001 >nul
title 반도체 및 대한항공 리포트 전체 실행

echo.
echo [1/2] 반도체 Daily Report 작업을 시작합니다.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Run-DailyReport.ps1"
set "SEMI_EXIT=%ERRORLEVEL%"

echo.
echo [2/2] 대한항공 Career Brief 작업을 시작합니다.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Korea_Airline_Scrap\scripts\Run-DailyScrap.ps1"
set "AIR_EXIT=%ERRORLEVEL%"

echo.
echo ================================
echo 실행 결과
echo ================================
echo 반도체 리포트 종료 코드: %SEMI_EXIT%
echo 대한항공 리포트 종료 코드: %AIR_EXIT%
echo.

if not "%SEMI_EXIT%"=="0" (
    echo 반도체 작업 오류: output\errors.log
)
if not "%AIR_EXIT%"=="0" (
    echo 대한항공 작업 오류: Korea_Airline_Scrap\output\errors.log
)
if "%SEMI_EXIT%"=="0" if "%AIR_EXIT%"=="0" (
    echo 두 작업이 모두 정상적으로 완료되었습니다.
)

echo.
pause

if not "%SEMI_EXIT%"=="0" exit /b %SEMI_EXIT%
exit /b %AIR_EXIT%
