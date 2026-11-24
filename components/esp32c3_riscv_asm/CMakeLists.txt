# Component build file for esp32c3_riscv_asm.
#
# The repository root is an ESP-IDF COMPONENT, not a project. That is what
# lets other projects pull it in with:
#
#     idf.py add-dependency "<namespace>/esp32c3_riscv_asm^1.0.0"
#
# Complete, buildable projects live under examples/.
#
# ".S" (capital S) runs the assembler through the C preprocessor first, so
# #define and #include work inside the assembly sources.
idf_component_register(
    SRCS        "asm/riscv_asm.S"
    INCLUDE_DIRS "include"
)
