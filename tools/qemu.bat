@echo off
REM ---------------------------------------------------------------------
REM qemu.bat - Windows entry point for running the firmware on QEMU.
REM
REM Thin wrapper around qemu.ps1, so it can be double-clicked from Explorer
REM without changing the machine's PowerShell execution policy.
REM
REM Usage:
REM     qemu.bat                          run the example on the emulator
REM     qemu.bat -Gdb                     wait for a debugger on port 3333
REM     qemu.bat -Attach                  start gdb against a waiting QEMU
REM     qemu.bat -Project C:\work\robot
REM
REM No board is needed, and nothing is sent to one if it happens to be
REM plugged in. Port 3333 is shared with OpenOCD, so only one of the two can
REM be debugged at a time; -Gdb stops a running OpenOCD first.
REM ---------------------------------------------------------------------
setlocal
set "SCRIPT_DIR=%~dp0"

where powershell >nul 2>&1
if errorlevel 1 (
    echo [fail] PowerShell not found. It ships with Windows 7 and later.
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%qemu.ps1" %*
set "RC=%ERRORLEVEL%"

REM Keep the window open when launched by double-click.
echo %CMDCMDLINE% | find /i "/c" >nul && pause
exit /b %RC%
