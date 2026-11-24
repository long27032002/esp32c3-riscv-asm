#!/usr/bin/env bash
#
# setup.sh - one-shot environment setup for the ESP32-C3 assembly template.
#
# What it does, in order:
#   1. checks for VS Code and offers to install it;
#   2. finds or installs ESP-IDF;
#   3. asks ESP-IDF itself where its toolchain, GDB and OpenOCD live, instead
#      of guessing - this is what keeps the versions consistent;
#   4. installs the VS Code extensions needed for build and debug, including
#      the MEMORY and xRTOS panels;
#   5. detects the board's serial port by its stable by-id path;
#   6. generates .vscode/{settings,launch,tasks}.json from tools/templates.
#
# Usage:
#   ./tools/setup.sh                 full setup
#   ./tools/setup.sh --check         report only, change nothing
#   ./tools/setup.sh --no-install    never install anything, only configure
#   ./tools/setup.sh --idf-path DIR  use this ESP-IDF instead of searching
#   ./tools/setup.sh --port DEV      use this serial port instead of detecting
#   ./tools/setup.sh --project DIR   configure this project instead of the
#                                    bundled example
#   ./tools/setup.sh --breakpoint S  stop at this symbol instead of app_main
#
set -o errexit
set -o nounset
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="${REPO_ROOT}/tools/templates"

# The repository root is a component, not a project, so there is nothing to
# debug here. Default to the bundled example; --project points at any other
# project, such as one made by tools/new-project.sh.
DEFAULT_PROJECT="${REPO_ROOT}/examples/hello_asm"
PROJECT_DIR="${DEFAULT_PROJECT}"

# Values substituted into the templates.
TARGET="esp32c3"
OPENOCD_CFG="board/esp32c3-builtin.cfg"
# Where the debugger stops first. The bundled example aims at the assembly
# loop, which is the point of it; any other project gets app_main, the only
# symbol every ESP-IDF project is guaranteed to have.
INITIAL_BREAKPOINT=""

MODE="setup"
ARG_IDF_PATH=""
ARG_PORT=""
ALLOW_INSTALL=1

# ----------------------------------------------------------------- output ---
if [ -t 1 ]; then
    C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'
    C_DIM=$'\033[2m'; C_B=$'\033[1m'; C_0=$'\033[0m'
else
    C_OK=""; C_WARN=""; C_ERR=""; C_DIM=""; C_B=""; C_0=""
fi
step() { printf '\n%s==> %s%s\n' "${C_B}" "$*" "${C_0}"; }
ok()   { printf '    %s[ ok ]%s %s\n'   "${C_OK}"   "${C_0}" "$*"; }
warn() { printf '    %s[warn]%s %s\n'   "${C_WARN}" "${C_0}" "$*"; }
die()  { printf '    %s[fail]%s %s\n\n' "${C_ERR}"  "${C_0}" "$*" >&2; exit 1; }
info() { printf '    %s%s%s\n' "${C_DIM}" "$*" "${C_0}"; }

ask_yes_no() {
    # $1 = question. Returns 0 for yes. Non-interactive runs answer "no".
    if [ ! -t 0 ]; then
        info "not a terminal, assuming no: $1"
        return 1
    fi
    local reply
    read -r -p "    $1 [y/N] " reply
    [[ "${reply}" =~ ^([yY]|[yY][eE][sS])$ ]]
}

# ------------------------------------------------------------- arguments ---
while [ $# -gt 0 ]; do
    case "$1" in
        --check)      MODE="check" ;;
        --no-install) ALLOW_INSTALL=0 ;;
        --idf-path)   ARG_IDF_PATH="${2:-}"; shift ;;
        --port)       ARG_PORT="${2:-}"; shift ;;
        --project)    PROJECT_DIR="$(cd "${2:-}" 2>/dev/null && pwd)" \
                          || die "no such directory: ${2:-}"; shift ;;
        --breakpoint) INITIAL_BREAKPOINT="${2:-}"; shift ;;
        -h|--help)    sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *)            die "unknown option: $1" ;;
    esac
    shift
done

printf '%s\n' "${C_B}ESP32-C3 assembly template - environment setup${C_0}"
info "project: ${PROJECT_DIR}"
[ "${PROJECT_DIR}" = "${DEFAULT_PROJECT}" ] \
    && info "(the bundled example; use --project DIR for your own)"

[ -f "${PROJECT_DIR}/CMakeLists.txt" ] \
    || die "${PROJECT_DIR} is not an ESP-IDF project: no CMakeLists.txt"

# The debugger needs the ELF name, which CMake takes from project().
PROJECT_NAME="$(sed -n 's/^[[:space:]]*project(\([A-Za-z0-9_]*\)).*/\1/p' \
                "${PROJECT_DIR}/CMakeLists.txt" | head -1)"
[ -n "${PROJECT_NAME}" ] \
    || die "could not read project() name from ${PROJECT_DIR}/CMakeLists.txt"

if [ -z "${INITIAL_BREAKPOINT}" ]; then
    if [ "${PROJECT_DIR}" = "${DEFAULT_PROJECT}" ]; then
        INITIAL_BREAKPOINT="sum_loop"
    else
        INITIAL_BREAKPOINT="app_main"
    fi
fi

VSCODE_DIR="${PROJECT_DIR}/.vscode"
[ "${MODE}" = "check" ] && info "check mode: nothing will be modified"

# ------------------------------------------------------- 1. prerequisites ---
step "Checking prerequisites"
for tool in git python3; do
    command -v "${tool}" >/dev/null 2>&1 \
        && ok "${tool} -> $(command -v "${tool}")" \
        || die "${tool} not found. Install it and run this script again."
done

case "$(uname -s)" in
    Linux)  OS_NAME="linux" ;;
    Darwin) OS_NAME="macos" ;;
    *)      die "unsupported OS: $(uname -s). Use tools/setup.ps1 on Windows." ;;
esac
ok "operating system: ${OS_NAME}"

# ------------------------------------------------------------ 2. VS Code ---
step "Looking for VS Code"
CODE_BIN="$(command -v code || command -v codium || true)"
if [ -n "${CODE_BIN}" ]; then
    ok "VS Code -> ${CODE_BIN} ($("${CODE_BIN}" --version 2>/dev/null | head -1))"
elif [ "${MODE}" = "check" ] || [ "${ALLOW_INSTALL}" -eq 0 ]; then
    warn "VS Code not found"
else
    warn "VS Code not found"
    if ask_yes_no "Install VS Code now?"; then
        if   command -v pacman  >/dev/null 2>&1; then
            info "Arch: the 'code' package is the OSS build; the Microsoft"
            info "build lives in the AUR as visual-studio-code-bin."
            sudo pacman -S --needed code || true
        elif command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y wget gpg
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
                | gpg --dearmor > /tmp/microsoft.gpg
            sudo install -D -o root -g root -m 644 /tmp/microsoft.gpg \
                /etc/apt/keyrings/microsoft.gpg
            echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg]" \
                 "https://packages.microsoft.com/repos/code stable main" \
                 | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
            sudo apt-get update && sudo apt-get install -y code
        elif command -v dnf    >/dev/null 2>&1; then
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
            sudo dnf install -y code
        elif command -v brew   >/dev/null 2>&1; then
            brew install --cask visual-studio-code
        else
            warn "no supported package manager found"
            info "install manually from https://code.visualstudio.com/"
        fi
        CODE_BIN="$(command -v code || true)"
    fi
fi

# ------------------------------------------------------------ 3. ESP-IDF ---
step "Looking for ESP-IDF"
find_idf() {
    local candidate
    for candidate in \
        "${ARG_IDF_PATH}" "${IDF_PATH:-}" \
        "${HOME}/esp/esp-idf" "${HOME}/esp/v5.3/esp-idf" "${HOME}/esp-idf" \
        "/opt/esp-idf"
    do
        if [ -n "${candidate}" ] && [ -f "${candidate}/export.sh" ]; then
            printf '%s' "${candidate}"; return 0
        fi
    done
    for candidate in "${HOME}"/esp/*/esp-idf; do
        if [ -f "${candidate}/export.sh" ]; then
            printf '%s' "${candidate}"; return 0
        fi
    done
    return 1
}

IDF_DIR="$(find_idf || true)"
if [ -n "${IDF_DIR}" ]; then
    ok "ESP-IDF -> ${IDF_DIR}"
    info "version: $(git -C "${IDF_DIR}" describe --tags 2>/dev/null || echo unknown)"
elif [ "${MODE}" = "check" ] || [ "${ALLOW_INSTALL}" -eq 0 ]; then
    die "ESP-IDF not found. Pass --idf-path DIR or install it."
else
    warn "ESP-IDF not found"
    if ask_yes_no "Clone and install ESP-IDF v5.3.5 into ~/esp/esp-idf? (~2 GB)"; then
        mkdir -p "${HOME}/esp"
        git clone -b v5.3.5 --recursive \
            https://github.com/espressif/esp-idf.git "${HOME}/esp/esp-idf"
        ( cd "${HOME}/esp/esp-idf" && ./install.sh "${TARGET}" )
        IDF_DIR="${HOME}/esp/esp-idf"
        ok "installed into ${IDF_DIR}"
    else
        die "ESP-IDF is required. Re-run with --idf-path DIR if you have one."
    fi
fi

# --------------------------------- 4. ask ESP-IDF where its tools live ------
# Sourcing export.sh in a subshell is the only reliable way to learn which
# toolchain, GDB and OpenOCD build belong to THIS ESP-IDF. Several versions of
# each tool usually coexist under ~/.espressif, and picking the newest by hand
# is how version mismatches start.
step "Asking ESP-IDF for its toolchain paths"
IDF_ENV="$(
    set +u
    # shellcheck disable=SC1091
    . "${IDF_DIR}/export.sh" >/dev/null 2>&1
    printf 'IDF_PATH=%s\n'            "${IDF_PATH}"
    printf 'IDF_PYTHON=%s\n'          "${IDF_PYTHON_ENV_PATH}/bin/python"
    printf 'OPENOCD_SCRIPTS=%s\n'     "${OPENOCD_SCRIPTS}"
    printf 'GDB_BIN=%s\n'             "$(command -v riscv32-esp-elf-gdb)"
    printf 'OPENOCD_BIN=%s\n'         "$(command -v openocd)"
    printf 'TOOLCHAIN_GCC=%s\n'       "$(command -v riscv32-esp-elf-gcc)"
)" || die "could not source ${IDF_DIR}/export.sh"

eval "$(printf '%s\n' "${IDF_ENV}" | sed 's/^/export /')"
IDF_TOOLS_PATH="${IDF_TOOLS_PATH:-${HOME}/.espressif}"

for var in IDF_PATH IDF_PYTHON OPENOCD_SCRIPTS GDB_BIN OPENOCD_BIN TOOLCHAIN_GCC; do
    value="${!var}"
    [ -n "${value}" ] || die "${var} is empty - is ESP-IDF installed? Run ${IDF_DIR}/install.sh ${TARGET}"
    [ -e "${value}" ] || die "${var} points to a missing path: ${value}"
    ok "${var} -> ${value}"
done

[ -f "${OPENOCD_SCRIPTS}/${OPENOCD_CFG}" ] \
    && ok "OpenOCD board file -> ${OPENOCD_CFG}" \
    || die "missing ${OPENOCD_SCRIPTS}/${OPENOCD_CFG}"

EXTRA_PATHS="$(dirname "${GDB_BIN}"):$(dirname "${TOOLCHAIN_GCC}"):$(dirname "${OPENOCD_BIN}")"

# -------------------------------------------------- 5. VS Code extensions ---
step "VS Code extensions"
EXTENSIONS=(
    "espressif.esp-idf-extension"   # build, flash and the gdbtarget debug type
    "ms-vscode.cpptools"            # C/C++ language support
    "mcu-debug.memory-view"         # the MEMORY panel
    "mcu-debug.rtos-views"          # the xRTOS panel (FreeRTOS task list)
)
if [ -z "${CODE_BIN}" ]; then
    warn "VS Code not available, skipping extensions"
    info "install later with: code --install-extension <id>"
else
    INSTALLED="$("${CODE_BIN}" --list-extensions 2>/dev/null || true)"
    for ext in "${EXTENSIONS[@]}"; do
        if printf '%s\n' "${INSTALLED}" | grep -qix "${ext}"; then
            ok "${ext} (already installed)"
        elif [ "${MODE}" = "check" ] || [ "${ALLOW_INSTALL}" -eq 0 ]; then
            warn "${ext} is missing"
        else
            info "installing ${ext} ..."
            "${CODE_BIN}" --install-extension "${ext}" --force >/dev/null 2>&1 \
                && ok "${ext} installed" \
                || warn "could not install ${ext}, do it from the Extensions view"
        fi
    done
fi

# ------------------------------------------------------- 6. serial port -----
# The built-in USB-Serial-JTAG re-enumerates on every reset, so /dev/ttyACM0
# can become /dev/ttyACM1. The by-id path is tied to the board's serial number
# and never changes.
step "Detecting the board"
SERIAL_PORT=""
# Decides which debug configuration VS Code offers first. Without a board the
# OpenOCD configurations cannot work, and picking one produces errors that
# name OpenOCD rather than the missing board: "OpenOCD is not running", then
# "monitor command not supported by this target" when the post-connect
# commands run on a session that never connected.
BOARD_PRESENT=1
if [ -n "${ARG_PORT}" ]; then
    SERIAL_PORT="${ARG_PORT}"
    ok "serial port from --port: ${SERIAL_PORT}"
else
    for candidate in /dev/serial/by-id/*Espressif* /dev/serial/by-id/*USB_JTAG*; do
        [ -e "${candidate}" ] || continue
        SERIAL_PORT="${candidate}"; break
    done
    if [ -n "${SERIAL_PORT}" ]; then
        ok "serial port: ${SERIAL_PORT}"
        info "resolves to $(readlink -f "${SERIAL_PORT}")"
    else
        for candidate in /dev/ttyACM0 /dev/ttyUSB0 /dev/cu.usbmodem*; do
            [ -e "${candidate}" ] && { SERIAL_PORT="${candidate}"; break; }
        done
        if [ -n "${SERIAL_PORT}" ]; then
            warn "no by-id entry, falling back to ${SERIAL_PORT}"
            warn "this name can change after a reset; re-run setup if it does"
        else
            SERIAL_PORT="/dev/ttyACM0"
            BOARD_PRESENT=0
            warn "no board detected - plug it in and re-run, or pass --port"
        fi
    fi
fi

if [ "${OS_NAME}" = "linux" ] && [ -e "${SERIAL_PORT}" ]; then
    if [ -r "${SERIAL_PORT}" ] && [ -w "${SERIAL_PORT}" ]; then
        ok "serial port is readable and writable"
    else
        warn "no permission on ${SERIAL_PORT}"
        info "fix with: sudo usermod -aG uucp,dialout \"\$USER\"  (then log out and back in)"
    fi
fi

# ------------------------------------------------- 7. generate .vscode ------
# The repository root used to be a project, and a .vscode/ generated back
# then survives as an untracked leftover: three OpenOCD configurations, each
# with "monitor reset halt", pointing at an ELF that no longer exists. Opening
# the root in VS Code offers those, and with no board the session fails as
#
#     OpenOCD is not running
#     "monitor" command not supported by this target.
#
# which names neither the stale file nor the missing board. The root is not a
# project any more - there is no project() in its CMakeLists.txt, and there is
# no CMakeLists.txt at all - so nothing there should offer a debug session.
if [ "${MODE}" != "check" ] \
   && [ "${PROJECT_DIR}" != "${REPO_ROOT}" ] \
   && [ ! -f "${REPO_ROOT}/CMakeLists.txt" ]; then
    for stale in launch.json tasks.json settings.json; do
        if [ -f "${REPO_ROOT}/.vscode/${stale}" ]; then
            rm -f "${REPO_ROOT}/.vscode/${stale}"
            warn "removed stale ${stale} at the repository root"
            warn "the root is not a project - open ${PROJECT_DIR#"${REPO_ROOT}"/} instead"
        fi
    done
fi

step "Generating .vscode configuration"
if [ "${MODE}" = "check" ]; then
    info "check mode: skipping file generation"
else
    mkdir -p "${VSCODE_DIR}"
    render() {
        local src="${TEMPLATE_DIR}/$1.in" dst="${VSCODE_DIR}/$1"
        [ -f "${src}" ] || die "missing template ${src}"
        [ -f "${dst}" ] && cp "${dst}" "${dst}.bak"
        sed -e "s|@IDF_PATH@|${IDF_PATH}|g" \
            -e "s|@IDF_TOOLS_PATH@|${IDF_TOOLS_PATH}|g" \
            -e "s|@IDF_PYTHON@|${IDF_PYTHON}|g" \
            -e "s|@OPENOCD_BIN@|${OPENOCD_BIN}|g" \
            -e "s|@OPENOCD_SCRIPTS@|${OPENOCD_SCRIPTS}|g" \
            -e "s|@OPENOCD_CFG@|${OPENOCD_CFG}|g" \
            -e "s|@GDB_BIN@|${GDB_BIN}|g" \
            -e "s|@TOOLCHAIN_GCC@|${TOOLCHAIN_GCC}|g" \
            -e "s|@EXTRA_PATHS@|${EXTRA_PATHS}|g" \
            -e "s|@SERIAL_PORT@|${SERIAL_PORT}|g" \
            -e "s|@TARGET@|${TARGET}|g" \
            -e "s|@PROJECT_NAME@|${PROJECT_NAME}|g" \
            -e "s|@INITIAL_BREAKPOINT@|${INITIAL_BREAKPOINT}|g" \
            -e "s|@QEMU_SH@|${REPO_ROOT}/tools/qemu.sh|g" \
            -e "s|@GDB_QEMU@|${VSCODE_DIR}/gdb-qemu.sh|g" \
            "${src}" > "${dst}"
        ok "${dst#"${PROJECT_DIR}"/}"
    }
    # gdb wrapper for the QEMU configuration.
    #
    # The restricted target description has to be loaded before gdb connects,
    # and the only hook the debug adapter offers that early is
    # connectCommands - but supplying those replaces the adapter's own
    # connect, and that route ended in "monitor command not supported by this
    # target". Starting gdb with -x sidesteps the adapter completely: the
    # command file is read at startup, before anything else happens.
    printf 'set tdesc filename %s\n' "${TEMPLATE_DIR}/riscv-qemu.xml" \
        > "${VSCODE_DIR}/qemu-tdesc.gdb"
    cat > "${VSCODE_DIR}/gdb-qemu.sh" <<WRAP
#!/usr/bin/env bash
# GENERATED BY tools/setup.sh - DO NOT EDIT BY HAND.
exec "${GDB_BIN}" -x "${VSCODE_DIR}/qemu-tdesc.gdb" "\$@"
WRAP
    chmod +x "${VSCODE_DIR}/gdb-qemu.sh"
    ok "$(basename "${VSCODE_DIR}")/gdb-qemu.sh"

    render settings.json
    render launch.json
    render tasks.json

    # VS Code offers the first configuration in the list by default. With no
    # board attached only the QEMU one can work, and choosing an OpenOCD one
    # by accident fails in a way that never mentions the board: first
    # "OpenOCD is not running", then, because the post-connect commands run
    # on a session that never connected, the gdb error
    # "monitor command not supported by this target".
    "${IDF_PYTHON}" - "${VSCODE_DIR}/launch.json" "${BOARD_PRESENT}" <<'PY'
import sys, pathlib

path, board_present = pathlib.Path(sys.argv[1]), sys.argv[2] == "1"
text = path.read_text(encoding="utf8")
begin, end = "        // @QEMU_BLOCK_BEGIN@\n", "        // @QEMU_BLOCK_END@\n"

if begin in text and end in text:
    head, rest = text.split(begin, 1)
    block, tail = rest.split(end, 1)
    if board_present:
        text = head + block + tail
    else:
        # Insert ahead of the first configuration, which starts on the line
        # after "configurations": [ .
        anchor = '"configurations": [\n'
        i = head.index(anchor) + len(anchor)
        text = head[:i] + block + head[i:] + tail
    path.write_text(text, encoding="utf8")
PY

    # Validate the generated JSONC: a stray character here turns into an
    # unhelpful VS Code error hours later.
    python3 - "${VSCODE_DIR}" <<'PY' || die "generated JSON is invalid"
import json, re, sys, pathlib
bad = False
for p in sorted(pathlib.Path(sys.argv[1]).glob("*.json")):
    text = re.sub(r'(?m)^\s*//.*$', '', p.read_text(encoding="utf8"))
    try:
        json.loads(text)
        print(f"    [ ok ] {p.name} is valid JSON")
    except Exception as exc:
        print(f"    [fail] {p.name}: {exc}")
        bad = True
sys.exit(1 if bad else 0)
PY
fi

# --------------------------------------------- 8. guard against leaking -----
# The generated .vscode files contain absolute paths and one board's serial
# number. .gitignore keeps them out of the repository, but a hurried
# "git add -f" would defeat that, so install a pre-commit hook as a second
# line of defence. Never overwrite a hook the user already has.
step "Installing the pre-commit guard"
HOOK_DIR="${REPO_ROOT}/.git/hooks"
if [ ! -d "${REPO_ROOT}/.git" ]; then
    info "not a git repository, skipping"
elif [ "${MODE}" = "check" ]; then
    info "check mode: skipping"
elif [ -e "${HOOK_DIR}/pre-commit" ]; then
    warn "a pre-commit hook already exists, leaving it alone"
    info "run ./tools/check-release.sh --staged by hand before publishing"
else
    mkdir -p "${HOOK_DIR}"
    cat > "${HOOK_DIR}/pre-commit" <<'HOOK'
#!/bin/sh
# Installed by tools/setup.sh. Blocks commits that would leak machine-specific
# paths or a board serial number. Bypass once with: git commit --no-verify
exec "$(git rev-parse --show-toplevel)/tools/check-release.sh" --staged
HOOK
    chmod +x "${HOOK_DIR}/pre-commit"
    ok "pre-commit hook installed (bypass once with git commit --no-verify)"
fi

# ----------------------------------------------------------- 9. summary -----
step "Done"
cat <<EOF
    Next steps:

      1. Open the PROJECT folder in VS Code (not the repository root):
             code "${PROJECT_DIR}"
      2. Build:  Ctrl+Shift+B
      3. Flash and watch the console:
             Terminal -> Run Task -> "flash + monitor"
      4. Debug:  F5   (stops at "${INITIAL_BREAKPOINT}")

    From a terminal, without VS Code:

         . "${IDF_PATH}/export.sh"
         cd "${PROJECT_DIR}"
         idf.py build
         idf.py -p "${SERIAL_PORT}" flash monitor

    If JTAG ever gets stuck ("Examination failed"):
         Terminal -> Run Task -> "recover JTAG (watchdog reset)"
EOF
