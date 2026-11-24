# ESP32-C3 RISC-V Assembly Template

**English** · [Tiếng Việt](README.vi.md)

[![CI](https://github.com/long27032002/esp32c3-riscv-asm/actions/workflows/ci.yml/badge.svg)](https://github.com/long27032002/esp32c3-riscv-asm/actions/workflows/ci.yml)

An ESP-IDF **component** of RISC-V (RV32IMC) assembly routines for the
ESP32-C3, plus the tooling to develop with them: a worked example, a blank
project skeleton, automated environment setup and a VS Code debug
configuration with MEMORY and xRTOS panels.

All source comments follow **Doxygen in English**.

## Quick start

Pick whichever fits what you are doing.

```bash
# 1. Run the worked example, straight from the registry
idf.py create-project-from-example "long27032002/esp32c3_riscv_asm^1.0.0:hello_asm"

# 2. Add the routines to a project you already have
idf.py add-dependency "long27032002/esp32c3_riscv_asm^1.0.0"

# 3. Start something new, from a clone of this repository
git clone https://github.com/long27032002/esp32c3-riscv-asm.git
cd esp32c3-riscv-asm && ./tools/setup.sh
./tools/new-project.sh my_robot
```

Then in your code:

```c
#include "riscv_asm.h"

uint32_t total = asm_sum_loop(55);     /* 1540 */
asm_gpio_output_init(8);
asm_gpio_clear(8);                     /* LED on, active low */
```

## Layout

```
components/esp32c3_riscv_asm/     the component, published to the registry
├── include/riscv_asm.h           public API, documented
├── asm/riscv_asm.S               the assembly
├── idf_component.yml             manifest
└── examples/hello_asm/           complete example project

templates/blank_asm/              skeleton for tools/new-project.sh
tools/                            setup, project creation, docs, recovery
```

The repository root is **not** a project: the component is, and complete
projects live under `examples/` and wherever `new-project.sh` puts them.

---

## What you get

| Component | Contents |
|---|---|
| `components/esp32c3_riscv_asm/` | The component: arithmetic, GPIO through raw registers, CSR reads |
| `components/.../include/riscv_asm.h` | Public API, fully documented |
| `components/.../asm/riscv_asm.S` | Reference assembly: leaf routine, stack-frame routine, peripheral access |
| `components/.../examples/hello_asm/` | Worked example, self-checking, three FreeRTOS tasks |
| `templates/blank_asm/` | Minimal skeleton: one C file, one `.S` file, component wired in |
| `tools/new-project.sh` | Creates a project from the skeleton or any example |
| `tools/setup.sh` | Environment setup for Linux and macOS |
| `tools/setup.bat` + `setup.ps1` | Setup for Windows |
| `tools/recover-jtag.sh` + `.ps1` + `.bat` | Unstick a wedged JTAG |
| `tools/check-release.sh` | Scans for machine paths, serial numbers and keys |
| `tools/build-docs.sh` | Builds the documentation in both languages |
| `Doxyfile` + `Doxyfile.vi` | English and Vietnamese documentation |
| `.gitattributes` | Pins line endings: `.sh` LF, `.bat`/`.ps1` CRLF |

The example program:

1. reads `misa` from assembly to identify the core;
2. computes 1..55 with a **loop** and with the **closed-form formula**, then
   checks itself;
3. measures the **CPU cycles** of both using the performance counter;
4. writes an 8-word table in RAM to inspect in the **MEMORY view**;
5. creates three FreeRTOS tasks to inspect in the **xRTOS view**.

Real output from an ESP32-C3 SuperMini:

```
[1] misa = 0x40101104  -> C I M U   (MXL=1, 1 means RV32)
[2] asm_sum_loop(55)         = 1540
    asm_sum_closed_form(55)  = 1540
    self-check: PASS
[3] cycles: loop = 322, closed form = 16
[4] g_result_table at 0x3fc8bfc0  <- open the MEMORY view here
```

The loop costs **322 cycles**, the formula **16** — more than 20x, a compact
example for talking about algorithmic cost rather than instruction cost.

---

## Setup

### Linux / macOS

```bash
git clone https://github.com/long27032002/esp32c3-riscv-asm.git
cd esp32c3-riscv-asm
./tools/setup.sh                 # configures the bundled example
./tools/setup.sh --project DIR   # or any project of your own
```

### Windows

```bat
git clone https://github.com/long27032002/esp32c3-riscv-asm.git
cd esp32c3-riscv-asm
tools\setup.bat
```

The script:

1. checks for **VS Code** and offers to install it (pacman / apt / dnf / brew /
   winget);
2. looks for **ESP-IDF**; if none is found it offers to clone v5.3.5 and run
   `install.sh`;
3. **asks ESP-IDF itself** where the toolchain, GDB and OpenOCD live;
4. installs four VS Code extensions: ESP-IDF, C/C++, **memory-view** (MEMORY
   tab) and **rtos-views** (xRTOS tab);
5. detects the board's serial port through its **stable by-id path**;
6. generates `.vscode/settings.json`, `launch.json` and `tasks.json`, then
   **validates the JSON**.

Useful flags:

```bash
./tools/setup.sh --check            # report only, change nothing
./tools/setup.sh --no-install       # configure only, never install
./tools/setup.sh --idf-path ~/esp/esp-idf
./tools/setup.sh --port /dev/ttyACM0
./tools/setup.sh --project ~/work/my_robot
./tools/setup.sh --breakpoint app_main
```

### Why the script asks ESP-IDF instead of guessing paths

Several versions of each tool usually coexist under `~/.espressif/tools`.
Picking the newest by directory name is the quickest way to end up with a
toolchain, a GDB and an OpenOCD that do not belong together. The script sources
`export.sh` in a subshell and asks `command -v`, so it always gets the tools of
the ESP-IDF actually in use.

---

## Publishing to the ESP Component Registry

The component is not published yet. Everything needed is in place; these are
the steps.

### 1. Validate first, no account needed

A dry run uploads the archive for checking and publishes nothing. The registry
accepts it anonymously:

```bash
cd components/esp32c3_riscv_asm
compote component pack   --name esp32c3_riscv_asm --version 1.0.0
compote component upload --name esp32c3_riscv_asm --version 1.0.0 --dry-run
# NOTICE: Uploaded archive is valid
```

Or from the **Actions** tab: *Publish to ESP Component Registry* ->
**Run workflow**, leaving "dry run" ticked.

### 2. Create a token

Sign in at [components.espressif.com](https://components.espressif.com) ->
**Profile** -> **Tokens** -> create one with the `write:components` scope.

Your account name becomes the namespace: a component owned by `alice` installs
as `alice/esp32c3_riscv_asm`.

### 3. Store the token

Repository -> **Settings** -> **Secrets and variables** -> **Actions** ->
**New repository secret**, named `IDF_COMPONENT_API_TOKEN`.

### 4. Publish

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow refuses to run if the tag and the `version` in
`idf_component.yml` disagree. **A published version is permanent** — the
registry can yank a version but never reuse its number, so bump the manifest
for every release.

To publish from your own machine instead:

```bash
export IDF_COMPONENT_API_TOKEN=...
cd components/esp32c3_riscv_asm
compote component upload --namespace <your-account> \
                         --name esp32c3_riscv_asm --version 1.0.0
```

Without `--namespace`, compote defaults to `espressif` and the registry
answers *"You do not have upload permissions"*. In CI the namespace defaults
to the GitHub repository owner; set the repository variable
`IDF_COMPONENT_NAMESPACE` if your registry account has a different name.

### If your namespace is not `long27032002`

Three places name it, and they must agree:

| File | What to change |
|---|---|
| `tools/new-project.sh` | `NAMESPACE=` near the top |
| `README.md`, `README.vi.md` | the `idf.py add-dependency` lines |
| `components/.../examples/hello_asm/README.md` | the `create-project-from-example` line |


## Continuous integration (GitHub Actions)

Every push and pull request runs six jobs in parallel. See the **Actions** tab,
or click the badge at the top.

| Job | Runs on | What it checks |
|---|---|---|
| `build` | container `espressif/idf:v5.3.5` | Compiles with `-Werror`; reports size; verifies seven assembly symbols really reached the ELF; uploads `.bin`/`.elf`/`.map` |
| `generate` | ESP-IDF container | Actually runs `setup.sh`, then checks the generated JSON is valid, has **no `@...@` placeholder left**, and is still ignored by git |
| `leaks` | ubuntu | `check-release.sh`: machine paths, board serial numbers, keys |
| `docs` | ubuntu | Doxygen must emit **zero warnings**; uploads the HTML |
| `shell` | ubuntu | `bash -n`, `shellcheck`, and LF line endings |
| `windows` | **windows-latest** | Parses the `.ps1` files with the real PowerShell parser; runs `setup.ps1 -Check` to confirm it fails readably; `.bat` must be CRLF |

### What CI cannot do

GitHub runners have **no ESP32-C3 attached**, so CI can never:

- flash the firmware, run it, or watch the LED
- drive JTAG, read registers, or measure cycle counts
- test the serial port, the BOOT button, or UART/SPI loopback

Those stay manual, on real hardware. CI covers the failures that are *silent*:
code that no longer compiles, a script with a syntax error, documentation that
breaks, or someone committing their own machine's paths.

### Why there is a `windows` job

The development machine runs Linux, so `setup.ps1` and `recover-jtag.ps1` could
not be exercised there. This job runs on a real Windows host and at least
guarantees they **parse** and fail with a readable message instead of a stack
trace. A full run with ESP-IDF and a board still needs a Windows user.

### Running it by hand

**Actions** tab -> pick the **CI** workflow -> **Run workflow**, thanks to
`workflow_dispatch`.

## What never enters the repository

These three exist **only on your machine**; `.gitignore` excludes them. Anyone
who clones gets none of them and regenerates them by running the script or
building:

| Item | Why it is not committed | Created by |
|---|---|---|
| `build/` | Compiler output; embeds absolute paths of the machine that built it | `idf.py build` |
| `sdkconfig` | Expanded from `sdkconfig.defaults`, pins toolchain paths | the first build |
| `.vscode/settings.json`, `launch.json`, `tasks.json` | Absolute paths and the **serial number of one specific board** | `tools/setup.sh` |

Only `sdkconfig.defaults` and `.vscode/extensions.json` are committed. The
latter holds **extension identifiers only**, no paths, so VS Code offers to
install the four required extensions the first time someone opens the folder.

### Why `.vscode/settings.json` must contain absolute paths

There is no alternative. The ESP-IDF extension reads `idf.*` settings
**verbatim**: it does not expand `${env:HOME}` or any other variable, as a
search through the extension source confirms. On top of that, tool directory
names encode versions (`16.3_20250913`, `v0.12.0-esp32-20251215`) that differ
between machines even on the same operating system.

So the answer is not to make the file prettier, but to **regenerate it per
machine**: `setup.sh` writes it, `.gitignore` keeps it out of the repository.

### Checking before you publish

```bash
./tools/check-release.sh
```

It covers five classes: tracked generated files, `/home/...` or `C:\Users\...`
paths, a hardcoded python environment, a board serial number, and credentials
or private keys. `setup.sh` also installs a **`pre-commit` git hook** that runs
it, so one careless `git add -f` is blocked. Bypass once with
`git commit --no-verify`.

## Daily use

```bash
# Open the PROJECT, not the repository root - the root is a component and
# has nothing to debug.
code components/esp32c3_riscv_asm/examples/hello_asm
```

| Action | How |
|---|---|
| Build | `Ctrl+Shift+B` |
| Flash and watch the console | Terminal → Run Task → **flash + monitor** |
| Debug | **F5** (stops at the `sum_loop` label) |
| Generate documentation | Terminal → Run Task → **docs (doxygen, en + vi)** |

Without VS Code:

```bash
. ~/esp/esp-idf/export.sh
idf.py build
idf.py -p "$(ls /dev/serial/by-id/usb-Espressif*)" flash monitor
```

### While debugging

- **Registers** in the Variables panel: `t0`, `t1`, `a0` change at every step
- **Disassembly**: right-click in a `.S` file → *Open Disassembly View*; it has
  an address column
- **F11** steps one machine instruction when the Disassembly view has focus
- **Call Stack** lists every FreeRTOS task by name
- **xRTOS**: task table with priorities and remaining stack
- **MEMORY**: click **+**, enter `&g_result_table` or the address the program
  prints
- **Debug Console**: any GDB command with the `-exec` prefix, for example
  `-exec info threads`

Three debug configurations are provided:

| Configuration | When to use |
|---|---|
| Debug (task starts OpenOCD) | **default**, always works |
| Debug (extension starts OpenOCD) | only after registering ESP-IDF with the extension |
| Debug (OpenOCD already running) | when you start OpenOCD yourself |

---

## Writing a new assembly routine

Copy the skeleton from `asm_template.S`. Every routine needs four things:

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

Then declare it in `asm_api.h` with a matching Doxygen block, and add the `.S`
file to `main/CMakeLists.txt`.

### House rules

- Use psABI register names (`a0`, `t0`, `s0`), not `x10`, `x5`
- Every peripheral address must be a named constant **with the ESP-IDF header
  it came from**
- A routine containing `call` must open a stack frame and save `ra`
- `.global` / `.type` / `.size` around every exported symbol
- **Put data sections at the very end of the file**

That last rule is a real trap: a `.section` directive stays in force until the
next one, so a `.data` block in the middle of a file **swallows every routine
written after it** — the code lands in `.data`, and jumping to it raises an
instruction access fault.

---

## Troubleshooting

### OpenOCD reports "Examination failed" or "Unsupported DTM version: -1"

JTAG is wedged, usually because a debug session was cut off while the target
was halted. **An ordinary reset does not clear it**: `hard_reset` only restarts
the CPU. Use:

Terminal → Run Task → **recover JTAG (watchdog reset)**

or:

```bash
./tools/recover-jtag.sh
```

The script locates the ESP-IDF python and the serial port by itself, with no
environment to source first. Note that the system `python` does **not** have
the `esptool` module, and the python environment directory name
(`idf5.3_py3.14_env`, ...) differs per installation - which is why the script
detects it instead of hardcoding a path.

### "couldn't bind ... port 6666: Address already in use"

A stale OpenOCD is still running. Use the **kill stray OpenOCD** task, or
`pkill -x openocd`.

Note the task uses `pkill -x openocd`, which matches the *process name*. Do not
switch it to `pkill -f <path>`: `-f` matches whole command lines, and the
command line of the shell running the task itself contains the OpenOCD path, so
the task would kill its own shell and die with an empty terminal.

### A `.sh` script reports `env: 'bash\r': No such file or directory`

The file was converted to CRLF line endings, usually by checking it out on
Windows with `core.autocrlf=true` and then copying it to Linux or WSL. The
kernel reads the interpreter name as `bash\r` and cannot find it.

`.gitattributes` pins `.sh` files to LF, so a fresh clone is safe. If a copy
reached you another way, such as a zip or a USB stick:

```bash
sed -i 's/\r$//' tools/*.sh
```

### The serial port name changes after a reset

The board uses native USB, so every reset re-enumerates it and `ttyACM0` can
become `ttyACM1`. The generated configuration uses the stable by-id path keyed
to the board's serial number. If you swap boards, re-run `./tools/setup.sh`.

### The extension reports "OPENOCD_SCRIPTS environment variable is missing"

Only happens with *Debug (extension starts OpenOCD)*. The extension does not
read `OPENOCD_SCRIPTS` directly from settings; it takes it from the environment
computed when you select an ESP-IDF installation inside the extension (stored
in `~/.espressif/esp_idf.json`). Use the default configuration, or register your
installation: `F1` → *ESP-IDF: Configure ESP-IDF extension* → **USE EXISTING
SETUP**.

---

## Hardware

Defaults target the **ESP32-C3 SuperMini** (single USB-C port, built-in
USB-Serial-JTAG, `303a:1001`):

- On-board LED: **GPIO8**, **active low** (write 0 to light it)
- BOOT button: **GPIO9**, active low
- **GPIO18/19 are USB** — reconfiguring them drops the connection
- GPIO0-7 and GPIO10 are free for lab work; the board has **no** LED on them

For another board, change `LED_GPIO` in `main.c`. An external LED wired
pin → 330 Ω → GND is **active high**, so swap `asm_gpio_set` and
`asm_gpio_clear`.

---

## Verification status

Everything below was run on a real ESP32-C3 SuperMini with ESP-IDF v5.3.5,
GDB 16.3 and OpenOCD v0.12.0-esp32:

- `setup.sh` in both `--check` and normal mode; generated JSON validates
- `idf.py build`: **no warnings, no errors**
- Flashed and run: self-check **PASS**, measured 322 / 16 cycles
- `doxygen Doxyfile`: **no warnings**; the `.S` routines appear in the output
- Debugging: OpenOCD starts correctly and opens **only port 3333**, GDB stops at
  `sum_loop`, registers, disassembly and the task list are all readable
- Cloned into a clean directory and set up from scratch, to confirm nothing
  machine-specific is committed

Re-verified on hardware after the restructure: flashed from
`components/esp32c3_riscv_asm/examples/hello_asm`, self-check **PASS**,
322 / 16 cycles, same as before the move.

The registry upload was validated with `compote component upload --dry-run`,
which the registry answered with "Uploaded archive is valid". Nothing has
been published.

**Not verified:** `setup.ps1` and `setup.bat`. The development machine runs
Linux and has no PowerShell to test them. Their logic mirrors `setup.sh`
one-to-one, but the first Windows user should run `tools\setup.bat -Check`
before the real thing.

---

## License

MIT — see [LICENSE](LICENSE).
