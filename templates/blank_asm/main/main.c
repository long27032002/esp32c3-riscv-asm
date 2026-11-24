/**
 * @file    main.c
 * @brief   Entry point for @PROJECT_NAME@.
 *
 * @author  @AUTHOR@
 * @copyright SPDX-License-Identifier: MIT
 */

#include <stdio.h>
#include <inttypes.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "riscv_asm.h"      /* the esp32c3_riscv_asm component */

/** @brief Your own routine, implemented in app_asm.S. */
uint32_t app_asm_func(uint32_t value);

/** @brief Application entry point. */
void app_main(void)
{
    printf("\n@PROJECT_NAME@\n");

    /* From your own assembly. */
    printf("app_asm_func(21)  = %" PRIu32 "\n", app_asm_func(21));

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
