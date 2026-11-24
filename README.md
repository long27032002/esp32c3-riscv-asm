# esp32c3_riscv_asm

**English** · [Tiếng Việt](README.vi.md)

[![CI](https://github.com/long27032002/esp32c3-riscv-asm/actions/workflows/ci.yml/badge.svg)](https://github.com/long27032002/esp32c3-riscv-asm/actions/workflows/ci.yml)

RISC-V (RV32IMC) assembly routines for the ESP32-C3, callable from C, together
with the tooling to build, run, debug and document them.

This is written to be **read** as much as used. Every routine carries a Doxygen
block stating what it clobbers and what it returns; every peripheral address is
a named constant that names the ESP-IDF header it came from; every non-obvious
workaround in the scripts explains the failure it prevents. If you are learning
RISC-V assembly on real hardware, the comments are the point.

**Contents**

1. [What you need](#what-you-need)
2. [Quick start](#quick-start)
3. [The assembly API](#the-assembly-api)
4. [Repository layout](#repository-layout)
5. [Build, flash, monitor](#build-flash-monitor)
6. [Debugging in VS Code](#debugging-in-vs-code)
7. [Debugging from a terminal](#debugging-from-a-terminal)
8. [Running without a board: QEMU](#running-without-a-board-qemu)
9. [Starting your own project](#starting-your-own-project)
10. [Tool reference](#tool-reference)
11. [Documentation](#documentation)
12. [Troubleshooting](#troubleshooting)
13. [Continuous integration](#continuous-integration)
14. [License](#license)

---

## What you need

**Hardware.** An ESP32-C3 board and one USB-C cable. Nothing else — the chip has
a built-in USB-Serial-JTAG bridge, so flashing, the serial console and the
debugger all travel over that one cable. No external probe.

The defaults assume an **ESP32-C3 SuperMini**: on-board LED on **GPIO8, active
low** (write 0 to light it), BOOT button on **GPIO9**. On a different board,
change the pin number in `main.c`; nothing else is board-specific.

> **ESP32-C3 only.** The register addresses and the custom performance-counter
> CSRs used here are specific to this chip. And do not drive **GPIO18/GPIO19**:
> they are USB D−/D+ on boards with native USB, so touching them drops the very
> connection you are flashing and debugging over.

**Software.** ESP-IDF **v5.0 or newer** (developed and tested on v5.3.5). If you
do not have it yet:

```bash
git clone -b v5.3.5 --recursive https://github.com/espressif/esp-idf.git ~/esp/esp-idf
~/esp/esp-idf/install.sh esp32c3
```

Optional: VS Code with the ESP-IDF extension (`tools/setup.sh` installs it),
Doxygen and Graphviz for the API documentation, and Espressif's QEMU if you want
to run without a board.

---

## Quick start

Two ways in, depending on whether you want to *use* these routines or *work on*
them.

### A. Add the component to a project of your own

```bash
idf.py add-dependency "long27032002/esp32c3_riscv_asm^1.1.0"
```

```c
#include "riscv_asm.h"

void app_main(void)
{
    uint32_t total = asm_sum_loop(55);          /* 1540 */

    asm_gpio_output_init(8);
    asm_gpio_clear(8);                          /* LED on — active low */

    printf("misa = 0x%08lx\n", asm_read_misa());
}
```

### B. Clone the repository and work inside it

```bash
git clone https://github.com/long27032002/esp32c3-riscv-asm.git
cd esp32c3-riscv-asm
./tools/setup.sh                    # finds ESP-IDF, installs the VS Code
                                    # extensions, writes .vscode/ for the example
cd examples/hello_asm
idf.py set-target esp32c3
idf.py -p /dev/ttyACM0 flash monitor
```

`tools/setup.sh` detects the serial port itself; the command above spells it out
only to show the shape. On Windows use `tools\setup.bat`.

The example prints the ISA string decoded from `misa`, computes 1+2+…+55 two
different ways and compares them, measures how many cycles each way costs, fills
a table in RAM so there is something to watch in the MEMORY view, exercises its
own assembly in `main/app_asm.S`, and then starts three FreeRTOS tasks — one
blinking the LED, one computing, one reporting the task list.

---

## The assembly API

Full reference, with clobber lists and register-level notes:
[`components/esp32c3_riscv_asm/riscv_asm.h`](components/esp32c3_riscv_asm/riscv_asm.h).

### Arithmetic

| Routine | Purpose |
|---|---|
| `uint32_t asm_sum_loop(uint32_t n)` | 1 + 2 + … + n with an explicit loop. The label `sum_loop` sits on the loop body and is the natural place for a breakpoint. |
| `uint32_t asm_sum_closed_form(uint32_t n)` | The same result from `n(n+1)/2` — one multiply instead of n iterations. Compare the cycle counts. |
| `void asm_fill_table(uint32_t n)` | Writes `g_result_table[]`. Allocates a real stack frame and saves the registers the ABI requires, so it shows what a non-leaf function has to do. |

`extern uint32_t g_result_table[ASM_RESULT_WORDS]` is a scratch array in RAM.
The example prints its address; paste that into the MEMORY view to watch the
writes land.

### GPIO

| Routine | Purpose |
|---|---|
| `void asm_gpio_output_init(uint32_t pin)` | Routes the pin through IO_MUX and the GPIO matrix, then enables the output driver. |
| `void asm_gpio_set(uint32_t pin)` | Drives the pin high via `GPIO_OUT_W1TS`. |
| `void asm_gpio_clear(uint32_t pin)` | Drives the pin low via `GPIO_OUT_W1TC`. |
| `uint32_t asm_gpio_read_all(void)` | Returns the whole `GPIO_IN` register; bit *n* is the level of GPIO *n*. |

`W1TS`/`W1TC` are write-one-to-set and write-one-to-clear registers: each write
touches only the bits you name, so there is no read-modify-write and no race
with an interrupt that changes a different pin.

### Introspection

| Routine | Purpose |
|---|---|
| `uint32_t asm_read_misa(void)` | Reads the `misa` CSR, which encodes the implemented ISA extensions. |
| `void asm_perf_counter_start(uint32_t event)` | Resets and starts the performance counter. Bit 0 of `event` counts CPU cycles, bit 1 counts retired instructions. |
| `uint32_t asm_perf_counter_read(void)` | Reads the counter. |

### Calling convention

The routines follow the standard RISC-V ILP32 ABI, so they are ordinary C
functions as far as the compiler is concerned:

- arguments in `a0`–`a7`, return value in `a0`;
- `t0`–`t6` and `a0`–`a7` are caller-saved — free to clobber;
- `s0`–`s11`, `sp` and `ra` are callee-saved — save and restore them if you use
  them;
- the stack stays 16-byte aligned.

Each routine's `@clobber` line states exactly which registers it touches, so you
can check the code against its own contract while single-stepping.

---

## Repository layout

```
components/esp32c3_riscv_asm/   the component published to the registry
    riscv_asm.S                 the routines
    riscv_asm.h                 the C interface, fully documented
    CMakeLists.txt
    idf_component.yml           manifest; points at ../../examples
    README.md  LICENSE          what the registry page shows

examples/hello_asm/             complete, runnable example
    main/main.c                 calls everything and prints the results
    main/app_asm.S              assembly belonging to the example — yours to edit
    components/riscv_asm/       its own copy, so it builds with nothing downloaded
    sdkconfig.defaults          board build
    sdkconfig.qemu              overlay for the emulator

templates/blank_asm/            minimal skeleton that new-project.sh copies
tools/                          setup, project generator, QEMU, docs, JTAG recovery
.github/workflows/              CI and registry publishing
```

Two things look like duplication and are not:

**`examples/hello_asm/components/riscv_asm/`** is a copy of the component. It is
what makes the example self-contained: it builds identically from a git clone
and from `idf.py create-project-from-example`, with nothing resolved from the
registry. It is deliberately **not** named `riscv` — ESP-IDF ships a built-in
component by that name, and the collision fails the build with
`fatal error: riscv/rv_utils.h: No such file or directory`.

**`build/`, `sdkconfig` and the generated `.vscode/*.json` are not committed.**
They contain absolute paths and one board's serial number, which would be wrong
on every other machine. Each user regenerates them with `tools/setup.sh`.

---

## Build, flash, monitor

```bash
cd examples/hello_asm
idf.py set-target esp32c3          # once per project
idf.py build
idf.py -p <PORT> flash monitor     # Ctrl-] to leave the monitor
```

`<PORT>` is `/dev/ttyACM0`-ish on Linux, `/dev/cu.usbmodem*` on macOS, `COM*` on
Windows. The configuration generated by `tools/setup.sh` uses the stable
`/dev/serial/by-id/...` path instead, because native USB re-enumerates after a
reset and a bare `ttyACM` number can move.

Useful extras:

```bash
idf.py size                                              # flash and RAM usage
idf.py monitor                                           # console only
riscv32-esp-elf-objdump -d build/hello_asm.elf | less    # full disassembly
riscv32-esp-elf-nm build/hello_asm.elf | grep asm_       # check symbols exist
```

---

## Debugging in VS Code

```bash
./tools/setup.sh                             # the bundled example
./tools/setup.sh --project ~/work/my_robot   # a project of your own
```

The script locates ESP-IDF, OpenOCD, the toolchain gdb and the serial port,
installs the VS Code extensions, and writes `.vscode/settings.json`,
`launch.json` and `tasks.json` with absolute paths filled in.

> Open the **project** folder in VS Code (`examples/hello_asm`), not the
> repository root. VS Code resolves `${workspaceFolder}` against the folder you
> opened, and every path in the generated configuration is relative to the
> project.

Press **F5**. The `openocd` task starts first, the debugger attaches, and
execution stops at `sum_loop` — inside the assembly, not at `app_main`.

### What each view gives you

| View | What you get |
|---|---|
| **Disassembly** (right-click a line → *Open Disassembly View*) | The actual instructions with their addresses, interleaved with the source. `Ctrl+F5` steps one *instruction*; `F10`/`F11` step one source line. |
| **Variables → Registers** | All 32 general-purpose registers plus `pc`, live and editable. |
| **Debug Console** | A full gdb prompt: `info registers`, `p/x $mcause`, `x/16xw $sp`, `set $a0 = 99`, `info all-registers`. |
| **MEMORY** | Raw memory. Paste the `g_result_table` address the example prints and watch `asm_fill_table` write into it. |
| **xRTOS** | The FreeRTOS task list with each task's state and stack. Needs `CONFIG_FREERTOS_USE_TRACE_FACILITY`, which `sdkconfig.defaults` already sets. |
| **Call Stack** | Frames across the C/assembly boundary — `asm_sum_loop` → `app_main` → `main_task`. |

Breakpoints work directly in `.S` files: click the gutter next to any label.

### The debug configurations

| Configuration | When to use it |
|---|---|
| **Debug (task starts OpenOCD)** | The default. A VS Code task starts OpenOCD with absolute paths, so it works whether or not the extension has a registered ESP-IDF installation. |
| **Debug on QEMU (no board)** | No hardware attached. See [QEMU](#running-without-a-board-qemu). |
| **Debug (extension starts OpenOCD)** | Lets the ESP-IDF extension manage OpenOCD. Requires the extension to know an ESP-IDF installation; otherwise it reports `OPENOCD_SCRIPTS … missing`. |
| **Debug (OpenOCD already running)** | You started OpenOCD yourself in a terminal. |

### Tasks

**Terminal → Run Task**: `build`, `flash + monitor`, `qemu (run)`,
`qemu (gdb server)`, `recover JTAG (watchdog reset)`, `kill stray OpenOCD`,
`docs (doxygen, en + vi)`.

---

## Debugging from a terminal

Two windows. First:

```bash
openocd -f board/esp32c3-builtin.cfg
```

Second:

```bash
cd examples/hello_asm
riscv32-esp-elf-gdb build/hello_asm.elf \
    -ex "target extended-remote :3333" \
    -ex "monitor reset halt" \
    -ex "break sum_loop" \
    -ex "continue"
```

Commands worth knowing once you are stopped inside assembly:

```
info registers          all general-purpose registers and pc
p/x $misa               one CSR in hex
x/8i $pc                the next eight instructions
x/16xw $sp              the top of the stack
stepi / si              one instruction
layout asm              a split source/assembly window
info threads            FreeRTOS tasks (OpenOCD provides this; QEMU does not)
```

OpenOCD listens on **3333** (gdb), 4444 (telnet) and 6666 (tcl). The generated
task disables the two it does not need, because a stale process otherwise
reports the clash on port 6666, which points nowhere near the cause.

---

## Running without a board: QEMU

Espressif maintains a QEMU fork that models the ESP32-C3. Install it once:

```bash
python "$IDF_PATH/tools/idf_tools.py" install qemu-riscv32
```

On Linux it also needs libslirp, which most distributions do not install by
default — `sudo pacman -S libslirp` on Arch, `sudo apt install libslirp0` on
Debian and Ubuntu, `brew install libslirp` on macOS.

```bash
./tools/qemu.sh                     # run; Ctrl-A X quits
./tools/qemu.sh --gdb               # hold at the reset vector, listen on 3333
./tools/qemu.sh --attach            # the debugger half, in a second terminal
```

In VS Code, pick **Debug on QEMU (no board)** and press F5.

### What works, and what the emulator cannot tell you

Breakpoints, single-stepping, the Disassembly view, all 32 general-purpose
registers plus `pc` in **Variables → Registers**, writing to registers, and the
MEMORY view all behave as they do over JTAG.

What does not carry over:

- **No electrical world.** `asm_gpio_set`/`asm_gpio_clear` write their registers
  and `asm_gpio_read_all` reads them back, but no LED lights up and the BOOT
  button can never be pressed.
- **Timing is not the chip's.** The performance counters advance with emulated
  instructions, not with real pipeline behaviour. Flash timing is not modelled.
- **No xRTOS task list.** Task awareness comes from OpenOCD's `-rtos` support;
  QEMU's gdb stub reports one thread per emulated CPU instead.
- **No CSRs by name.** QEMU advertises far more CSRs than it will serve, and
  the Registers pane asks for every register in a single request, so one
  refusal — the first is `htimedelta`, a hypervisor CSR — empties the pane.
  The QEMU configuration therefore hands gdb a restricted target description
  (`tools/templates/riscv-qemu.xml`), which costs the CSR names: `p/x $misa`
  answers `void`. Read them from the program instead — `asm_read_misa()` does
  exactly that — or debug on the board, where OpenOCD advertises only
  registers it serves and both the pane and the CSR names work. To make the
  opposite trade, delete the `set tdesc filename` line from
  `.vscode/launch.json`.
- **`misa` differs.** QEMU reports `0x401411ad`; the header documents the chip's
  `0x40101104`. If you are studying which extensions the silicon really has, use
  the board.

### How it is wired, in case you need to change it

The build goes into **`build-qemu/` with its own `sdkconfig`**. That is not
tidiness: the example runs its console over USB-Serial-JTAG, which QEMU does not
emulate, so a board build boots to **complete silence** after the bootloader —
indistinguishable from an early crash. `sdkconfig.qemu` moves the console to
UART0. An existing `sdkconfig` overrides `SDKCONFIG_DEFAULTS`, so the overlay
only takes effect because the build is pointed at a separate config file; that
also keeps the emulator from overwriting the board's configuration. The separate
directory additionally avoids a full rebuild every time you alternate between
the two.

### Does QEMU conflict with a board that is plugged in?

**One real conflict: port 3333.** `idf.py qemu --gdb` hardcodes `-gdb tcp::3333`
and QEMU honours the first `-gdb` on its command line, so the port cannot be
changed from outside. That is also OpenOCD's gdb port, so **you cannot debug the
board and the emulator at the same time**. Both directions handle it: `--gdb`
stops a running OpenOCD first, and the `openocd` task stops a running QEMU.

Otherwise they do not interfere. QEMU never opens the serial port, so
`idf.py flash monitor` on the board keeps working alongside it, and QEMU never
writes to the board — it does not invoke esptool and does not touch JTAG. The
build directories and configurations are separate, so neither clobbers the
other.

> **Do not flash `build-qemu/*.bin` to a real board.** Its console is on UART0
> (GPIO20/21), so the board would boot and say nothing over USB — exactly the
> silent-crash symptom described above. Flash from `build/`.

---

## Starting your own project

```bash
./tools/new-project.sh my_robot                   # from the blank skeleton
./tools/new-project.sh my_robot --from hello_asm  # from an example
./tools/new-project.sh --list                     # what you can copy
```

The new project gets its own copy of the component under
`components/esp32c3_riscv_asm/`, so it builds with nothing downloaded and the
assembly is right there to edit. Pass `--from-registry` to depend on the
published component instead.

```bash
cd my_robot
idf.py set-target esp32c3 && idf.py build
~/esp32c3-riscv-asm/tools/setup.sh --project "$PWD"   # then F5 in VS Code
```

Or start from the registry, which needs no clone at all:

```bash
idf.py create-project-from-example "long27032002/esp32c3_riscv_asm^1.1.0:hello_asm"
```

### Writing your own routine

`main/app_asm.S`, in both the skeleton and the example, is yours. The shape to
follow:

```asm
/**
 * @fn      uint32_t app_double(uint32_t value)
 * @brief   Return @p value times two.
 *
 * @param   a0  The value.
 * @return  a0  Twice the value.
 * @clobber none.
 */
    .section .text
    .align   2
    .global  app_double
    .type    app_double, @function
app_double:
    slli    a0, a0, 1
    ret
    .size   app_double, . - app_double
```

Declare it in a header (`uint32_t app_double(uint32_t);`), add the `.S` file to
`SRCS` in `main/CMakeLists.txt`, and call it from C. The `.global`, `.type` and
`.size` directives are what put the symbol in the ELF with the right size, so
gdb and the Disassembly view can find it.

---

## Tool reference

Every script accepts `--help` and refuses to guess: if ESP-IDF or the board is
missing it says so, with the command that fixes it.

| Script | What it does | Options |
|---|---|---|
| `tools/setup.sh` | Finds ESP-IDF, installs the VS Code extensions, generates `.vscode/` | `--check`, `--no-install`, `--idf-path DIR`, `--port DEV`, `--project DIR`, `--breakpoint SYM` |
| `tools/new-project.sh` | New project from the skeleton or an example | `--list`, `--from NAME`, `--dir DIR`, `--author NAME`, `--from-registry` |
| `tools/qemu.sh` | Run or debug on the emulator | `--gdb`, `--attach`, `--project DIR`, `--no-build`, `--no-monitor` |
| `tools/recover-jtag.sh` | Watchdog reset for a wedged debug module | `--port DEV`, `--idf-path DIR` |
| `tools/build-docs.sh` | Doxygen, English and Vietnamese, fails on any warning | — |
| `tools/check-release.sh` | Scans for machine paths, board serials, keys, committed build output | — |

Windows equivalents: `tools\setup.bat`, `tools\qemu.bat`,
`tools\recover-jtag.bat` (and the `.ps1` scripts behind them, which take
PowerShell-style switches: `-Gdb`, `-Project`, `-NoBuild`).

---

## Documentation

```bash
./tools/build-docs.sh        # → docs/html/index.html
```

Two complete sets are produced from the same sources: English in
`docs/html/en/`, Vietnamese in `docs/html/vi/`, with a language chooser at
`docs/html/index.html`. Source comments are written in English; the Vietnamese
build translates Doxygen's own navigation.

Graphviz is optional — call graphs are enabled when `dot` is available and
skipped when it is not. The script fails on **any** Doxygen warning, because a
missing `@param` is how reference documentation rots.

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `Examination failed`, `Unsupported DTM version: -1`, `Timed out … waiting for busy to go low` | The debug module is wedged, usually after a session was cut off while the target was halted. A plain reset is not enough — it restarts the CPU and leaves the debug module stuck. Run `./tools/recover-jtag.sh`, which sends a watchdog reset and restarts the whole digital core. |
| `couldn't bind to socket on port 6666` | A stale OpenOCD. `pkill -x openocd`. The clash is reported on 6666 even though the port that matters is 3333. |
| QEMU: `Failed to bind socket`, or the debugger cannot connect | OpenOCD or an older QEMU holds 3333. `pkill -x openocd; pkill -f '[q]emu-system-riscv32'`. Note that `pkill -x qemu-system-riscv32` silently matches nothing: `/proc/PID/comm` truncates the name to 15 characters. |
| QEMU boots, prints the bootloader, then nothing | The console is on USB-Serial-JTAG, which QEMU does not emulate. Use `tools/qemu.sh`, which layers `sdkconfig.qemu`. |
| QEMU: `libslirp.so.0: cannot open shared object file` | Install libslirp (`libslirp0` on Debian and Ubuntu). |
| `"monitor" command not supported by this target.` | A board configuration ran with no OpenOCD: the connection failed, and the post-connect commands then ran on a session that never connected. Usually it means the **repository root** is open in VS Code rather than a project folder — an old `.vscode/launch.json` there offers board configurations for an ELF that no longer exists. Open `examples/hello_asm`; `tools/setup.sh` deletes the stale root files. |
| The Registers pane shows only `Could not fetch register "h…"` | QEMU advertises CSRs it will not serve, and one refusal fails the whole request. Regenerate with `tools/setup.sh`, which points gdb at a restricted target description. |
| QEMU debug console shows `unknown command: 'reset'` | Harmless. The extension prefixes `monitor reset halt`; QEMU's gdb stub has no such command, and the connection is already up. Nothing needs resetting — QEMU holds the CPU at the reset vector until a debugger attaches. |
| `A program is being debugged already` / `could not connect: Connection timed out` | Something connected twice. `initCommands` are sent *after* the adapter has connected, so a `target remote` there — or in `connectCommands` — connects a second time. Regenerate with `tools/setup.sh`. |
| The serial port changed name after a reset | Native USB re-enumerates. The generated configuration uses the stable `/dev/serial/by-id/...` path; pass `--port` to override. |
| The extension reports `OPENOCD_SCRIPTS environment variable is missing` | You picked *Debug (extension starts OpenOCD)* without registering an ESP-IDF installation. Use the default configuration, or F1 → *ESP-IDF: Configure ESP-IDF extension* → **USE EXISTING SETUP**. |
| `env: 'bash\r': No such file or directory` | The shell scripts were checked out with CRLF endings. `sed -i 's/\r$//' tools/*.sh`, and check that `.gitattributes` survived. |
| `fatal error: riscv/rv_utils.h: No such file or directory` | A component directory of yours is named `riscv`, colliding with ESP-IDF's built-in component. Rename it. |
| The LED does not blink but the console looks fine | Wrong pin or wrong polarity for your board. The default is GPIO8, active low. |

---

## Continuous integration

Every push and pull request runs eight jobs:

| Job | What it proves |
|---|---|
| **build** | Every example compiles with warnings as errors, a project generated from the skeleton compiles too, and the expected symbols are really in the ELF. |
| **qemu** | The firmware *runs*: the sums come out right, the example's own assembly returns the expected values, both tasks start, and nothing panicked. |
| **generate** | `setup.sh` still produces valid JSON with no placeholder left, and the generated files stay out of git. |
| **component** | The component packs for the registry, with README and LICENSE inside the archive and no build output. |
| **leaks** | No machine path, board serial number or key is committed. |
| **docs** | Doxygen builds both languages with zero warnings, with and without Graphviz. |
| **shell** | `bash -n` and shellcheck pass; line endings are LF. |
| **windows** | The PowerShell scripts parse on a real Windows host and fail cleanly without ESP-IDF; the batch files are CRLF. |

What CI cannot do: flash a board, drive JTAG, blink the LED or measure real
cycle counts. Those stay manual.

---

## License

MIT — see [LICENSE](LICENSE). Contributions are welcome; CI must be green and
`tools/check-release.sh` must stay clean.
