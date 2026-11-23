# ".S" (capital S) means the file is run through the C preprocessor first,
# so #define / #include work inside assembly.
idf_component_register(
    SRCS "main.c"
         "asm_template.S"
    INCLUDE_DIRS "."
)
