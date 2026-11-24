#!/usr/bin/env bash
#
# qemu.sh - run the firmware on Espressif's QEMU instead of a board.
#
# Useful when no ESP32-C3 is plugged in, when JTAG has wedged, or in CI. The
# CPU, the memory map and the registers are emulated faithfully enough to
# single-step assembly and read CSRs, which is what this template is about.
#
# WHAT QEMU DOES NOT EMULATE
#
# GPIO has no electrical side: asm_gpio_set and asm_gpio_clear write their
# registers and asm_gpio_read_all reads them back, but no LED lights up and
# the BOOT button can never be pressed. The performance counters advance with
# emulated instructions, not with real pipeline behaviour, so cycle counts are
# plausible but not the chip's. Flash and PSRAM timing are not modelled at all.
# Anything about timing or about the outside world still needs the board.
#
# Usage:
#     ./tools/qemu.sh                     # run, output in this terminal
#     ./tools/qemu.sh --gdb               # wait for a debugger on port 3333
#     ./tools/qemu.sh --project DIR       # a project other than the example
#     ./tools/qemu.sh --no-build          # reuse the existing build-qemu/
#     ./tools/qemu.sh --no-monitor        # raw QEMU output, no idf_monitor
#
# With --gdb, two terminals:
#     ./tools/qemu.sh --gdb
#     ./tools/qemu.sh --attach            # starts gdb on the same ELF
#
# Ctrl-A X quits QEMU. Ctrl-C reaches the emulated program, not QEMU.
#
set -o errexit
set -o nounset
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${REPO_ROOT}/examples/hello_asm"
GDB_WAIT=0
ATTACH=0
BUILD=1
MONITOR=1

# Not configurable. "idf.py qemu --gdb" hardcodes "-gdb tcp::3333", and QEMU
# honours the first -gdb on the command line, so appending another one through
# --qemu-extra-args is silently ignored. 3333 is also OpenOCD's port, which is
# why --gdb kills a running OpenOCD below rather than failing to bind.
GDB_PORT=3333

if [ -t 1 ]; then
    C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_B=$'\033[1m'
    C_DIM=$'\033[2m'; C_0=$'\033[0m'
else
    C_OK=""; C_ERR=""; C_B=""; C_DIM=""; C_0=""
fi
ok()   { printf '  %s[ ok ]%s %s\n' "${C_OK}" "${C_0}" "$*"; }
info() { printf '  %s%s%s\n' "${C_DIM}" "$*" "${C_0}"; }
die()  { printf '%s[fail]%s %s\n' "${C_ERR}" "${C_0}" "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--gdb)     GDB_WAIT=1 ;;
        -a|--attach)  ATTACH=1 ;;
        --project)    PROJECT="${2:-}"; shift ;;
        --no-build)   BUILD=0 ;;
        --no-monitor) MONITOR=0 ;;
        -h|--help)    sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *)            die "unknown option: $1" ;;
    esac
    shift
done

[ -d "${PROJECT}" ] || die "no such project: ${PROJECT}"

# ---------------------------------------------------------------------------
# ESP-IDF
# ---------------------------------------------------------------------------
if ! command -v idf.py >/dev/null 2>&1; then
    IDF_PATH="${IDF_PATH:-${HOME}/esp/esp-idf}"
    [ -f "${IDF_PATH}/export.sh" ] \
        || die "ESP-IDF not found. Set IDF_PATH, or run tools/setup.sh first."
    # shellcheck disable=SC1091
    . "${IDF_PATH}/export.sh" >/dev/null
fi

# ---------------------------------------------------------------------------
# The emulator itself
# ---------------------------------------------------------------------------
# Espressif ships its own QEMU fork; the distribution's qemu-system-riscv32
# knows nothing about the ESP32-C3 memory map.
#
# idf_tools.py lists qemu-riscv32 as optional, and export.sh exports only the
# tools every build needs, so even after a successful install the emulator is
# not on PATH and "idf.py qemu" reports it as not installed. Put it there.
#
# The version is read out of ESP-IDF's own tools.json rather than guessed from
# whatever directories happen to exist, so a stale install left over from an
# earlier ESP-IDF cannot be picked up by accident.
if ! command -v qemu-system-riscv32 >/dev/null 2>&1; then
    QEMU_PATHS="$(python3 - <<'PY'
import json, os
idf = os.environ['IDF_PATH']
tools = os.environ.get('IDF_TOOLS_PATH') or os.path.expanduser('~/.espressif')
try:
    spec = json.load(open(os.path.join(idf, 'tools', 'tools.json')))
    tool = next(t for t in spec['tools'] if t['name'] == 'qemu-riscv32')
    version = next(v for v in tool['versions']
                   if v['status'] == 'recommended')['name']
except (OSError, KeyError, StopIteration):
    raise SystemExit(0)
print(':'.join(os.path.join(tools, 'tools', tool['name'], version, *parts)
                for parts in tool['export_paths']))
PY
)"
    [ -n "${QEMU_PATHS}" ] && export PATH="${QEMU_PATHS}:${PATH}"
fi

if ! command -v qemu-system-riscv32 >/dev/null 2>&1; then
    printf '%s[fail]%s Espressif QEMU for RISC-V is not installed.\n\n' \
           "${C_ERR}" "${C_0}" >&2
    cat >&2 <<EOF
  Install it with:

      python "\${IDF_PATH}/tools/idf_tools.py" install qemu-riscv32

  then open a new shell, or source export.sh again.
EOF
    exit 1
fi

# The binary unpacks fine but needs libslirp at run time, and the error it
# gives ("cannot open shared object file") says nothing about which package to
# install. Check up front instead.
if ! qemu-system-riscv32 --version >/dev/null 2>&1; then
    printf '%s[fail]%s QEMU is installed but will not start:\n\n' \
           "${C_ERR}" "${C_0}" >&2
    qemu-system-riscv32 --version 2>&1 | sed 's/^/      /' >&2 || true
    cat >&2 <<'EOF'

  Espressif's build links against libslirp, which most distributions do not
  install by default:

      Arch         sudo pacman -S --needed libslirp
      Debian       sudo apt install libslirp0
      Fedora       sudo dnf install libslirp
      macOS        brew install libslirp
EOF
    exit 1
fi

cd "${PROJECT}"
PROJECT_NAME="$(basename "${PROJECT}")"

# A separate build directory, for two reasons. The console has to be moved off
# USB-Serial-JTAG (see sdkconfig.qemu), so the configuration genuinely differs
# from the board build; and sharing one directory would mean a full rebuild
# every time you alternate between the emulator and real hardware.
BUILD_DIR="${PROJECT}/build-qemu"
ELF="${BUILD_DIR}/${PROJECT_NAME}.elf"

# Projects created before this script existed have no sdkconfig.qemu; write
# the one setting that matters into the build directory instead of refusing.
QEMU_SDKCONFIG="${PROJECT}/sdkconfig.qemu"
if [ ! -f "${QEMU_SDKCONFIG}" ]; then
    mkdir -p "${BUILD_DIR}"
    QEMU_SDKCONFIG="${BUILD_DIR}/sdkconfig.qemu"
    cat > "${QEMU_SDKCONFIG}" <<'EOF'
CONFIG_ESP_CONSOLE_UART_DEFAULT=y
CONFIG_ESP_CONSOLE_SECONDARY_NONE=y
EOF
fi

# SDKCONFIG has to be redirected too. An existing project sdkconfig wins over
# SDKCONFIG_DEFAULTS - the defaults are only consulted when no sdkconfig
# exists - so without this the overlay is silently ignored and the build keeps
# the board's USB-Serial-JTAG console. It also stops the QEMU configuration
# from overwriting the one the board build uses.
IDF_ARGS=(-B "${BUILD_DIR}"
          -D "SDKCONFIG=${BUILD_DIR}/sdkconfig"
          -D "SDKCONFIG_DEFAULTS=sdkconfig.defaults;${QEMU_SDKCONFIG}")

# ---------------------------------------------------------------------------
# --attach: the debugger half of a --gdb session
# ---------------------------------------------------------------------------
if [ "${ATTACH}" -eq 1 ]; then
    [ -f "${ELF}" ] || die "nothing built yet: ${ELF}"
    ok "attaching to localhost:${GDB_PORT}"
    # QEMU's gdbstub is not OpenOCD: "monitor reset halt" and the flash
    # breakpoint commands do not exist there. Connecting is enough, because
    # --gdb already holds the CPU at the reset vector.
    exec riscv32-esp-elf-gdb "${ELF}" \
        -ex "set remotetimeout 20" \
        -ex "set print pretty on" \
        -ex "target remote localhost:${GDB_PORT}" \
        -ex "break sum_loop" \
        -ex "echo \n*** stopped at the reset vector; 'continue' to reach sum_loop ***\n"
fi

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
if [ "${BUILD}" -eq 1 ]; then
    info "building ${PROJECT_NAME}"
    idf.py "${IDF_ARGS[@]}" build >/dev/null
    ok "built"
else
    [ -f "${ELF}" ] || die "nothing built yet: ${ELF} (drop --no-build)"
fi

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
if [ "${GDB_WAIT}" -eq 1 ]; then
    # A stale emulator holds the gdb port and the next run fails with
    # "Failed to bind socket". Match the process NAME: matching the command
    # line with pkill -f would also match this script's own command line.
    pkill -x qemu-system-riscv32 2>/dev/null || true
    # QEMU's gdbstub and OpenOCD both want port 3333, and OpenOCD is the more
    # likely leftover: it keeps running after a debug session is stopped.
    pkill -x openocd 2>/dev/null || true
    sleep 0.3

    printf '\n%sQEMU, waiting for a debugger%s\n' "${C_B}" "${C_0}"
    info "elf:  ${ELF}"
    info "gdb:  localhost:${GDB_PORT}"
    echo

    # The ready line below is what the VS Code task's problem matcher waits
    # for. QEMU itself prints nothing when it stops at the reset vector, so
    # without it the debug session would start before the port is open. Print
    # it from a watcher that polls the port, not before launching QEMU.
    (
        for _ in $(seq 1 100); do
            if (exec 3<>"/dev/tcp/127.0.0.1/${GDB_PORT}") 2>/dev/null; then
                exec 3<&- 2>/dev/null || true
                echo "QEMU_READY: gdb server listening on localhost:${GDB_PORT}"
                exit 0
            fi
            sleep 0.1
        done
        echo "QEMU_FAILED: port ${GDB_PORT} never opened" >&2
    ) &

    exec idf.py "${IDF_ARGS[@]}" qemu --gdb
fi

printf '\n%sQEMU%s  (Ctrl-A X to quit)\n\n' "${C_B}" "${C_0}"

# idf_monitor decodes panic backtraces and resolves addresses to source, which
# is worth having - but it refuses to start unless stdin is a terminal
# ("Monitor requires standard input to be attached to TTY"). Under CI, or with
# output piped to a file, drop it and let QEMU write to stdout directly.
if [ "${MONITOR}" -eq 1 ] && [ -t 0 ]; then
    exec idf.py "${IDF_ARGS[@]}" qemu monitor
fi
exec idf.py "${IDF_ARGS[@]}" qemu
