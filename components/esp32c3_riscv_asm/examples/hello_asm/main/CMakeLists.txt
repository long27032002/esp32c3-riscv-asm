idf_component_register(
    SRCS "main.c"
         "app_asm.S"
    INCLUDE_DIRS "."
    REQUIRES esp32c3_riscv_asm
)
