# esp32c3_riscv_asm

RISC-V (RV32IMC) assembly routines for the ESP32-C3, callable from C.

Every routine is documented with Doxygen, and every peripheral address is a
named constant carrying the ESP-IDF header it came from — the component is
meant to be read as much as used.

## Install

```bash
idf.py add-dependency "long27032002/esp32c3_riscv_asm^1.1.0"
```

## Use

```c
#include "riscv_asm.h"

uint32_t total = asm_sum_loop(55);     /* 1540 */

asm_gpio_output_init(8);
asm_gpio_clear(8);                     /* LED on, active low */
```

| Routine | Does |
|---|---|
| `asm_sum_loop(n)` | 1 + 2 + … + n with a loop; the label `sum_loop` is a good breakpoint |
| `asm_sum_closed_form(n)` | the same with `n(n+1)/2` |
| `asm_fill_table(n)` | writes `g_result_table`; shows a stack frame and saved registers |
| `asm_gpio_output_init(pin)` | IO_MUX, GPIO matrix and output enable |
| `asm_gpio_set` / `asm_gpio_clear` | atomic `W1TS` / `W1TC` writes |
| `asm_gpio_read_all()` | the `GPIO_IN` register |
| `asm_read_misa()` | the `misa` CSR |
| `asm_perf_counter_start` / `_read` | cycle and instruction counters |

Full reference: [`riscv_asm.h`](riscv_asm.h).

## Example

```bash
idf.py create-project-from-example "long27032002/esp32c3_riscv_asm^1.1.0:hello_asm"
```

It exercises the routines, measures how many cycles each costs, and includes
`main/app_asm.S` — assembly of its own to edit and step through.

## Target

**ESP32-C3 only.** `GPIO18` and `GPIO19` are USB D-/D+ on boards with native
USB; driving them drops the connection used for flashing and debugging.

## More

Setup scripts, a project generator and the debug configuration live in the
[GitHub repository](https://github.com/long27032002/esp32c3-riscv-asm).

MIT, see [LICENSE](LICENSE).
