/**
 * @file    main.c
 * @brief   Entry point: exercises the assembly routines and keeps tasks alive.
 *
 * The C side is deliberately thin. Everything interesting - the arithmetic,
 * the GPIO writes, the CSR reads - happens in `asm_template.S`. C only prints
 * results and provides the FreeRTOS tasks that make the debugger views
 * (Call Stack, xRTOS, MEMORY) worth looking at.
 *
 * @author  Your Name
 * @date    2026-11-24
 * @copyright SPDX-License-Identifier: MIT
 */

#include <stdio.h>
#include <inttypes.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_heap_caps.h"

#include "asm_api.h"

/** @brief On-board LED of the ESP32-C3 SuperMini; active low (0 = lit). */
#define LED_GPIO            8
/** @brief Blink half-period in milliseconds. */
#define LED_PERIOD_MS       500
/** @brief Upper bound used in the summation demos. */
#define SUM_N               55
/** @brief Expected result of sum 1..55, used as a self-check. */
#define SUM_N_EXPECTED      1540

/* ------------------------------------------------------------------------ */
/* Tasks                                                                    */
/* ------------------------------------------------------------------------ */

/**
 * @brief Blink the on-board LED using the raw GPIO registers.
 * @param[in] arg Unused.
 */
static void task_led(void *arg)
{
    (void)arg;
    asm_gpio_output_init(LED_GPIO);

    uint32_t tick = 0U;
    for (;;) {
        asm_gpio_clear(LED_GPIO);   /* active low: clearing lights the LED */
        printf("[led ] %4" PRIu32 " on   (W1TC, bit %d)\n", ++tick, LED_GPIO);
        vTaskDelay(pdMS_TO_TICKS(LED_PERIOD_MS));

        asm_gpio_set(LED_GPIO);
        printf("[led ] %4" PRIu32 " off  (W1TS, bit %d)\n", tick, LED_GPIO);
        vTaskDelay(pdMS_TO_TICKS(LED_PERIOD_MS));
    }
}

/**
 * @brief Recompute the summary table every two seconds.
 *
 * Breakpoints set on ::asm_fill_table or `sum_loop` are hit from this task,
 * which is the easiest way to inspect assembly state once the scheduler is
 * running and several tasks exist.
 *
 * @param[in] arg Unused.
 */
static void task_compute(void *arg)
{
    (void)arg;
    for (;;) {
        asm_fill_table(SUM_N);
        printf("[calc] n=%" PRIu32 " loop=%" PRIu32 " formula=%" PRIu32
               " calls=%" PRIu32 "\n",
               g_result_table[0], g_result_table[1],
               g_result_table[2], g_result_table[3]);
        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

/**
 * @brief Print the FreeRTOS task table and heap usage every five seconds.
 *
 * Requires @c CONFIG_FREERTOS_USE_TRACE_FACILITY and
 * @c CONFIG_FREERTOS_USE_STATS_FORMATTING_FUNCTIONS, both set in
 * `sdkconfig.defaults`.
 *
 * @param[in] arg Unused.
 */
static void task_monitor(void *arg)
{
    (void)arg;
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(5000));

        char table[640];
        vTaskList(table);
        printf("\n[mon ] FreeRTOS tasks\n");
        printf("Name           St  Prio  StackFree  Num\n%s", table);
        printf("  St: R=running B=blocked S=suspended D=deleted\n");
        printf("  StackFree is in words; a small number means near overflow\n");
        printf("  Heap free: %u bytes (largest block %u)\n\n",
               (unsigned)heap_caps_get_free_size(MALLOC_CAP_DEFAULT),
               (unsigned)heap_caps_get_largest_free_block(MALLOC_CAP_DEFAULT));
    }
}

/* ------------------------------------------------------------------------ */
/* Entry point                                                              */
/* ------------------------------------------------------------------------ */

/**
 * @brief Application entry point called by the ESP-IDF startup code.
 *
 * Runs the one-shot demonstrations, then creates the three tasks and
 * returns. The `main` task deletes itself on return; the created tasks keep
 * running.
 */
void app_main(void)
{
    printf("\n\n==============================================\n");
    printf("  RISC-V assembly template for the ESP32-C3\n");
    printf("==============================================\n\n");

    /* --- Identify the core from assembly ------------------------------- */
    const uint32_t misa = asm_read_misa();
    printf("[1] misa = 0x%08" PRIx32 "  ->", misa);
    for (unsigned i = 0U; i < 26U; i++) {
        if ((misa & (1UL << i)) != 0UL) {
            printf(" %c", (char)('A' + (int)i));
        }
    }
    printf("   (MXL=%" PRIu32 ", 1 means RV32)\n\n", misa >> 30);

    /* --- Arithmetic ----------------------------------------------------- */
    const uint32_t by_loop    = asm_sum_loop(SUM_N);
    const uint32_t by_formula = asm_sum_closed_form(SUM_N);
    printf("[2] asm_sum_loop(%d)         = %" PRIu32 "\n", SUM_N, by_loop);
    printf("    asm_sum_closed_form(%d)  = %" PRIu32 "\n", SUM_N, by_formula);
    printf("    self-check: %s\n\n",
           (by_loop == SUM_N_EXPECTED && by_formula == SUM_N_EXPECTED)
               ? "PASS" : "FAIL");

    /* --- Cost of the two algorithms, in CPU cycles ---------------------- */
    asm_perf_counter_start(0x1U);           /* bit 0 selects cycle counting */
    const uint32_t c0 = asm_perf_counter_read();
    (void)asm_sum_loop(SUM_N);
    const uint32_t c1 = asm_perf_counter_read();
    (void)asm_sum_closed_form(SUM_N);
    const uint32_t c2 = asm_perf_counter_read();
    printf("[3] cycles: loop = %" PRIu32 ", closed form = %" PRIu32 "\n\n",
           c1 - c0, c2 - c1);

    /* --- Memory table for the debugger's MEMORY view -------------------- */
    asm_fill_table(SUM_N);
    printf("[4] g_result_table at %p  <- open the MEMORY view here\n",
           (void *)g_result_table);
    for (unsigned i = 0U; i < ASM_RESULT_WORDS; i++) {
        printf("    [%u] = 0x%08" PRIx32 "\n", i, g_result_table[i]);
    }
    printf("\n");

    /* --- Tasks ---------------------------------------------------------- */
    printf("[5] creating tasks: task_led, task_compute, task_monitor\n\n");
    (void)xTaskCreate(task_led,     "task_led",     2560, NULL, 5, NULL);
    (void)xTaskCreate(task_compute, "task_compute", 2560, NULL, 4, NULL);
    (void)xTaskCreate(task_monitor, "task_monitor", 3584, NULL, 3, NULL);
}
