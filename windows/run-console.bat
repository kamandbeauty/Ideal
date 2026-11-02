@echo off
rem Parsigo in console mode - shows the log, useful when the window does not open.
cd /d "%~dp0.."
chcp 65001 >nul
set PYTHONUTF8=1
if exist ".venv\Scripts\python.exe" (
  ".venv\Scripts\python.exe" "desktop\main.py" --debug %*
) else (
  echo Parsigo is not installed yet. Run windows\install.bat first.
)
pause
