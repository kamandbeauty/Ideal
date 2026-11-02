@echo off
rem Parsigo - wrap the portable build into a classic Setup.exe (Inno Setup 6).
rem Run windows\build-portable.bat first; this script only packages the result.
cd /d "%~dp0.."
chcp 65001 >nul
set PYTHONUTF8=1

set ISCC="%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist %ISCC% set ISCC="%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not exist %ISCC% (
  echo.
  echo   Inno Setup 6 was not found.
  echo   Install it from https://jrsoftware.org/isdl.php and run this again,
  echo   or simply ship the portable folder from dist\ as-is.
  pause
  exit /b 1
)

for /d %%D in (dist\Parsigo-*-windows-x64) do set APPDIR=%%D
if not defined APPDIR (
  echo   Build the portable folder first: windows\build-portable.bat
  pause
  exit /b 1
)

echo   Compiling installer from %APPDIR% ...
%ISCC% /DAppDir="%CD%\%APPDIR%" windows\installer.iss
if errorlevel 1 (
  echo   Inno Setup failed - see the compiler output above.
  pause
  exit /b 1
)
echo.
echo   Done: dist\Parsigo-Setup-*.exe
pause
