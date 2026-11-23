@echo off
REM ---------------------------------------------------------------------
REM setup.bat - Windows entry point for the ESP32-C3 assembly template.
REM
REM Thin wrapper: all the work happens in setup.ps1. Using a .bat file lets
REM users double-click it from Explorer without changing the PowerShell
REM execution policy of their machine.
REM
REM Usage:
REM     setup.bat                 full setup
REM     setup.bat -Check          report only, change nothing
REM     setup.bat -NoInstall      configure only, never install
REM     setup.bat -IdfPath C:\esp\esp-idf
REM     setup.bat -Port COM7
REM ---------------------------------------------------------------------
setlocal
set "SCRIPT_DIR=%~dp0"

where powershell >nul 2>&1
if errorlevel 1 (
    echo [fail] PowerShell not found. It ships with Windows 7 and later.
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup.ps1" %*
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo [fail] setup failed with exit code %RC%
)

REM Keep the window open when launched by double-click.
echo %CMDCMDLINE% | find /i "/c" >nul && pause
exit /b %RC%
