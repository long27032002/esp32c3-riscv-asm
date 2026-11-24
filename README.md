# esp32c3_riscv_asm

**English** · [Tiếng Việt](README.vi.md)

[![CI](https://github.com/long27032002/esp32c3-riscv-asm/actions/workflows/ci.yml/badge.svg)](https://github.com/long27032002/esp32c3-riscv-asm/actions/workflows/ci.yml)

RISC-V (RV32IMC) assembly routines for the ESP32-C3, callable from C, with the
tooling to develop and debug them.

Every routine is documented with Doxygen, and every peripheral address is a
named constant carrying the ESP-IDF header it came from — this is meant to be
read as much as used.

## Install

```bash
idf.py add-dependency "long27032002/esp32c3_riscv_asm^1.1.0"
```

```c
#include "riscv_asm.h"

uint32_t total = asm_sum_loop(55);     /* 1540 */

asm_gpio_output_init(8);
asm_gpio_clear(8);                     /* LED on, active low */
```

| Routine | Does |
|---|---|
| `asm_sum_loop(n)` | 1 + 2 + … + n with a loop; `sum_loop` is a good breakpoint |
| `asm_sum_closed_form(n)` | the same with `n(n+1)/2` |
| `asm_fill_table(n)` | writes `g_result_table`; shows a stack frame and saved registers |
| `asm_gpio_output_init(pin)` | IO_MUX, GPIO matrix and output enable |
| `asm_gpio_set` / `asm_gpio_clear` | atomic `W1TS` / `W1TC` writes |
| `asm_gpio_read_all()` | the `GPIO_IN` register |
| `asm_read_misa()` | the `misa` CSR |
| `asm_perf_counter_start` / `_read` | cycle and instruction counters |

Full reference in [`riscv_asm.h`](components/esp32c3_riscv_asm/riscv_asm.h).

## Try the example

```bash
idf.py create-project-from-example "long27032002/esp32c3_riscv_asm^1.1.0:hello_asm"
cd hello_asm && idf.py set-target esp32c3 && idf.py -p <PORT> flash monitor
```

It exercises the routines, measures how many cycles each costs, and carries
`main/app_asm.S` — assembly of its own to edit and single-step.

## Develop with it

```bash
git clone https://github.com/long27032002/esp32c3-riscv-asm.git
cd esp32c3-riscv-asm
./tools/setup.sh                    # VS Code extensions + debug configuration
./tools/new-project.sh my_robot     # a project of your own
```

```
components/esp32c3_riscv_asm/   the component published to the registry
examples/hello_asm/        complete example, with its own components/riscv_asm
templates/blank_asm/       skeleton that new-project.sh copies
tools/                     setup, project generator, docs, JTAG recovery
```

Open a **project** folder in VS Code, not the repository root — `F5` then
stops at `sum_loop`, with the MEMORY and xRTOS panels wired up.

### Without a board

```bash
./tools/qemu.sh              # run on Espressif's QEMU
./tools/qemu.sh --gdb        # and wait for a debugger on port 3333
```

In VS Code pick **Debug on QEMU (no board)**. Breakpoints, stepping,
Disassembly and MEMORY all behave as on hardware.

What the emulator will not tell you: no LED lights up and the BOOT button can
never be pressed, cycle counts come from emulated instructions rather than the
real pipeline, and the xRTOS task list stays empty — task awareness comes from
OpenOCD, and QEMU's gdbstub reports one thread per CPU. The console is moved
to UART in `sdkconfig.qemu`, because QEMU does not emulate USB-Serial-JTAG and
the board configuration boots silent.

| Script | Does |
|---|---|
| `tools/setup.sh` | finds ESP-IDF, installs extensions, writes `.vscode/` (`--project DIR` for your own) |
| `tools/new-project.sh` | new project from the skeleton or an example (`--list`) |
| `tools/qemu.sh` | run or debug on the emulator, no board needed |
| `tools/recover-jtag.sh` | watchdog reset when the debug module wedges |
| `tools/build-docs.sh` | Doxygen, English and Vietnamese |
| `tools/check-release.sh` | scans for machine paths, board serials, keys |

Windows equivalents: `tools/setup.bat`, `tools/recover-jtag.bat`.

## Target

**ESP32-C3 only.** `GPIO18` and `GPIO19` are USB D-/D+ on boards with native
USB; driving them drops the connection used for flashing and debugging.

Defaults assume an ESP32-C3 SuperMini: on-board LED on **GPIO8, active low**,
BOOT button on **GPIO9**.

## When something breaks

| Symptom | Fix |
|---|---|
| `Examination failed`, `Unsupported DTM version: -1` | `./tools/recover-jtag.sh` — a plain reset is not enough |
| `couldn't bind … port 6666` | a stale OpenOCD: `pkill -x openocd` |
| QEMU boots then goes silent | the console is on USB-Serial-JTAG; use `tools/qemu.sh`, which layers `sdkconfig.qemu` |
| QEMU: `libslirp.so.0: cannot open shared object file` | install `libslirp` (`libslirp0` on Debian) |
| `env: 'bash\r': No such file` | CRLF line endings: `sed -i 's/\r$//' tools/*.sh` |
| serial port renamed after a reset | native USB re-enumerates; the generated config uses the stable `by-id` path |
| extension reports `OPENOCD_SCRIPTS … missing` | use the default debug configuration, or register ESP-IDF with the extension |

`build/`, `sdkconfig` and the generated `.vscode/*.json` are deliberately not
committed: they hold absolute paths and one board's serial number. Each user
regenerates them with `tools/setup.sh`.

## License

MIT, see [LICENSE](LICENSE).
