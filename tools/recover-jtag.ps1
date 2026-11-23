<#
.SYNOPSIS
    Unstick the ESP32-C3 debug module (Windows counterpart of recover-jtag.sh).

.DESCRIPTION
    Symptoms this fixes, as printed by OpenOCD:
        Timed out after Ns waiting for busy to go low (abstractcs=0x...)
        Examination failed
        Unsupported DTM version: -1

    Usually caused by a debug session that was cut off while the target was
    halted. A plain reset is NOT enough: "hard_reset" only restarts the CPU and
    leaves the debug module wedged. A watchdog reset restarts the whole digital
    core and clears it, without unplugging the cable.

    Nothing is hardcoded to one machine: the ESP-IDF python environment is
    found by importing export.ps1, exactly like tools/setup.ps1 does, because
    the directory name encodes both the ESP-IDF and the Python version
    (idf5.3_py3.14_env, idf5.5_py3.11_env, ...) and differs per installation.

.PARAMETER Port
    Serial port to use, for example COM7. Detected automatically if omitted.

.PARAMETER IdfPath
    ESP-IDF directory to use. Searched for if omitted.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\recover-jtag.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\recover-jtag.ps1 -Port COM7
#>

[CmdletBinding()]
param(
    [string]$Port = "",
    [string]$IdfPath = ""
)

$ErrorActionPreference = "Stop"
$Target = "esp32c3"

function Write-Info { param($m) Write-Host "    $m" }
function Die { param($m) Write-Host "[fail] $m" -ForegroundColor Red; exit 1 }

# --------------------------------------------------------------- ESP-IDF ---
$Candidates = @()
if ($IdfPath)      { $Candidates += $IdfPath }
if ($env:IDF_PATH) { $Candidates += $env:IDF_PATH }
$Candidates += @(
    "$env:USERPROFILE\esp\esp-idf",
    "C:\Espressif\frameworks\esp-idf-v5.3.5",
    "C:\esp\esp-idf"
)
foreach ($root in @("$env:USERPROFILE\esp", "C:\Espressif\frameworks")) {
    if (Test-Path $root) {
        $Candidates += (Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
                        ForEach-Object { $_.FullName; Join-Path $_.FullName "esp-idf" })
    }
}

$IdfDir = $null
foreach ($c in $Candidates) {
    if ($c -and (Test-Path (Join-Path $c "export.ps1"))) { $IdfDir = $c; break }
}
if (-not $IdfDir) { Die "ESP-IDF not found. Pass -IdfPath DIR." }

# Import export.ps1 in a child process so this shell keeps a clean environment.
$probe = @"
`$ErrorActionPreference = 'SilentlyContinue'
. '$IdfDir\export.ps1' | Out-Null
Write-Output "`$env:IDF_PYTHON_ENV_PATH\Scripts\python.exe"
"@
$IdfPython = (& powershell -NoProfile -ExecutionPolicy Bypass -Command $probe |
              Select-Object -Last 1)

if (-not $IdfPython -or -not (Test-Path $IdfPython)) {
    Die "ESP-IDF python not found. Run $IdfDir\install.ps1 $Target"
}
Write-Info "ESP-IDF python: $IdfPython"

# ------------------------------------------------------------ serial port --
if (-not $Port) {
    # The built-in USB-Serial-JTAG enumerates with VID 303A, PID 1001.
    $dev = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -match '\(COM\d+\)' -and
                          ($_.Name -match 'USB JTAG' -or $_.PNPDeviceID -match 'VID_303A') } |
           Select-Object -First 1
    if ($dev -and $dev.Name -match '\((COM\d+)\)') {
        $Port = $Matches[1]
    } else {
        $any = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '\(COM\d+\)' } | Select-Object -First 1
        if ($any -and $any.Name -match '\((COM\d+)\)') { $Port = $Matches[1] }
    }
}
if (-not $Port) { Die "no serial port found. Plug the board in, or pass -Port." }
Write-Info "serial port:    $Port"

# ------------------------------------------------------------- do the work -
$running = Get-Process openocd -ErrorAction SilentlyContinue
if ($running) {
    $running | Stop-Process -Force
    Write-Info "stopped a running OpenOCD"
} else {
    Write-Info "no OpenOCD was running"
}
Start-Sleep -Seconds 1

Write-Info "sending a watchdog reset ..."
& $IdfPython -m esptool --chip $Target -p $Port --after watchdog_reset flash_id
if ($LASTEXITCODE -ne 0) { Die "esptool failed with exit code $LASTEXITCODE" }

Write-Host "`n    Done. Start OpenOCD again; it should report ""Examination succeed""."
