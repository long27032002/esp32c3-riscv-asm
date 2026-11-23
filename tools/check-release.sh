#!/usr/bin/env bash
#
# check-release.sh - make sure nothing machine-specific is about to be shared.
#
# The generated files under .vscode/ legitimately contain absolute paths and
# one board's serial number: the ESP-IDF extension reads idf.* settings
# verbatim and does not expand variables, so there is no portable form. They
# are kept out of the repository by .gitignore instead.
#
# This script verifies that the protection actually holds. Run it before
# publishing, or let tools/setup.sh install it as a pre-commit hook.
#
# Usage:
#     ./tools/check-release.sh            check files tracked by git
#     ./tools/check-release.sh --staged   check what is staged for commit
#
# Exit code 0 = clean, 1 = something would leak.
#
set -o errexit
set -o nounset
set -o pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MODE="tracked"
[ "${1:-}" = "--staged" ] && MODE="staged"

if [ -t 1 ]; then
    C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_B=$'\033[1m'; C_0=$'\033[0m'
else
    C_OK=""; C_ERR=""; C_B=""; C_0=""
fi
ok()   { printf '  %s[ ok ]%s %s\n' "${C_OK}" "${C_0}" "$*"; }
bad()  { printf '  %s[fail]%s %s\n' "${C_ERR}" "${C_0}" "$*"; }

git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository"; exit 0; }

if [ "${MODE}" = "staged" ]; then
    FILES="$(git diff --cached --name-only --diff-filter=ACM)"
    GREP_ARGS="--cached"
else
    FILES="$(git ls-files)"
    GREP_ARGS=""
fi
[ -n "${FILES}" ] || { ok "nothing to check"; exit 0; }

printf '%sChecking %s files for machine-specific content%s\n' \
       "${C_B}" "${MODE}" "${C_0}"

FAILED=0

# 1. Files that must never be tracked, even if .gitignore is edited later.
FORBIDDEN='^(build/|sdkconfig$|\.vscode/(settings|launch|tasks)\.json$|managed_components/)'
HITS="$(printf '%s\n' "${FILES}" | grep -E "${FORBIDDEN}" || true)"
if [ -n "${HITS}" ]; then
    bad "generated files are tracked:"
    printf '%s\n' "${HITS}" | sed 's/^/         /'
    FAILED=1
else
    ok "no generated file is tracked"
fi

# 2. Absolute home directories of a particular user.
# shellcheck disable=SC2086
HITS="$(git grep -nI ${GREP_ARGS} -E '(/home/[a-z_][a-z0-9_-]*/|/Users/[a-z_][a-z0-9_-]*/|C:\\\\Users\\\\)' -- . || true)"
if [ -n "${HITS}" ]; then
    bad "absolute home paths found:"
    printf '%s\n' "${HITS}" | sed 's/^/         /'
    FAILED=1
else
    ok "no absolute home paths"
fi

# 3. Tool directory names that encode a version, outside explanatory prose.
# A command someone is meant to run must not contain one; mentioning one while
# explaining why is fine, so only lines that look like commands are flagged.
# shellcheck disable=SC2086
HITS="$(git grep -nI ${GREP_ARGS} -E 'python_env/idf[0-9]' -- . \
        | grep -vE 'differs per installation|khác nhau theo từng máy|and differs per' || true)"
if [ -n "${HITS}" ]; then
    bad "hardcoded ESP-IDF python environment in a command:"
    printf '%s\n' "${HITS}" | sed 's/^/         /'
    FAILED=1
else
    ok "no hardcoded python environment"
fi

# 4. Board serial numbers from a by-id path.
# shellcheck disable=SC2086
HITS="$(git grep -nI ${GREP_ARGS} -E 'usb-Espressif_USB_JTAG_serial_debug_unit_[0-9A-F]{2}:' -- . || true)"
if [ -n "${HITS}" ]; then
    bad "a specific board serial number is present:"
    printf '%s\n' "${HITS}" | sed 's/^/         /'
    FAILED=1
else
    ok "no board serial number"
fi

# 5. Obvious secrets.
# The literals below are split with a pair of empty quotes so that this file
# cannot match its own patterns. Spelling an SSH public-key prefix out in full
# anywhere in this file - even inside a comment - would make the scanner report
# itself. Same self-match trap as using "pkill -f <path>" in a task whose own
# command line contains that path.
SECRET_RE="(gh[pousr]_[A-Za-z0-9]{20,}"
SECRET_RE="${SECRET_RE}|BEGIN [A-Z ]*PRIVATE"" KEY"
SECRET_RE="${SECRET_RE}|ssh-rsa AA""AA|ssh-ed25519 AA""AA)"
# shellcheck disable=SC2086
HITS="$(git grep -nI ${GREP_ARGS} -E "${SECRET_RE}" -- . || true)"
if [ -n "${HITS}" ]; then
    bad "possible credential or private key:"
    printf '%s\n' "${HITS}" | sed 's/^/         /'
    FAILED=1
else
    ok "no credentials or keys"
fi

echo
if [ "${FAILED}" -eq 0 ]; then
    printf '%sClean - safe to publish.%s\n' "${C_OK}" "${C_0}"
else
    printf '%sDo not publish until the entries above are resolved.%s\n' \
           "${C_ERR}" "${C_0}"
fi
exit "${FAILED}"
