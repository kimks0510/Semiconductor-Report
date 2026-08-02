@echo off
setlocal
fltmc >nul 2>&1
if errorlevel 1 goto elevate
goto register

:elevate
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c','\"%~f0\"' -Verb RunAs"
exit /b

:register
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Register-TomorrowReport.ps1"
if errorlevel 1 goto failed
echo.
echo Registration completed successfully.
echo Keep this window open and confirm the Next run time is 2026-07-25 08:00.
goto done

:failed
echo.
echo Registration failed. Please send a screenshot of this window.

:done
echo.
pause
endlocal
