# Local copy of the esp32c3_riscv_asm component, so this example builds from
# a git clone without fetching anything from the registry.
#
# A project fetched with create-project-from-example does not carry this
# directory; there the dependency in main/idf_component.yml is resolved from
# the registry instead.
idf_component_register(
    SRCS         "riscv_asm.S"
    INCLUDE_DIRS "."
)
