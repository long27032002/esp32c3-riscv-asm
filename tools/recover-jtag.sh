#!/usr/bin/env bash
#
# recover-jtag.sh - unstick the ESP32-C3 debug module.
#
# Symptoms this fixes, as printed by OpenOCD:
#     Timed out after Ns waiting for busy to go low (abstractcs=0x...)
#     Examination failed
#     Unsupported DTM version: -1
#
# Usually caused by a debug session that was cut off while the target was
# halted. A plain reset is NOT enough: "hard_reset" only restarts the CPU and
# leaves the debug module wedged. A watchdog reset restarts the whole digital
# core and clears it, without unplugging the cable.
#
# Nothing here is hardcoded to one machine: the ESP-IDF python environment is
# found by sourcing export.sh, exactly like tools/setup.sh does, because the
# directory name encodes both the ESP-IDF and the Python version
# (idf5.3_py3.14_env, idf5.5_py3.11_env, ...) and differs per installation.
#
# Usage:
#     ./tools/recover-jtag.sh                  detect everything
#     ./tools/recover-jtag.sh --port /dev/...  use this port
#     ./tools/recover-jtag.sh --idf-path DIR   use this ESP-IDF
#
set -o errexit
set -o nounset
set -o pipefail

TARGET="esp32c3"
ARG_PORT=""
ARG_IDF_PATH=""

while [ $# -gt 0 ]; do
    case "$1" in
        --port)     ARG_PORT="${2:-}"; shift ;;
        --idf-path) ARG_IDF_PATH="${2:-}"; shift ;;
        -h|--help)  sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *)          echo "unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

say()  { printf '    %s\n' "$*"; }
die()  { printf '[fail] %s\n' "$*" >&2; exit 1; }

# --------------------------------------------------------------- ESP-IDF ---
find_idf() {
    local candidate
    for candidate in \
        "${ARG_IDF_PATH}" "${IDF_PATH:-}" \
        "${HOME}/esp/esp-idf" "${HOME}/esp-idf" "/opt/esp-idf"
    do
        if [ -n "${candidate}" ] && [ -f "${candidate}/export.sh" ]; then
            printf '%s' "${candidate}"; return 0
        fi
    done
    for candidate in "${HOME}"/esp/*/esp-idf; do
        [ -f "${candidate}/export.sh" ] && { printf '%s' "${candidate}"; return 0; }
    done
    return 1
}

IDF_DIR="$(find_idf || true)"
[ -n "${IDF_DIR}" ] || die "ESP-IDF not found. Pass --idf-path DIR."

IDF_PYTHON="$(
    set +u
    # shellcheck disable=SC1091
    . "${IDF_DIR}/export.sh" >/dev/null 2>&1
    printf '%s' "${IDF_PYTHON_ENV_PATH}/bin/python"
)"
[ -x "${IDF_PYTHON}" ] || die "ESP-IDF python not found at ${IDF_PYTHON}"
say "ESP-IDF python: ${IDF_PYTHON}"

# ------------------------------------------------------------ serial port --
# The built-in USB-Serial-JTAG re-enumerates on every reset, so /dev/ttyACM0
# can become /dev/ttyACM1. The by-id path is keyed to the board's serial
# number and stays valid.
PORT="${ARG_PORT}"
if [ -z "${PORT}" ]; then
    for candidate in /dev/serial/by-id/*Espressif* /dev/serial/by-id/*USB_JTAG* \
                     /dev/ttyACM0 /dev/cu.usbmodem*
    do
        [ -e "${candidate}" ] && { PORT="${candidate}"; break; }
    done
fi
[ -n "${PORT}" ] || die "no serial port found. Plug the board in, or pass --port."
say "serial port:    ${PORT}"

# ------------------------------------------------------------- do the work -
# Match the process NAME, not the command line. "pkill -f <path>" would also
# match the shell running this script, because its command line contains the
# same path - the script would kill itself.
if pkill -x openocd 2>/dev/null; then
    say "stopped a running OpenOCD"
else
    say "no OpenOCD was running"
fi
sleep 1

say "sending a watchdog reset ..."
"${IDF_PYTHON}" -m esptool --chip "${TARGET}" -p "${PORT}" \
    --after watchdog_reset flash_id

printf '\n    Done. Start OpenOCD again; it should report "Examination succeed".\n'
