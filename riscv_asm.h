/**
 * @file    riscv_asm.h
 * @brief   C-callable interface to the RISC-V assembly routines.
 *
 * Every routine declared here is implemented in assembly (`*.S`) and follows
 * the RISC-V psABI (ILP32) calling convention, so it can be called from C
 * exactly like an ordinary function:
 *
 * | Register   | Role                                                      |
 * | ---------- | --------------------------------------------------------- |
 * | `a0`-`a7`  | Arguments; `a0` also carries the return value             |
 * | `t0`-`t6`  | Temporaries, caller-saved: a callee may clobber them      |
 * | `s0`-`s11` | Saved registers, callee-saved: must be restored on return |
 * | `ra`       | Return address, set by `jal` / `jalr`                     |
 * | `sp`       | Stack pointer, must stay 16-byte aligned                  |
 *
 * @note  Keep this header and the `.S` files in sync. A mismatch in the
 *        number or width of parameters produces no compiler error, only
 *        garbage at run time.
 *
 * @author  Nguyen Nhu Hai Long
 * @date    2026-11-24
 * @copyright SPDX-License-Identifier: MIT
 */

#ifndef ASM_API_H
#define ASM_API_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** @brief Number of 32-bit words in ::g_result_table. */
#define ASM_RESULT_WORDS 8U

/**
 * @brief Scratch table in RAM written by ::asm_fill_table.
 *
 * Declared in assembly, in the `.data` section, so it has a fixed address
 * that is convenient to watch in the debugger's MEMORY view.
 *
 * | Index | Contents                                     |
 * | ----- | -------------------------------------------- |
 * | 0     | `n`, the argument passed to ::asm_fill_table  |
 * | 1     | sum 1..n computed by the loop                 |
 * | 2     | sum 1..n computed by the closed-form formula  |
 * | 3     | number of times ::asm_fill_table was called   |
 * | 4..7  | `0xC3C3C3C3`, an easy-to-spot fill pattern    |
 */
extern uint32_t g_result_table[ASM_RESULT_WORDS];

/* ------------------------------------------------------------------------ */
/* Arithmetic                                                               */
/* ------------------------------------------------------------------------ */

/**
 * @brief Compute 1 + 2 + ... + n with an explicit loop.
 *
 * Implemented as a leaf function: it uses only temporaries, touches no
 * callee-saved register and allocates no stack frame.
 *
 * @param[in] n Upper bound of the summation. @c 0 yields @c 0.
 * @return The sum, modulo 2^32.
 *
 * @note The loop body is labelled `sum_loop`, which makes it a convenient
 *       breakpoint target: `break sum_loop`.
 * @see   asm_sum_closed_form() for the O(1) version.
 */
uint32_t asm_sum_loop(uint32_t n);

/**
 * @brief Compute 1 + 2 + ... + n with the closed-form formula n(n+1)/2.
 *
 * Three instructions instead of a loop; useful next to ::asm_sum_loop to
 * show the cost of an algorithm rather than of an instruction set.
 *
 * @param[in] n Upper bound of the summation.
 * @return The sum, modulo 2^32.
 * @warning Overflows silently for @p n >= 92682 because the intermediate
 *          product @c n*(n+1) exceeds 32 bits.
 */
uint32_t asm_sum_closed_form(uint32_t n);

/**
 * @brief Fill ::g_result_table from assembly.
 *
 * Demonstrates a non-leaf function: it builds a stack frame, saves @c ra and
 * @c s0, calls other assembly routines, then restores and returns.
 *
 * @param[in] n Value to summarise into the table.
 */
void asm_fill_table(uint32_t n);

/* ------------------------------------------------------------------------ */
/* GPIO, driven through the raw peripheral registers                        */
/* ------------------------------------------------------------------------ */

/**
 * @brief Configure one pin as a general-purpose output.
 *
 * Performs the three steps the hardware requires:
 * 1. `IO_MUX[pin].MCU_SEL = 1`, selecting the GPIO matrix for the pad;
 * 2. `GPIO_FUNC<pin>_OUT_SEL = 128` (`SIG_GPIO_OUT_IDX`), routing the plain
 *    output signal to the pad;
 * 3. `GPIO_ENABLE_W1TS = 1 << pin`, enabling the output driver.
 *
 * @param[in] pin GPIO number, 0..21 on the ESP32-C3.
 * @warning Never pass 18 or 19: they carry USB D-/D+ and reconfiguring them
 *          drops the USB connection used for flashing and debugging.
 */
void asm_gpio_output_init(uint32_t pin);

/**
 * @brief Drive a pin high by writing @c GPIO_OUT_W1TS.
 * @param[in] pin GPIO number previously passed to ::asm_gpio_output_init.
 * @note Write-1-to-set is atomic: it changes only the selected bit and needs
 *       no read-modify-write, so it is safe against interrupts.
 */
void asm_gpio_set(uint32_t pin);

/**
 * @brief Drive a pin low by writing @c GPIO_OUT_W1TC.
 * @param[in] pin GPIO number previously passed to ::asm_gpio_output_init.
 */
void asm_gpio_clear(uint32_t pin);

/**
 * @brief Read the whole @c GPIO_IN register.
 * @return Bit @c n reflects the input level of GPIO @c n.
 * @note A pad only reports a level when @c FUN_IE is set in its IO_MUX
 *       register; otherwise the bit always reads 0.
 */
uint32_t asm_gpio_read_all(void);

/* ------------------------------------------------------------------------ */
/* Control and status registers                                             */
/* ------------------------------------------------------------------------ */

/**
 * @brief Read the @c misa CSR, which describes the implemented ISA.
 * @return Raw register value. On the ESP32-C3 this is @c 0x40101104,
 *         i.e. RV32 with the I, M, C and U extensions.
 */
uint32_t asm_read_misa(void);

/**
 * @brief Read the cycle counter of the ESP32-C3 performance counter unit.
 *
 * Call ::asm_perf_counter_start first. The counter is vendor-specific:
 * `mpcer` (0x7E0) selects the event, `mpcmr` (0x7E1) enables counting and
 * `mpccr` (0x7E2) holds the value.
 *
 * @return Current counter value.
 */
uint32_t asm_perf_counter_read(void);

/**
 * @brief Reset and start the performance counter.
 * @param[in] event Event select mask for @c mpcer: bit 0 counts CPU cycles,
 *                  bit 1 counts retired instructions.
 */
void asm_perf_counter_start(uint32_t event);

#ifdef __cplusplus
}
#endif

#endif /* ASM_API_H */
