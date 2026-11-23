/**
 * @file    asm_template.S
 * @brief   Reference template for RISC-V (RV32IMC) assembly on the ESP32-C3.
 *
 * Use this file as the starting point for new assembly routines. It shows the
 * house style every routine in this project follows:
 *
 * - one Doxygen block per routine, documenting parameters and clobbers;
 * - `.global` / `.type` / `.size` around every exported symbol, so the symbol
 *   has a correct size in the ELF and the debugger can disassemble it;
 * - register names from the psABI (`a0`, `t0`, `s0`) rather than `x10`, `x5`;
 * - peripheral addresses given as named constants with the header they came
 *   from, never as bare magic numbers.
 *
 * @section regs Calling convention (RISC-V psABI, ILP32)
 * @verbatim
 *   a0-a7   arguments, a0 also returns the result
 *   t0-t6   temporaries, free to clobber
 *   s0-s11  saved registers, must be restored before ret
 *   ra      return address
 *   sp      stack pointer, keep 16-byte aligned
 * @endverbatim
 *
 * @section srcs Where the numbers come from
 * Every address below was taken from the ESP-IDF headers of the version this
 * project builds against, not from memory:
 * - `components/soc/esp32c3/include/soc/reg_base.h`
 * - `components/soc/esp32c3/include/soc/gpio_reg.h`
 * - `components/soc/esp32c3/include/soc/io_mux_reg.h`
 * - `components/soc/esp32c3/include/soc/gpio_sig_map.h`
 *
 * @author  Your Name
 * @date    2026-11-24
 * @copyright SPDX-License-Identifier: MIT
 */

/* ========================================================================== */
/* Peripheral constants                                                       */
/* ========================================================================== */

/** @brief Base of the GPIO peripheral (soc/reg_base.h: DR_REG_GPIO_BASE). */
#define GPIO_BASE               0x60004000
/** @brief Offset of GPIO_OUT_W1TS: write 1 to a bit to drive that pad high. */
#define GPIO_OUT_W1TS_OFF       0x08
/** @brief Offset of GPIO_OUT_W1TC: write 1 to a bit to drive that pad low. */
#define GPIO_OUT_W1TC_OFF       0x0C
/** @brief Offset of GPIO_ENABLE_W1TS: write 1 to enable the output driver. */
#define GPIO_ENABLE_W1TS_OFF    0x24
/** @brief Offset of GPIO_IN: one bit per pad, reads the input level. */
#define GPIO_IN_OFF             0x3C
/** @brief Offset of GPIO_FUNC0_OUT_SEL_CFG; pin n is at +4*n from here. */
#define GPIO_FUNC_OUT_SEL0_OFF  0x554

/** @brief Base of the IO_MUX peripheral (soc/reg_base.h). */
#define IO_MUX_BASE             0x60009000
/** @brief Offset of the IO_MUX register of GPIO0; pin n is at +4*n from here. */
#define IO_MUX_PIN0_OFF         0x04
/** @brief MCU_SEL field is bits [14:12]; value 1 selects the GPIO matrix. */
#define IO_MUX_MCU_SEL_GPIO     (1 << 12)

/** @brief Signal index that means "plain GPIO output" (gpio_sig_map.h). */
#define SIG_GPIO_OUT_IDX        128

/** @brief Performance counter CSRs, specific to the ESP32-C3. */
#define CSR_MPCER               0x7E0   /**< Event select.   */
#define CSR_MPCMR               0x7E1   /**< Mode / enable.  */
#define CSR_MPCCR               0x7E2   /**< Counter value.  */

    .section .text
    .align  2

/* ========================================================================== */
/* Arithmetic                                                                 */
/* ========================================================================== */

/**
 * @fn      uint32_t asm_sum_loop(uint32_t n)
 * @brief   Compute 1 + 2 + ... + n with an explicit loop.
 *
 * @param   a0  n, the upper bound.
 * @return  a0  The sum.
 * @clobber t0 (accumulator), t1 (induction variable).
 *
 * Leaf function: no stack frame, no callee-saved register touched.
 * The label `sum_loop` marks the top of the loop and is a good breakpoint.
 */
    .global asm_sum_loop
    .type   asm_sum_loop, @function
asm_sum_loop:
    li      t0, 0                   /* t0 = accumulator = 0                 */
    li      t1, 1                   /* t1 = i           = 1                 */
sum_loop:                           /* <-- breakpoint here to watch t0, t1  */
    bgtu    t1, a0, sum_done        /* while (i <= n)                       */
    add     t0, t0, t1              /*     acc += i                         */
    addi    t1, t1, 1               /*     i++                              */
    j       sum_loop
sum_done:
    mv      a0, t0                  /* return value goes in a0              */
    ret
    .size   asm_sum_loop, . - asm_sum_loop

/**
 * @fn      uint32_t asm_sum_closed_form(uint32_t n)
 * @brief   Compute 1 + 2 + ... + n as n*(n+1)/2.
 *
 * @param   a0  n, the upper bound.
 * @return  a0  The sum.
 * @clobber t0, t1.
 * @warning The product n*(n+1) overflows 32 bits for n >= 92682.
 */
    .global asm_sum_closed_form
    .type   asm_sum_closed_form, @function
asm_sum_closed_form:
    addi    t0, a0, 1               /* t0 = n + 1                           */
    mul     t1, a0, t0              /* t1 = n * (n + 1)   (M extension)     */
    srli    a0, t1, 1               /* a0 = t1 / 2                          */
    ret
    .size   asm_sum_closed_form, . - asm_sum_closed_form

/**
 * @fn      void asm_fill_table(uint32_t n)
 * @brief   Summarise @p n into ::g_result_table.
 *
 * @param   a0  Value to summarise.
 * @clobber t0-t2, a0.
 *
 * Non-leaf function: it calls other routines, so it must preserve `ra` and
 * any callee-saved register it uses. This is the pattern to copy whenever a
 * routine contains a `call`.
 */
    .global asm_fill_table
    .type   asm_fill_table, @function
asm_fill_table:
    addi    sp, sp, -16             /* open a 16-byte aligned frame         */
    sw      ra, 12(sp)              /* save return address: we will call    */
    sw      s0, 8(sp)               /* save s0: it is callee-saved          */
    mv      s0, a0                  /* keep n across the calls              */

    la      t2, g_result_table
    sw      s0, 0(t2)               /* [0] = n                              */

    mv      a0, s0
    call    asm_sum_loop
    la      t2, g_result_table
    sw      a0, 4(t2)               /* [1] = sum by loop                    */

    mv      a0, s0
    call    asm_sum_closed_form
    la      t2, g_result_table
    sw      a0, 8(t2)               /* [2] = sum by formula                 */

    lw      t0, 12(t2)              /* [3] = call counter                   */
    addi    t0, t0, 1
    sw      t0, 12(t2)

    li      t1, 0xC3C3C3C3          /* [4..7] = recognisable fill pattern   */
    sw      t1, 16(t2)
    sw      t1, 20(t2)
    sw      t1, 24(t2)
    sw      t1, 28(t2)

    lw      s0, 8(sp)               /* restore in reverse order             */
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
    .size   asm_fill_table, . - asm_fill_table

/* ========================================================================== */
/* GPIO                                                                       */
/* ========================================================================== */

/**
 * @fn      void asm_gpio_output_init(uint32_t pin)
 * @brief   Configure one pad as a plain GPIO output.
 *
 * @param   a0  GPIO number.
 * @clobber t0-t2.
 * @warning Do not call with 18 or 19: those pads are USB D-/D+.
 */
    .global asm_gpio_output_init
    .type   asm_gpio_output_init, @function
asm_gpio_output_init:
    slli    t0, a0, 2                           /* byte offset = pin * 4    */
    li      t1, IO_MUX_BASE + IO_MUX_PIN0_OFF
    add     t0, t1, t0
    li      t2, IO_MUX_MCU_SEL_GPIO
    sw      t2, 0(t0)                           /* select the GPIO matrix   */

    slli    t0, a0, 2
    li      t1, GPIO_BASE + GPIO_FUNC_OUT_SEL0_OFF
    add     t0, t1, t0
    li      t2, SIG_GPIO_OUT_IDX
    sw      t2, 0(t0)                           /* route the output signal  */

    li      t0, 1
    sll     t0, t0, a0                          /* mask = 1 << pin          */
    li      t1, GPIO_BASE + GPIO_ENABLE_W1TS_OFF
    sw      t0, 0(t1)                           /* enable the driver        */
    ret
    .size   asm_gpio_output_init, . - asm_gpio_output_init

/**
 * @fn      void asm_gpio_set(uint32_t pin)
 * @brief   Drive a pad high.
 * @param   a0  GPIO number.
 * @clobber t0, t1.
 */
    .global asm_gpio_set
    .type   asm_gpio_set, @function
asm_gpio_set:
    li      t0, 1
    sll     t0, t0, a0
    li      t1, GPIO_BASE + GPIO_OUT_W1TS_OFF
    sw      t0, 0(t1)
    ret
    .size   asm_gpio_set, . - asm_gpio_set

/**
 * @fn      void asm_gpio_clear(uint32_t pin)
 * @brief   Drive a pad low.
 * @param   a0  GPIO number.
 * @clobber t0, t1.
 */
    .global asm_gpio_clear
    .type   asm_gpio_clear, @function
asm_gpio_clear:
    li      t0, 1
    sll     t0, t0, a0
    li      t1, GPIO_BASE + GPIO_OUT_W1TC_OFF
    sw      t0, 0(t1)
    ret
    .size   asm_gpio_clear, . - asm_gpio_clear

/**
 * @fn      uint32_t asm_gpio_read_all(void)
 * @brief   Read the GPIO_IN register.
 * @return  a0  One bit per pad.
 * @clobber t0.
 */
    .global asm_gpio_read_all
    .type   asm_gpio_read_all, @function
asm_gpio_read_all:
    li      t0, GPIO_BASE + GPIO_IN_OFF
    lw      a0, 0(t0)
    ret
    .size   asm_gpio_read_all, . - asm_gpio_read_all

/* ========================================================================== */
/* Control and status registers                                               */
/* ========================================================================== */

/**
 * @fn      uint32_t asm_read_misa(void)
 * @brief   Read the @c misa CSR.
 * @return  a0  Raw value; 0x40101104 on the ESP32-C3 (RV32IMCU).
 */
    .global asm_read_misa
    .type   asm_read_misa, @function
asm_read_misa:
    csrr    a0, misa
    ret
    .size   asm_read_misa, . - asm_read_misa

/**
 * @fn      void asm_perf_counter_start(uint32_t event)
 * @brief   Reset and enable the ESP32-C3 performance counter.
 * @param   a0  Event mask for @c mpcer: bit 0 = cycles, bit 1 = instructions.
 * @clobber t0.
 */
    .global asm_perf_counter_start
    .type   asm_perf_counter_start, @function
asm_perf_counter_start:
    csrw    CSR_MPCER, a0
    li      t0, 1
    csrw    CSR_MPCMR, t0           /* bit 0 enables counting               */
    csrw    CSR_MPCCR, zero         /* reset the counter                    */
    ret
    .size   asm_perf_counter_start, . - asm_perf_counter_start

/**
 * @fn      uint32_t asm_perf_counter_read(void)
 * @brief   Read the performance counter.
 * @return  a0  Current count.
 */
    .global asm_perf_counter_read
    .type   asm_perf_counter_read, @function
asm_perf_counter_read:
    csrr    a0, CSR_MPCCR
    ret
    .size   asm_perf_counter_read, . - asm_perf_counter_read

/* ========================================================================== */
/* Data                                                                       */
/* ========================================================================== */

/*
 * Keep data sections at the very end of the file. A `.section` directive is
 * in force until the next one, so a data block placed in the middle silently
 * swallows every routine written after it - the code ends up in .data or
 * .rodata and jumping to it raises an instruction access fault.
 */
    .section .data
    .align  4
/*
 * Eight words written by asm_fill_table(). The symbol is documented once, in
 * asm_api.h, where C code sees it; repeating a @var block here would make
 * Doxygen merge the .global directive into the symbol name.
 */
    .global g_result_table
g_result_table:
    .word   0, 0, 0, 0, 0, 0, 0, 0
    .size   g_result_table, . - g_result_table
