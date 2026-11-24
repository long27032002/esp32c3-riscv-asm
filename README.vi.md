# esp32c3_riscv_asm

[English](README.md) · **Tiếng Việt**

[![CI](https://github.com/long27032002/esp32c3-riscv-asm/actions/workflows/ci.yml/badge.svg)](https://github.com/long27032002/esp32c3-riscv-asm/actions/workflows/ci.yml)

Các hàm hợp ngữ RISC-V (RV32IMC) cho ESP32-C3, gọi được từ C, kèm công cụ để
phát triển và debug.

Mỗi hàm có chú thích Doxygen, mỗi địa chỉ ngoại vi là hằng có tên kèm tên
header ESP-IDF lấy ra — viết để đọc được chứ không chỉ để dùng.

Chú thích trong mã nguồn bằng tiếng Anh; tài liệu hướng dẫn bằng tiếng Việt.

## Cài đặt

```bash
idf.py add-dependency "long27032002/esp32c3_riscv_asm^1.1.0"
```

```c
#include "riscv_asm.h"

uint32_t tong = asm_sum_loop(55);      /* 1540 */

asm_gpio_output_init(8);
asm_gpio_clear(8);                     /* LED sáng, tích cực mức thấp */
```

| Hàm | Làm gì |
|---|---|
| `asm_sum_loop(n)` | 1 + 2 + … + n bằng vòng lặp; nhãn `sum_loop` tiện đặt breakpoint |
| `asm_sum_closed_form(n)` | cùng kết quả bằng `n(n+1)/2` |
| `asm_fill_table(n)` | ghi `g_result_table`; minh hoạ khung ngăn xếp và thanh ghi phải giữ |
| `asm_gpio_output_init(pin)` | IO_MUX, GPIO matrix và bật output |
| `asm_gpio_set` / `asm_gpio_clear` | ghi `W1TS` / `W1TC`, nguyên tử |
| `asm_gpio_read_all()` | thanh ghi `GPIO_IN` |
| `asm_read_misa()` | CSR `misa` |
| `asm_perf_counter_start` / `_read` | bộ đếm chu kỳ và số lệnh |

Tham chiếu đầy đủ trong [`riscv_asm.h`](components/esp32c3_riscv_asm/riscv_asm.h).

## Chạy thử example

```bash
idf.py create-project-from-example "long27032002/esp32c3_riscv_asm^1.1.0:hello_asm"
cd hello_asm && idf.py set-target esp32c3 && idf.py -p <PORT> flash monitor
```

Example gọi hết các hàm, đo số chu kỳ từng cách, và mang theo `main/app_asm.S`
— assembly của riêng nó để bạn sửa và chạy từng lệnh.

## Phát triển

```bash
git clone https://github.com/long27032002/esp32c3-riscv-asm.git
cd esp32c3-riscv-asm
./tools/setup.sh                    # extension VS Code + cấu hình debug
./tools/new-project.sh my_robot     # tạo dự án của bạn
```

```
components/esp32c3_riscv_asm/   component đưa lên registry
examples/hello_asm/        example hoàn chỉnh, có components/riscv_asm riêng
templates/blank_asm/       khung rỗng cho new-project.sh
tools/                     cài đặt, tạo dự án, tài liệu, gỡ kẹt JTAG
```

Mở thư mục **project** trong VS Code, đừng mở gốc repo — khi đó `F5` dừng ở
`sum_loop`, có sẵn panel MEMORY và xRTOS.

### Không có board

```bash
./tools/qemu.sh              # chạy trên QEMU của Espressif
./tools/qemu.sh --gdb        # và chờ debugger ở cổng 3333
```

Trong VS Code chọn **Debug on QEMU (no board)**. Breakpoint, chạy từng lệnh,
Disassembly và MEMORY hoạt động y như trên phần cứng.

Những gì QEMU không cho biết: LED không sáng và không bao giờ bấm được nút
BOOT, số chu kỳ đếm theo lệnh mô phỏng chứ không theo pipeline thật, và danh
sách task xRTOS rỗng — tính năng đó do OpenOCD cung cấp, còn gdbstub của QEMU
chỉ báo một thread cho mỗi CPU. Console được chuyển sang UART trong
`sdkconfig.qemu`, vì QEMU không mô phỏng USB-Serial-JTAG và cấu hình cho board
sẽ khởi động im lặng.

| Script | Làm gì |
|---|---|
| `tools/setup.sh` | tìm ESP-IDF, cài extension, sinh `.vscode/` (`--project DIR` cho dự án riêng) |
| `tools/new-project.sh` | tạo dự án từ khung rỗng hoặc example (`--list`) |
| `tools/qemu.sh` | chạy hoặc debug trên máy ảo, không cần board |
| `tools/recover-jtag.sh` | watchdog reset khi debug module kẹt |
| `tools/build-docs.sh` | Doxygen, tiếng Anh và tiếng Việt |
| `tools/check-release.sh` | quét đường dẫn máy, số serial board, khoá |

Bản Windows: `tools/setup.bat`, `tools/qemu.bat`, `tools/recover-jtag.bat`.

## Phần cứng

**Chỉ ESP32-C3.** `GPIO18` và `GPIO19` là USB D-/D+ trên board dùng USB tích
hợp; chạm vào là mất kết nối nạp và debug.

Mặc định theo ESP32-C3 SuperMini: LED trên board ở **GPIO8, tích cực mức
thấp**, nút BOOT ở **GPIO9**.

## Khi gặp sự cố

| Triệu chứng | Cách gỡ |
|---|---|
| `Examination failed`, `Unsupported DTM version: -1` | `./tools/recover-jtag.sh` — reset thường không đủ |
| `couldn't bind … port 6666` | còn OpenOCD cũ: `pkill -x openocd` |
| QEMU khởi động rồi im lặng | console đang ở USB-Serial-JTAG; dùng `tools/qemu.sh`, nó nạp thêm `sdkconfig.qemu` |
| QEMU: `libslirp.so.0: cannot open shared object file` | cài `libslirp` (Debian: `libslirp0`) |
| `env: 'bash\r': No such file` | kết thúc dòng CRLF: `sed -i 's/\r$//' tools/*.sh` |
| cổng serial đổi tên sau reset | USB tích hợp nối lại; cấu hình sinh ra dùng đường dẫn `by-id` cố định |
| extension báo `OPENOCD_SCRIPTS … missing` | dùng cấu hình debug mặc định, hoặc đăng ký ESP-IDF với extension |

`build/`, `sdkconfig` và `.vscode/*.json` sinh ra **cố ý không commit**: chúng
chứa đường dẫn tuyệt đối và số serial của một board cụ thể. Mỗi người tự sinh
lại bằng `tools/setup.sh`.

## Giấy phép

MIT, xem [LICENSE](LICENSE).
