@echo off
setlocal
echo Sign in to Codex CLI in the browser window.
codex login
if errorlevel 1 (
    echo Codex CLI login failed.
    pause
    exit /b 1
)
codex login status
echo Codex CLI login completed.
pause
exit /b 0
