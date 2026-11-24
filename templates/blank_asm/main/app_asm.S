/**
 * @file    app_asm.S
 * @brief   Your assembly routines for @PROJECT_NAME@.
 *
 * House style, copied from the esp32c3_riscv_asm component:
 *   - one Doxygen block per routine, documenting parameters and clobbers;
 *   - .global / .type / .size around every exported symbol;
 *   - psABI register names (a0, t0, s0), not x10, x5;
 *   - peripheral addresses as named constants, with the ESP-IDF header they
 *     came from;
 *   - data sections at the END of the file - a .section directive stays in
 *     force until the next one, so a .data block in the middle silently
 *     swallows every routine written after it.
 *
 * Calling convention (RISC-V psABI, ILP32):
 * @verbatim
 *   a0-a7   arguments, a0 also returns the result
 *   t0-t6   temporaries, free to clobber
 *   s0-s11  saved registers, must be restored before ret
 *   ra      return address
 *   sp      stack pointer, keep 16-byte aligned
 * @endverbatim
 *
 * @author  @AUTHOR@
 * @copyright SPDX-License-Identifier: MIT
 */

    .section .text
    .align  2

/**
 * @fn      uint32_t app_double(uint32_t value)
 * @brief   Return twice its argument. Replace this with your own routine.
 * @param   a0  The value to double.
 * @return  a0  Twice @p value, modulo 2^32.
 * @clobber none.
 */
    .global app_double
    .type   app_double, @function
app_double:
    slli    a0, a0, 1               /* a0 = value << 1 */
    ret
    .size   app_double, . - app_double

/* Data sections go here, at the end of the file. */
