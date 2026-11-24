<#
.SYNOPSIS
    Environment setup for the ESP32-C3 assembly template on Windows.

.DESCRIPTION
    Mirrors tools/setup.sh:
      1. checks for VS Code and offers to install it through winget;
      2. finds or installs ESP-IDF;
      3. asks ESP-IDF itself where its toolchain, GDB and OpenOCD live,
         instead of guessing, so the versions always match;
      4. installs the VS Code extensions needed for build and debug,
         including the MEMORY and xRTOS panels;
      5. detects the board's COM port;
      6. generates .vscode\{settings,launch,tasks}.json from tools\templates.

.PARAMETER Check
    Report only; change nothing.

.PARAMETER NoInstall
    Never install anything, only configure.

.PARAMETER IdfPath
    Use this ESP-IDF directory instead of searching.

.PARAMETER Port
    Use this COM port instead of detecting one.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\setup.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\setup.ps1 -Check
#>

[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$NoInstall,
    [string]$IdfPath = "",
    [string]$Port = ""
)

$ErrorActionPreference = "Stop"

$ProjectDir  = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$TemplateDir = Join-Path $ProjectDir "tools\templates"
$VscodeDir   = Join-Path $ProjectDir ".vscode"

# Values substituted into the templates.
$Target            = "esp32c3"
$OpenOcdCfg        = "board/esp32c3-builtin.cfg"
$ProjectName       = "esp32c3_asm_template"
$InitialBreakpoint = "sum_loop"

function Write-Step { param($m) Write-Host "`n==> $m" -ForegroundColor White }
function Write-Ok   { param($m) Write-Host "    [ ok ] $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "    [warn] $m" -ForegroundColor Yellow }
function Write-Info { param($m) Write-Host "    $m" -ForegroundColor DarkGray }
function Die        { param($m) Write-Host "    [fail] $m`n" -ForegroundColor Red; exit 1 }

function Ask-YesNo {
    param($Question)
    if ([Console]::IsInputRedirected) {
        Write-Info "not interactive, assuming no: $Question"
        return $false
    }
    $reply = Read-Host "    $Question [y/N]"
    return $reply -match '^(y|yes)$'
}

Write-Host "ESP32-C3 assembly template - environment setup" -ForegroundColor White
Write-Info "project: $ProjectDir"
if ($Check) { Write-Info "check mode: nothing will be modified" }

# ------------------------------------------------------------ VS Code ------
Write-Step "Looking for VS Code"
$CodeCmd = (Get-Command code -ErrorAction SilentlyContinue)
if ($CodeCmd) {
    Write-Ok "VS Code -> $($CodeCmd.Source)"
} elseif ($Check -or $NoInstall) {
    Write-Warn "VS Code not found"
} else {
    Write-Warn "VS Code not found"
    if (Ask-YesNo "Install VS Code with winget?") {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install -e --id Microsoft.VisualStudioCode `
                   --accept-package-agreements --accept-source-agreements
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") +
                        ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $CodeCmd = (Get-Command code -ErrorAction SilentlyContinue)
        } else {
            Write-Warn "winget not available"
            Write-Info "install manually from https://code.visualstudio.com/"
        }
    }
}

# ------------------------------------------------------------ ESP-IDF ------
Write-Step "Looking for ESP-IDF"
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

if ($IdfDir) {
    Write-Ok "ESP-IDF -> $IdfDir"
} elseif ($Check -or $NoInstall) {
    Die "ESP-IDF not found. Pass -IdfPath DIR or install it."
} else {
    Write-Warn "ESP-IDF not found"
    Write-Info "The recommended installer is the ESP-IDF Windows installer:"
    Write-Info "  https://dl.espressif.com/dl/esp-idf/"
    Write-Info "It installs ESP-IDF, the toolchain, OpenOCD and the drivers."
    if (Ask-YesNo "Clone ESP-IDF v5.3.5 into $env:USERPROFILE\esp\esp-idf instead? (~2 GB)") {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Die "git not found. Install Git for Windows first."
        }
        New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\esp" | Out-Null
        git clone -b v5.3.5 --recursive `
            https://github.com/espressif/esp-idf.git "$env:USERPROFILE\esp\esp-idf"
        & "$env:USERPROFILE\esp\esp-idf\install.ps1" $Target
        $IdfDir = "$env:USERPROFILE\esp\esp-idf"
    } else {
        Die "ESP-IDF is required."
    }
}

# ------------------------------- ask ESP-IDF where its tools live ----------
# Importing export.ps1 into a child process is the only reliable way to learn
# which toolchain, GDB and OpenOCD build belong to THIS ESP-IDF. Several
# versions usually coexist under the tools directory.
Write-Step "Asking ESP-IDF for its toolchain paths"
$probe = @"
`$ErrorActionPreference = 'SilentlyContinue'
. '$IdfDir\export.ps1' | Out-Null
`$g = (Get-Command riscv32-esp-elf-gdb).Source
`$o = (Get-Command openocd).Source
`$c = (Get-Command riscv32-esp-elf-gcc).Source
Write-Output "IDF_PATH=`$env:IDF_PATH"
Write-Output "IDF_PYTHON=`$env:IDF_PYTHON_ENV_PATH\Scripts\python.exe"
Write-Output "IDF_TOOLS_PATH=`$env:IDF_TOOLS_PATH"
Write-Output "OPENOCD_SCRIPTS=`$env:OPENOCD_SCRIPTS"
Write-Output "GDB_BIN=`$g"
Write-Output "OPENOCD_BIN=`$o"
Write-Output "TOOLCHAIN_GCC=`$c"
"@
$lines = & powershell -NoProfile -ExecutionPolicy Bypass -Command $probe
$V = @{}
foreach ($line in $lines) {
    if ($line -match '^([A-Z_]+)=(.*)$') { $V[$Matches[1]] = $Matches[2] }
}
if (-not $V["IDF_TOOLS_PATH"]) { $V["IDF_TOOLS_PATH"] = "$env:USERPROFILE\.espressif" }

foreach ($key in @("IDF_PATH","IDF_PYTHON","OPENOCD_SCRIPTS","GDB_BIN","OPENOCD_BIN","TOOLCHAIN_GCC")) {
    if (-not $V[$key]) { Die "$key is empty - run $IdfDir\install.ps1 $Target" }
    if (-not (Test-Path $V[$key])) { Die "$key points to a missing path: $($V[$key])" }
    Write-Ok "$key -> $($V[$key])"
}

$boardFile = Join-Path $V["OPENOCD_SCRIPTS"] ($OpenOcdCfg -replace '/', '\')
if (Test-Path $boardFile) { Write-Ok "OpenOCD board file -> $OpenOcdCfg" }
else { Die "missing $boardFile" }

$ExtraPaths = @(
    (Split-Path $V["GDB_BIN"]),
    (Split-Path $V["TOOLCHAIN_GCC"]),
    (Split-Path $V["OPENOCD_BIN"])
) -join ";"

# -------------------------------------------------- VS Code extensions ----
Write-Step "VS Code extensions"
$Extensions = @(
    "espressif.esp-idf-extension",   # build, flash and the gdbtarget debug type
    "ms-vscode.cpptools",            # C/C++ language support
    "mcu-debug.memory-view",         # the MEMORY panel
    "mcu-debug.rtos-views"           # the xRTOS panel (FreeRTOS task list)
)
if (-not $CodeCmd) {
    Write-Warn "VS Code not available, skipping extensions"
} else {
    $installed = & code --list-extensions 2>$null
    foreach ($ext in $Extensions) {
        if ($installed -contains $ext) {
            Write-Ok "$ext (already installed)"
        } elseif ($Check -or $NoInstall) {
            Write-Warn "$ext is missing"
        } else {
            Write-Info "installing $ext ..."
            & code --install-extension $ext --force 2>$null | Out-Null
            Write-Ok "$ext installed"
        }
    }
}

# ---------------------------------------------------------- serial port ----
Write-Step "Detecting the board"
$SerialPort = ""
if ($Port) {
    $SerialPort = $Port
    Write-Ok "serial port from -Port: $SerialPort"
} else {
    # The built-in USB-Serial-JTAG enumerates with VID 303A, PID 1001.
    $dev = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -match '\(COM\d+\)' -and
                          ($_.Name -match 'USB JTAG' -or $_.PNPDeviceID -match 'VID_303A') } |
           Select-Object -First 1
    if ($dev -and $dev.Name -match '\((COM\d+)\)') {
        $SerialPort = $Matches[1]
        Write-Ok "serial port: $SerialPort  ($($dev.Name))"
    } else {
        $any = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '\(COM\d+\)' } | Select-Object -First 1
        if ($any -and $any.Name -match '\((COM\d+)\)') {
            $SerialPort = $Matches[1]
            Write-Warn "no Espressif device found, falling back to $SerialPort"
        } else {
            $SerialPort = "COM3"
            Write-Warn "no board detected - plug it in and re-run, or pass -Port"
        }
    }
}

# ------------------------------------------------------ generate .vscode ---
Write-Step "Generating .vscode configuration"
if ($Check) {
    Write-Info "check mode: skipping file generation"
} else {
    New-Item -ItemType Directory -Force -Path $VscodeDir | Out-Null

    # JSON needs backslashes escaped; keep forward slashes instead, which
    # VS Code and the ESP-IDF extension both accept on Windows.
    function ToJsonPath { param($p) return ($p -replace '\\', '/') }

    # Counterparts of what setup.sh generates for QEMU: a gdb wrapper that
    # loads the restricted target description with -x before connecting, and
    # the command file it reads. Done as a .cmd here rather than a shell
    # script so cmd.exe can execute it directly.
    $TdescFile  = Join-Path $VscodeDir "qemu-tdesc.gdb"
    $GdbWrapper = Join-Path $VscodeDir "gdb-qemu.cmd"
    Set-Content -Path $TdescFile -Encoding ascii `
        -Value ("set tdesc filename " + (ToJsonPath (Join-Path $TemplateDir "riscv-qemu.xml")))
    Set-Content -Path $GdbWrapper -Encoding ascii -Value @(
        "@echo off",
        "REM GENERATED BY tools\setup.ps1 - DO NOT EDIT BY HAND.",
        ('"' + $V["GDB_BIN"] + '" -x "' + $TdescFile + '" %*')
    )

    $map = @{
        "@GDB_QEMU@"          = (ToJsonPath $GdbWrapper)
        "@QEMU_SH@"           = (ToJsonPath (Join-Path $ProjectDir "tools\qemu.bat"))
        "@IDF_PATH@"          = (ToJsonPath $V["IDF_PATH"])
        "@IDF_TOOLS_PATH@"    = (ToJsonPath $V["IDF_TOOLS_PATH"])
        "@IDF_PYTHON@"        = (ToJsonPath $V["IDF_PYTHON"])
        "@OPENOCD_BIN@"       = (ToJsonPath $V["OPENOCD_BIN"])
        "@OPENOCD_SCRIPTS@"   = (ToJsonPath $V["OPENOCD_SCRIPTS"])
        "@OPENOCD_CFG@"       = $OpenOcdCfg
        "@GDB_BIN@"           = (ToJsonPath $V["GDB_BIN"])
        "@TOOLCHAIN_GCC@"     = (ToJsonPath $V["TOOLCHAIN_GCC"])
        "@EXTRA_PATHS@"       = (ToJsonPath $ExtraPaths)
        "@SERIAL_PORT@"       = $SerialPort
        "@TARGET@"            = $Target
        "@PROJECT_NAME@"      = $ProjectName
        "@INITIAL_BREAKPOINT@"= $InitialBreakpoint
    }

    # The ordering markers are only meaningful to setup.sh, which moves the
    # block they wrap. Here they are simply removed so they cannot show up in
    # the generated file.
    $strip = @("        // @QEMU_BLOCK_BEGIN@`r`n", "        // @QEMU_BLOCK_END@`r`n",
               "        // @QEMU_BLOCK_BEGIN@`n",  "        // @QEMU_BLOCK_END@`n")

    foreach ($name in @("settings.json", "launch.json", "tasks.json")) {
        $src = Join-Path $TemplateDir "$name.in"
        $dst = Join-Path $VscodeDir $name
        if (-not (Test-Path $src)) { Die "missing template $src" }
        if (Test-Path $dst) { Copy-Item $dst "$dst.bak" -Force }
        $text = Get-Content $src -Raw
        foreach ($k in $map.Keys) { $text = $text.Replace($k, $map[$k]) }
        foreach ($m in $strip)    { $text = $text.Replace($m, "") }
        Set-Content -Path $dst -Value $text -Encoding UTF8
        Write-Ok ".vscode\$name"
    }

    # The shell commands in tasks.json use pkill and POSIX quoting, which do
    # not exist in cmd.exe or PowerShell. Rewrite them for Windows.
    $tasksPath = Join-Path $VscodeDir "tasks.json"
    $tasks = Get-Content $tasksPath -Raw
    $tasks = $tasks.Replace(
        "pkill -x openocd 2>/dev/null; sleep 0.5; exec ",
        "taskkill /IM openocd.exe /F 2>`$null; ")
    # The recovery task shells out to recover-jtag.ps1 rather than repeating
    # the esptool invocation, so there is one implementation to maintain.
    $tasks = [regex]::Replace(
        $tasks,
        'pkill -x openocd 2>/dev/null; sleep 1; [^"]*--after watchdog_reset flash_id',
        'powershell -NoProfile -ExecutionPolicy Bypass -File \"${workspaceFolder}/tools/recover-jtag.ps1\"')
    $tasks = $tasks.Replace(
        "pkill -x openocd && echo killed || echo 'nothing running'",
        "taskkill /IM openocd.exe /F")
    $tasks = $tasks.Replace(". '$($V["IDF_PATH"] -replace '\\','/')/export.sh' >/dev/null && ", "")
    Set-Content -Path $tasksPath -Value $tasks -Encoding UTF8
    Write-Ok "tasks.json adapted for Windows shells"

    # Validate the generated JSONC.
    $py = $V["IDF_PYTHON"]
    $validator = @'
import json, re, sys, pathlib
bad = False
for p in sorted(pathlib.Path(sys.argv[1]).glob("*.json")):
    text = re.sub(r"(?m)^\s*//.*$", "", p.read_text(encoding="utf8"))
    try:
        json.loads(text)
        print("    [ ok ] %s is valid JSON" % p.name)
    except Exception as exc:
        print("    [fail] %s: %s" % (p.name, exc))
        bad = True
sys.exit(1 if bad else 0)
'@
    $tmp = Join-Path $env:TEMP "validate_vscode_json.py"
    Set-Content -Path $tmp -Value $validator -Encoding UTF8
    & $py $tmp $VscodeDir
    if ($LASTEXITCODE -ne 0) { Die "generated JSON is invalid" }
}

# ---------------------------------------------------------------- summary --
Write-Step "Done"
@"
    Next steps:

      1. Open THIS folder in VS Code (not its parent):
             code "$ProjectDir"
      2. Build:  Ctrl+Shift+B
      3. Flash and watch the console:
             Terminal -> Run Task -> "flash + monitor"
      4. Debug:  F5   (stops at "$InitialBreakpoint")

    From a terminal, without VS Code:

         & "$($V["IDF_PATH"])\export.ps1"
         cd "$ProjectDir"
         idf.py build
         idf.py -p $SerialPort flash monitor

    If JTAG ever gets stuck ("Examination failed"):
         Terminal -> Run Task -> "recover JTAG (watchdog reset)"
"@ | Write-Host
