# hello_asm

Exercises every routine in the `esp32c3_riscv_asm` component on real hardware.

Fetch it straight from the registry:

```bash
idf.py create-project-from-example "long27032002/esp32c3_riscv_asm^1.1.0:hello_asm"
cd hello_asm
idf.py set-target esp32c3
idf.py -p <PORT> flash monitor
```

Or build it from a clone of the repository, where the local component is used
instead of the published one:

```bash
cd components/esp32c3_riscv_asm/examples/hello_asm
idf.py build
```

## What it does

1. reads `misa` from assembly to identify the core;
2. sums 1..55 with a loop and with the closed-form formula, then checks itself;
3. measures the CPU cycles of both with the performance counter;
4. writes an 8-word table in RAM, for the debugger's MEMORY view;
5. creates three FreeRTOS tasks, for the xRTOS view.

Output on an ESP32-C3 SuperMini:

```
[1] misa = 0x40101104  -> C I M U   (MXL=1, 1 means RV32)
[2] asm_sum_loop(55)         = 1540
    asm_sum_closed_form(55)  = 1540
    self-check: PASS
[3] cycles: loop = 322, closed form = 16
[4] g_result_table at 0x3fc8bfc0  <- open the MEMORY view here
```

The loop costs 322 cycles, the formula 16.

## Hardware

Defaults target the ESP32-C3 SuperMini: on-board LED on **GPIO8, active low**.
Change `LED_GPIO` in `main/main.c` for another board. An external LED wired
pin → 330 Ω → GND is active high, so swap `asm_gpio_set` and `asm_gpio_clear`.
