@echo off
rem Parsigo - Windows installer wrapper.
rem The real work happens in install.ps1 (Persian messages, UTF-8), because
rem cmd.exe mangles non-ASCII text in .bat files depending on the code page.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 pause
