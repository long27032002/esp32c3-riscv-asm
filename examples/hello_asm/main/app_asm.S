/**
 * @file    app_asm.S
 * @brief   Assembly belonging to this example, separate from the component.
 *
 * The component provides general routines; this file is where you experiment.
 * Edit it, rebuild, single-step it in the debugger. Nothing here is needed by
 * the component, so breaking it only breaks the example.
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
 * @author  Nguyen Nhu Hai Long
 * @copyright SPDX-License-Identifier: MIT
 */

    .section .text
    .align  2

/**
 * @fn      uint32_t app_count_ones(uint32_t value)
 * @brief   Count the set bits of @p value.
 *
 * @param   a0  The value to examine.
 * @return  a0  How many of its 32 bits are 1.
 * @clobber t0, t1, t2.
 *
 * A shift-and-test loop: the plainest way to write it, and short enough to
 * follow instruction by instruction in the Disassembly view.
 */
    .global app_count_ones
    .type   app_count_ones, @function
app_count_ones:
    li      t0, 0                   /* t0 = count                           */
    li      t2, 32                  /* t2 = bits left to look at            */
count_loop:                         /* <-- breakpoint here                  */
    beqz    t2, count_done
    andi    t1, a0, 1               /* t1 = lowest bit                      */
    add     t0, t0, t1              /* count += it                          */
    srli    a0, a0, 1               /* shift the next bit down              */
    addi    t2, t2, -1
    j       count_loop
count_done:
    mv      a0, t0
    ret
    .size   app_count_ones, . - app_count_ones

/**
 * @fn      uint32_t app_reverse_bytes(uint32_t value)
 * @brief   Swap the byte order of @p value, turning little-endian into big.
 *
 * @param   a0  The value to reverse.
 * @return  a0  The same bytes in the opposite order.
 * @clobber t0, t1, t2.
 */
    .global app_reverse_bytes
    .type   app_reverse_bytes, @function
app_reverse_bytes:
    andi    t0, a0, 0xFF            /* byte 0 */
    slli    t0, t0, 24
    srli    t1, a0, 8
    andi    t1, t1, 0xFF            /* byte 1 */
    slli    t1, t1, 16
    or      t0, t0, t1
    srli    t1, a0, 16
    andi    t1, t1, 0xFF            /* byte 2 */
    slli    t1, t1, 8
    or      t0, t0, t1
    srli    t1, a0, 24
    andi    t1, t1, 0xFF            /* byte 3 */
    or      a0, t0, t1
    ret
    .size   app_reverse_bytes, . - app_reverse_bytes
