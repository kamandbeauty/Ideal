@echo off
rem Parsigo - start the app from a checkout or an installed copy.
rem Parsigo.exe (portable build) and the Start Menu shortcut do the same thing.
cd /d "%~dp0.."
if exist ".venv\Scripts\pythonw.exe" (
  start "" ".venv\Scripts\pythonw.exe" "desktop\main.py" %*
) else (
  echo Parsigo is not installed yet. Run windows\install.bat first.
  pause
)
