<#
.SYNOPSIS
    Run the firmware on Espressif's QEMU instead of a board (Windows
    counterpart of qemu.sh).

.DESCRIPTION
    Useful when no ESP32-C3 is plugged in, when JTAG has wedged, or in CI. The
    CPU, the memory map and the registers are emulated faithfully enough to
    single-step assembly and read CSRs.

    WHAT QEMU DOES NOT EMULATE

    GPIO has no electrical side: asm_gpio_set and asm_gpio_clear write their
    registers and asm_gpio_read_all reads them back, but no LED lights up and
    the BOOT button can never be pressed. The performance counters advance with
    emulated instructions, not with real pipeline behaviour, so cycle counts
    are plausible but not the chip's. Flash timing is not modelled at all.

    THREE THINGS WORTH KNOWING

    The emulator is an optional ESP-IDF tool, so export.ps1 does not put it on
    PATH and "idf.py qemu" then claims it is not installed. This script adds
    the directory itself, reading the version from ESP-IDF's own tools.json.

    The build goes into build-qemu\ with its own sdkconfig, because the console
    has to move off USB-Serial-JTAG - QEMU does not emulate that peripheral,
    and a board build boots to complete silence. Keeping it separate also
    means no full rebuild when alternating with real hardware.

    The gdb stub listens on port 3333, the same port OpenOCD uses. -Gdb stops
    a running OpenOCD first; conversely the "openocd" task in VS Code stops a
    running QEMU. Only one of the two can be debugged at a time.

.PARAMETER Gdb
    Hold the CPU at the reset vector and wait for a debugger on port 3333.

.PARAMETER Attach
    Start gdb against a QEMU already waiting because of -Gdb.

.PARAMETER Project
    Project directory. Defaults to examples\hello_asm in this repository.

.PARAMETER NoBuild
    Reuse whatever is already in build-qemu\.

.PARAMETER NoMonitor
    Let QEMU write to the console directly, without idf_monitor.

.PARAMETER IdfPath
    ESP-IDF directory to use. Searched for if omitted.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\qemu.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\qemu.ps1 -Gdb
#>

[CmdletBinding()]
param(
    [switch]$Gdb,
    [switch]$Attach,
    [string]$Project = "",
    [switch]$NoBuild,
    [switch]$NoMonitor,
    [string]$IdfPath = ""
)

$ErrorActionPreference = "Stop"
$Target   = "esp32c3"
$GdbPort  = 3333          # not configurable; see the note below
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Write-Info { param($m) Write-Host "    $m" }
function Write-Ok   { param($m) Write-Host "  [ ok ] $m" -ForegroundColor Green }
function Die        { param($m) Write-Host "[fail] $m" -ForegroundColor Red; exit 1 }

if (-not $Project) { $Project = Join-Path $RepoRoot "examples\hello_asm" }
if (-not (Test-Path $Project)) { Die "no such project: $Project" }
$Project     = (Resolve-Path $Project).Path
$ProjectName = Split-Path -Leaf $Project

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
Write-Info "ESP-IDF: $IdfDir"

# Imported into THIS session, unlike recover-jtag.ps1 which probes in a child
# process: QEMU's output has to reach this console as it is produced.
. (Join-Path $IdfDir "export.ps1") | Out-Null
if (-not $env:IDF_PATH) { Die "export.ps1 did not set IDF_PATH" }

# ------------------------------------------------------------- the emulator -
# idf_tools.py lists qemu-riscv32 as optional, so export.ps1 exports the
# toolchain and OpenOCD but not this. Derive the directory from ESP-IDF's
# tools.json rather than from whatever happens to be on disk, so a leftover
# install from an older ESP-IDF cannot be picked up by mistake.
if (-not (Get-Command qemu-system-riscv32 -ErrorAction SilentlyContinue)) {
    $toolsRoot = if ($env:IDF_TOOLS_PATH) { $env:IDF_TOOLS_PATH }
                 else { Join-Path $env:USERPROFILE ".espressif" }
    $specPath  = Join-Path $env:IDF_PATH "tools\tools.json"
    if (Test-Path $specPath) {
        $spec = Get-Content $specPath -Raw | ConvertFrom-Json
        $tool = $spec.tools | Where-Object { $_.name -eq "qemu-riscv32" } |
                Select-Object -First 1
        if ($tool) {
            $version = ($tool.versions |
                        Where-Object { $_.status -eq "recommended" } |
                        Select-Object -First 1).name
            foreach ($parts in $tool.export_paths) {
                $p = Join-Path $toolsRoot (Join-Path "tools" (Join-Path $tool.name (Join-Path $version ($parts -join "\"))))
                if (Test-Path $p) { $env:PATH = "$p;$env:PATH" }
            }
        }
    }
}

if (-not (Get-Command qemu-system-riscv32 -ErrorAction SilentlyContinue)) {
    Write-Host "[fail] Espressif QEMU for RISC-V is not installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Install it with:"
    Write-Host ""
    Write-Host "      python `"$env:IDF_PATH\tools\idf_tools.py`" install qemu-riscv32"
    Write-Host ""
    Write-Host "  then run this script again."
    exit 1
}

# The archive unpacks fine but can still fail to start if a bundled DLL is
# missing, and the message Windows gives names the DLL rather than the fix.
# Surface it here instead of inside the build.
& qemu-system-riscv32 --version 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[fail] QEMU is installed but will not start:" -ForegroundColor Red
    & qemu-system-riscv32 --version 2>&1 | ForEach-Object { Write-Host "      $_" }
    Write-Host ""
    Write-Host "  Reinstall the tool, which carries the DLLs it needs:"
    Write-Host ""
    Write-Host "      python `"$env:IDF_PATH\tools\idf_tools.py`" install qemu-riscv32"
    exit 1
}
Write-Ok "emulator found"

# ------------------------------------------------------------ configuration -
Set-Location $Project

$BuildDir = Join-Path $Project "build-qemu"
$Elf      = Join-Path $BuildDir "$ProjectName.elf"

# Projects created before this script existed have no sdkconfig.qemu; write
# the one setting that matters into the build directory instead of refusing.
$QemuSdkconfig = Join-Path $Project "sdkconfig.qemu"
if (-not (Test-Path $QemuSdkconfig)) {
    New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
    $QemuSdkconfig = Join-Path $BuildDir "sdkconfig.qemu"
    Set-Content -Path $QemuSdkconfig -Encoding ascii -Value @(
        "CONFIG_ESP_CONSOLE_UART_DEFAULT=y",
        "CONFIG_ESP_CONSOLE_SECONDARY_NONE=y"
    )
}

# SDKCONFIG is redirected as well: an existing project sdkconfig wins over
# SDKCONFIG_DEFAULTS, so without this the overlay is silently ignored and the
# build keeps the board's USB-Serial-JTAG console. ";" is ESP-IDF's separator
# for SDKCONFIG_DEFAULTS on every platform, Windows included.
$IdfArgs = @(
    "-B", $BuildDir,
    "-D", "SDKCONFIG=$BuildDir\sdkconfig",
    "-D", "SDKCONFIG_DEFAULTS=sdkconfig.defaults;$QemuSdkconfig"
)

# ------------------------------------------------- -Attach: the gdb half ----
if ($Attach) {
    if (-not (Test-Path $Elf)) { Die "nothing built yet: $Elf" }
    Write-Ok "attaching to localhost:$GdbPort"
    # QEMU's gdb stub is not OpenOCD: "monitor reset halt" and the flash
    # breakpoint commands do not exist there. Connecting is enough, because
    # -Gdb already holds the CPU at the reset vector.
    & riscv32-esp-elf-gdb $Elf `
        -ex "set remotetimeout 20" `
        -ex "set print pretty on" `
        -ex "target remote localhost:$GdbPort" `
        -ex "break sum_loop"
    exit $LASTEXITCODE
}

# ------------------------------------------------------------------- build --
if (-not $NoBuild) {
    Write-Info "building $ProjectName"
    & idf.py @IdfArgs build | Out-Null
    if ($LASTEXITCODE -ne 0) { Die "build failed with exit code $LASTEXITCODE" }
    Write-Ok "built"
} elseif (-not (Test-Path $Elf)) {
    Die "nothing built yet: $Elf (drop -NoBuild)"
}

# --------------------------------------------------------------------- run --
# On Windows the process name is not truncated the way /proc/PID/comm is on
# Linux, so matching it directly is reliable here.
function Stop-StaleQemu {
    $stale = Get-Process qemu-system-riscv32 -ErrorAction SilentlyContinue
    if ($stale) {
        $stale | Stop-Process -Force
        Write-Info "stopped a running QEMU"
        Start-Sleep -Milliseconds 300
    }
}

if ($Gdb) {
    Stop-StaleQemu

    # QEMU's gdb stub and OpenOCD both want 3333, and OpenOCD is the more
    # likely leftover: it keeps running after a debug session is stopped.
    $oocd = Get-Process openocd -ErrorAction SilentlyContinue
    if ($oocd) { $oocd | Stop-Process -Force; Write-Info "stopped a running OpenOCD" }

    Write-Host ""
    Write-Host "QEMU, waiting for a debugger" -ForegroundColor White
    Write-Info "elf:  $Elf"
    Write-Info "gdb:  localhost:$GdbPort"
    Write-Host ""

    # The ready line is what the VS Code task's problem matcher waits for.
    # QEMU prints nothing when it stops at the reset vector, so without it the
    # debug session would start before the port is open. Printed by a job that
    # polls the port, not before launching QEMU.
    #
    # The port is not configurable: "idf.py qemu --gdb" hardcodes
    # "-gdb tcp::3333", and QEMU honours the first -gdb on its command line, so
    # anything passed through --qemu-extra-args is ignored without a word.
    # A -NoNewWindow child inherits this console, so what it writes lands on
    # the task's terminal where the matcher is watching. A background job would
    # not: its output has to be collected with Receive-Job, by which time the
    # debugger has already given up.
    $poll = @"
for (`$i = 0; `$i -lt 100; `$i++) {
    try {
        `$c = New-Object System.Net.Sockets.TcpClient
        `$c.Connect('127.0.0.1', $GdbPort)
        `$c.Close()
        Write-Host 'QEMU_READY: gdb server listening on localhost:$GdbPort'
        exit 0
    } catch {
        Start-Sleep -Milliseconds 200
    }
}
Write-Host 'QEMU_FAILED: port $GdbPort never opened'
"@
    Start-Process -NoNewWindow -FilePath "powershell" `
        -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $poll | Out-Null

    & idf.py @IdfArgs qemu --gdb
    exit $LASTEXITCODE
}

Stop-StaleQemu
Write-Host ""
Write-Host "QEMU  (Ctrl-A X to quit)" -ForegroundColor White
Write-Host ""

# idf_monitor decodes panic backtraces and resolves addresses to source, which
# is worth having - but it refuses to start unless stdin is a terminal
# ("Monitor requires standard input to be attached to TTY"). Under CI, or with
# output redirected, drop it and let QEMU write to stdout directly.
$interactive = -not [Console]::IsInputRedirected
if (-not $NoMonitor -and $interactive) {
    & idf.py @IdfArgs qemu monitor
} else {
    & idf.py @IdfArgs qemu
}
exit $LASTEXITCODE
