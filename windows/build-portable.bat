@echo off
rem Parsigo - build the self-contained Windows folder (no Python needed to run it).
rem The build itself needs Python 3.10+ on this machine (it downloads the
rem Windows wheels; it never runs them).
cd /d "%~dp0.."
chcp 65001 >nul
set PYTHONUTF8=1

set PY=python
where py >nul 2>nul && set PY=py -3

echo.
echo   Building Parsigo for Windows...
echo   (first run downloads CPython + wheels, ~120 MB, then caches them)
echo.
%PY% windows\build_portable.py %*
if errorlevel 1 (
  echo.
  echo   Build failed. See the messages above.
  pause
  exit /b 1
)
echo.
pause
