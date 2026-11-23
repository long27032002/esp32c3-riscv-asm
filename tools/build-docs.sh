#!/usr/bin/env bash
#
# build-docs.sh - generate the documentation in both languages.
#
#   docs/html/index.html   language chooser
#   docs/html/en/          English  (Doxyfile)
#   docs/html/vi/          Vietnamese (Doxyfile.vi)
#
# Only Doxygen's own chrome is translated - headings, navigation, table
# captions. The source comments stay English in both builds, by project
# convention, so the API reference reads the same either way; what changes is
# the surrounding text and which README becomes the main page.
#
# Any Doxygen warning fails the build, with one exception: Doxygen reports
# that its Vietnamese translation has not been updated since release 1.6.0.
# That is a statement about Doxygen itself, not about this project, and there
# is nothing to fix here, so it is filtered out by name rather than by
# loosening the check.
#
# Usage:
#     ./tools/build-docs.sh            build both
#     ./tools/build-docs.sh en         build English only
#     ./tools/build-docs.sh vi         build Vietnamese only
#
set -o errexit
set -o nounset
set -o pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -t 1 ]; then
    C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_B=$'\033[1m'; C_0=$'\033[0m'
else
    C_OK=""; C_ERR=""; C_B=""; C_0=""
fi
ok()  { printf '  %s[ ok ]%s %s\n' "${C_OK}" "${C_0}" "$*"; }
bad() { printf '  %s[fail]%s %s\n' "${C_ERR}" "${C_0}" "$*"; }

command -v doxygen >/dev/null 2>&1 || {
    bad "doxygen not installed"
    printf '         Debian/Ubuntu: sudo apt install doxygen\n'
    printf '         Arch:          sudo pacman -S doxygen\n'
    printf '         macOS:         brew install doxygen\n'
    exit 1
}

WANTED="${1:-both}"
FAILED=0

# The known Doxygen notice about its own Vietnamese translation, matched by
# its exact wording so a genuine warning can never slip through with it.
KNOWN_NOTICE='has not been updated|since release 1\.6\.0|some sentences may appear in English'

build_one() {
    local lang="$1" conf="$2" out="$3" log
    log="$(mktemp)"

    printf '%sBuilding %s documentation%s\n' "${C_B}" "${lang}" "${C_0}"

    # Doxygen creates only the last component of its output path, so a nested
    # HTML_OUTPUT such as "html/en" fails with "Could not create output
    # directory" unless the parent already exists.
    mkdir -p "${out}"

    doxygen "${conf}" 2>"${log}" >/dev/null || true

    # Match errors as well as warnings. Doxygen reports a missing output
    # directory as "error:" and still exits 0, so grepping only for "warning"
    # reports a clean build that produced no files at all.
    local real
    real="$(grep -iE 'warning|error' "${log}" | grep -vE "${KNOWN_NOTICE}" || true)"

    if [ -n "${real}" ]; then
        bad "Doxygen reported warnings:"
        printf '%s\n' "${real}" | sed 's/^/         /'
        FAILED=1
    else
        ok "no warnings"
    fi

    if grep -qiE "${KNOWN_NOTICE}" "${log}"; then
        printf '         (ignored: Doxygen says its own Vietnamese translation\n'
        printf '          is older than release 1.6.0, so some of its chrome\n'
        printf '          stays English - nothing to fix in this project)\n'
    fi

    # Trust the files, not the log: a build can be quiet and still produce
    # nothing.
    if [ -f "${out}/index.html" ]; then
        ok "${out}/index.html"
    else
        bad "no index.html was produced in ${out}"
        FAILED=1
    fi

    rm -f "${log}"
}

rm -rf docs/html

case "${WANTED}" in
    en)   build_one English    Doxyfile    docs/html/en ;;
    vi)   build_one Vietnamese Doxyfile.vi docs/html/vi ;;
    both) build_one English    Doxyfile    docs/html/en
          build_one Vietnamese Doxyfile.vi docs/html/vi ;;
    *)    bad "unknown argument: ${WANTED} (use en, vi, or nothing)"; exit 1 ;;
esac

# ------------------------------------------------------------- chooser -----
if [ "${WANTED}" = "both" ]; then
    cat > docs/html/index.html <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>ESP32-C3 RISC-V Assembly Template - Documentation</title>
<style>
  body { font-family: system-ui, sans-serif; max-width: 34rem;
         margin: 4rem auto; padding: 0 1rem; line-height: 1.6; }
  h1 { font-size: 1.4rem; }
  a.card { display: block; border: 1px solid #ccc; border-radius: 8px;
           padding: 1rem 1.2rem; margin: 0.8rem 0; text-decoration: none;
           color: inherit; }
  a.card:hover { border-color: #888; background: #f6f6f6; }
  .lang { font-weight: 600; }
  .note { color: #666; font-size: 0.9rem; }
  @media (prefers-color-scheme: dark) {
    body { background: #121212; color: #e6e6e6; }
    a.card { border-color: #444; }
    a.card:hover { border-color: #777; background: #1d1d1d; }
    .note { color: #aaa; }
  }
</style>
<h1>ESP32-C3 RISC-V Assembly Template</h1>
<p class="note">Choose a language / Chọn ngôn ngữ</p>
<a class="card" href="en/index.html">
  <span class="lang">English</span><br>
  <span class="note">Full API reference and guide.</span>
</a>
<a class="card" href="vi/index.html">
  <span class="lang">Tiếng Việt</span><br>
  <span class="note">Hướng dẫn tiếng Việt. Chú thích trong mã nguồn vẫn là
  tiếng Anh theo quy ước của dự án.</span>
</a>
HTML
    ok "docs/html/index.html (language chooser)"
fi

echo
if [ "${FAILED}" -eq 0 ]; then
    printf '%sDone.%s Open docs/html/index.html\n' "${C_OK}" "${C_0}"
else
    printf '%sFinished with warnings - see above.%s\n' "${C_ERR}" "${C_0}"
fi
exit "${FAILED}"
