@echo off
REM ---------------------------------------------------------------------
REM recover-jtag.bat - Windows entry point for unsticking the debug module.
REM
REM Thin wrapper around recover-jtag.ps1, so it can be double-clicked from
REM Explorer without changing the machine's PowerShell execution policy.
REM
REM Usage:
REM     recover-jtag.bat                 detect everything
REM     recover-jtag.bat -Port COM7
REM     recover-jtag.bat -IdfPath C:\esp\esp-idf
REM ---------------------------------------------------------------------
setlocal
set "SCRIPT_DIR=%~dp0"

where powershell >nul 2>&1
if errorlevel 1 (
    echo [fail] PowerShell not found. It ships with Windows 7 and later.
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%recover-jtag.ps1" %*
set "RC=%ERRORLEVEL%"

REM Keep the window open when launched by double-click.
echo %CMDCMDLINE% | find /i "/c" >nul && pause
exit /b %RC%
