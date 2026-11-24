# esp32c3_riscv_asm

RISC-V (RV32IMC) assembly routines for the ESP32-C3, written to be read as
well as used: every routine carries a Doxygen block documenting its
parameters, its return value and the registers it clobbers, and every
peripheral address is a named constant with the ESP-IDF header it came from.

Intended for teaching, for research, and as a starting point for firmware
that needs to drop below C.

## Install

```bash
idf.py add-dependency "long27032002/esp32c3_riscv_asm^1.0.1"
```

Or run the worked example without writing anything first:

```bash
idf.py create-project-from-example "long27032002/esp32c3_riscv_asm^1.0.1:hello_asm"
cd hello_asm
idf.py set-target esp32c3
idf.py -p <PORT> flash monitor
```

## Use

```c
#include "riscv_asm.h"

uint32_t total = asm_sum_loop(55);        /* 1540 */

asm_gpio_output_init(8);                  /* on-board LED on a SuperMini */
asm_gpio_clear(8);                        /* active low: clearing lights it */

asm_perf_counter_start(0x1);              /* bit 0 counts CPU cycles */
uint32_t before = asm_perf_counter_read();
```

## What is in it

| Routine | Purpose |
|---|---|
| `asm_sum_loop(n)` | 1 + 2 + … + n with an explicit loop. The label `sum_loop` is a convenient breakpoint |
| `asm_sum_closed_form(n)` | the same with `n(n+1)/2`: three instructions instead of a loop |
| `asm_fill_table(n)` | a non-leaf routine, showing a stack frame and saved registers |
| `asm_gpio_output_init(pin)` | IO_MUX, GPIO matrix and output enable, written directly |
| `asm_gpio_set` / `asm_gpio_clear` | atomic `W1TS` / `W1TC` writes |
| `asm_gpio_read_all()` | the `GPIO_IN` register |
| `asm_read_misa()` | the `misa` CSR; `0x40101104` on this chip, RV32IMCU |
| `asm_perf_counter_start` / `_read` | the ESP32-C3 performance counter, `mpcer` / `mpcmr` / `mpccr` |
| `g_result_table[8]` | a table in RAM at a fixed address, handy in a MEMORY view |

Measured on hardware: `asm_sum_loop(55)` takes **322 cycles**,
`asm_sum_closed_form(55)` takes **16**.

## Target

**ESP32-C3 only.** The peripheral layout and the performance-counter CSRs used
here are specific to it.

`GPIO18` and `GPIO19` carry USB D-/D+ on boards with native USB; passing either
to `asm_gpio_output_init` drops the connection used for flashing and
debugging.

## Writing your own

The component is also a style reference. Copy the shape of a routine from
`asm/riscv_asm.S`:

```asm
/**
 * @fn      uint32_t my_function(uint32_t arg)
 * @brief   One sentence saying what it does.
 * @param   a0  What the argument means.
 * @return  a0  What comes back.
 * @clobber t0, t1.
 */
    .global my_function
    .type   my_function, @function
my_function:
    ...
    ret
    .size   my_function, . - my_function
```

One trap worth knowing: a `.section` directive stays in force until the next
one, so a `.data` block placed in the middle of a file **swallows every
routine written after it** — the code lands in `.data`, and jumping to it
raises an instruction access fault. Keep data at the end.

## The rest of the project

The [GitHub repository](https://github.com/long27032002/esp32c3-riscv-asm)
carries the parts that do not belong in a component archive:

- `tools/setup.sh` and the Windows equivalents: install VS Code extensions,
  find the toolchain by asking ESP-IDF itself, and generate a debug
  configuration with MEMORY and xRTOS panels
- `tools/new-project.sh`: start a project from a blank skeleton or any example
- `tools/recover-jtag.sh`: unstick a wedged debug module without unplugging
- Doxygen documentation in English and Vietnamese

## License

MIT. See [LICENSE](LICENSE).
