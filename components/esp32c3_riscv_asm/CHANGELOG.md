# Changelog

All notable changes to this component.
This project follows [Semantic Versioning](https://semver.org/).

## [1.0.2] - 2026-11-24

### Fixed

- 1.0.1 was published seven minutes before the README, LICENSE and changelog
  were merged, so its registry page is as empty as 1.0.0's. This version
  carries them. The release workflow now refuses to publish an archive that
  is missing any of the three, so the ordering cannot bite a third time.

## [1.0.1] - 2026-11-24

### Fixed

- The `hello_asm` example declared only the `idf` dependency, so fetching it
  with `create-project-from-example` produced a project that could not build:
  `Failed to resolve component 'esp32c3_riscv_asm'`. The manifest now declares
  the component itself. Building from a git clone is unaffected: the local
  copy still wins through `EXTRA_COMPONENT_DIRS`.

### Added

- `README.md`, `LICENSE` and this changelog inside the component, so the
  registry page shows them. Version 1.0.0 shipped without any of the three.

## [1.0.0] - 2026-11-24

First release.

- Arithmetic: `asm_sum_loop`, `asm_sum_closed_form`, `asm_fill_table`
- GPIO through the raw registers: `asm_gpio_output_init`, `asm_gpio_set`,
  `asm_gpio_clear`, `asm_gpio_read_all`
- CSRs: `asm_read_misa`, `asm_perf_counter_start`, `asm_perf_counter_read`
- `hello_asm` example: self-checking, measures cycle counts, three FreeRTOS
  tasks for the debugger views
