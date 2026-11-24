# Component build file for esp32c3_riscv_asm.
#
# The repository root is the component, which is the layout the ESP Component
# Registry expects and what idf.py add-dependency pulls in.
#
# ".S" (capital S) runs the assembler through the C preprocessor first, so
# #define and #include work inside the assembly source.
idf_component_register(
    SRCS         "riscv_asm.S"
    INCLUDE_DIRS "."
)
