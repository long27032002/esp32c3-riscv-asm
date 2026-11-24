#!/usr/bin/env bash
#
# new-project.sh - start a new ESP32-C3 assembly project.
#
# Two sources to copy from:
#
#   blank      templates/blank_asm, a minimal skeleton: one C file, one .S
#              file, the component wired in and nothing else to delete
#
#   <example>  any directory under examples/,
#              copied complete and ready to build
#
# The new project depends on the esp32c3_riscv_asm component. By default the
# assembly is copied into the project as components/esp32c3_riscv_asm, so it
# builds with no registry account and the sources are there to edit; pass
# --from-registry to depend on the published component instead.
#
# Copying rather than pointing at the checkout with override_path keeps the
# new project movable: it still builds after the checkout is deleted.
#
# Usage:
#     ./tools/new-project.sh my_robot
#     ./tools/new-project.sh my_robot --from hello_asm
#     ./tools/new-project.sh my_robot --dir ~/work --author "Your Name"
#     ./tools/new-project.sh --list
#
set -o errexit
set -o nounset
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPONENT_DIR="${REPO_ROOT}/components/esp32c3_riscv_asm"
EXAMPLES_DIR="${REPO_ROOT}/examples"
TEMPLATES_DIR="${REPO_ROOT}/templates"

# Namespace used when depending on the published component. Must match the
# account the component is published under on components.espressif.com.
NAMESPACE="long27032002"

NAME=""
FROM="blank"
DEST_DIR="$(pwd)"
AUTHOR="${USER:-Your Name}"
FROM_REGISTRY=0

if [ -t 1 ]; then
    C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_B=$'\033[1m'
    C_DIM=$'\033[2m'; C_0=$'\033[0m'
else
    C_OK=""; C_ERR=""; C_B=""; C_DIM=""; C_0=""
fi
ok()   { printf '  %s[ ok ]%s %s\n' "${C_OK}" "${C_0}" "$*"; }
info() { printf '  %s%s%s\n' "${C_DIM}" "$*" "${C_0}"; }
die()  { printf '%s[fail]%s %s\n' "${C_ERR}" "${C_0}" "$*" >&2; exit 1; }

list_sources() {
    printf '%sAvailable sources%s\n' "${C_B}" "${C_0}"
    printf '  blank        minimal skeleton (templates/blank_asm)\n'
    for d in "${EXAMPLES_DIR}"/*/; do
        [ -d "${d}" ] || continue
        local n brief
        n="$(basename "${d}")"
        brief=""
        [ -f "${d}/README.md" ] && brief="$(sed -n '3p' "${d}/README.md" | cut -c1-48)"
        printf '  %-12s %s\n' "${n}" "${brief}"
    done
}

while [ $# -gt 0 ]; do
    case "$1" in
        --list)          list_sources; exit 0 ;;
        --from)          FROM="${2:-}"; shift ;;
        --dir)           DEST_DIR="${2:-}"; shift ;;
        --author)        AUTHOR="${2:-}"; shift ;;
        --from-registry) FROM_REGISTRY=1 ;;
        -h|--help)       sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        -*)              die "unknown option: $1" ;;
        *)               [ -z "${NAME}" ] && NAME="$1" || die "unexpected argument: $1" ;;
    esac
    shift
done

[ -n "${NAME}" ] || { list_sources; echo; die "give the new project a name"; }

# A CMake project name and a C identifier both have to survive this.
[[ "${NAME}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] \
    || die "'${NAME}' is not usable as a project name: letters, digits and underscores only, not starting with a digit"

if [ "${FROM}" = "blank" ]; then
    SRC="${TEMPLATES_DIR}/blank_asm"
else
    SRC="${EXAMPLES_DIR}/${FROM}"
    [ -d "${SRC}" ] || { list_sources; echo; die "no such example: ${FROM}"; }
fi

TARGET="${DEST_DIR%/}/${NAME}"
[ -e "${TARGET}" ] && die "${TARGET} already exists"

printf '%sCreating %s%s\n' "${C_B}" "${TARGET}" "${C_0}"
info "from: ${SRC#"${REPO_ROOT}"/}"

mkdir -p "${TARGET}"
# Copy the sources only. An example that has been built locally carries a
# build directory and a lock file that belong to this machine.
( cd "${SRC}" && tar --exclude=build --exclude=managed_components \
                    --exclude=dependencies.lock --exclude=sdkconfig \
                    --exclude=sdkconfig.old -cf - . ) | ( cd "${TARGET}" && tar -xf - )

# Substitute the placeholders the blank template carries. Examples have no
# placeholders, so this is a no-op for them.
find "${TARGET}" -type f \( -name '*.c' -o -name '*.h' -o -name '*.S' \
                            -o -name '*.txt' -o -name '*.yml' -o -name '*.md' \) \
    -exec sed -i \
        -e "s|@PROJECT_NAME@|${NAME}|g" \
        -e "s|@AUTHOR@|${AUTHOR}|g" \
        -e "s|@NAMESPACE@|${NAMESPACE}|g" {} +

# Point the dependency at the local checkout unless asked otherwise, so a new
# project builds before anything has been published.
MANIFEST="${TARGET}/main/idf_component.yml"
if [ -f "${MANIFEST}" ]; then
    if [ "${FROM_REGISTRY}" -eq 1 ]; then
        ok "dependency: ${NAMESPACE}/esp32c3_riscv_asm from the registry"
    else
        # Copied under the name the registry publishes, so "REQUIRES
        # esp32c3_riscv_asm" in main/CMakeLists.txt resolves either way and
        # switching to the published component changes only this manifest.
        LOCAL_COMPONENT="${TARGET}/components/esp32c3_riscv_asm"
        mkdir -p "${LOCAL_COMPONENT}"
        cp "${COMPONENT_DIR}/riscv_asm.S" \
           "${COMPONENT_DIR}/riscv_asm.h" "${LOCAL_COMPONENT}/"
        cat > "${LOCAL_COMPONENT}/CMakeLists.txt" <<'EOF'
idf_component_register(
    SRCS         "riscv_asm.S"
    INCLUDE_DIRS "."
)
EOF
        cat > "${MANIFEST}" <<EOF
## The assembly lives in components/esp32c3_riscv_asm inside this project, so
## nothing has to be downloaded and the sources are yours to edit. To follow
## the published component instead, delete that directory and add:
##   ${NAMESPACE}/esp32c3_riscv_asm:
##     version: "^1.1.0"
dependencies:
  idf:
    version: ">=5.0"
EOF
        ok "component copied to components/esp32c3_riscv_asm"
    fi
fi

ok "${TARGET}"

cat <<EOF

  Next:

      cd "${TARGET}"
      . "\${IDF_PATH:-\$HOME/esp/esp-idf}/export.sh"
      idf.py set-target esp32c3
      idf.py build

  For VS Code debugging, generate the configuration for the new project:

      ${REPO_ROOT}/tools/setup.sh --project "${TARGET}"
EOF
