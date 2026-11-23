# ESP32-C3 RISC-V Assembly Template

[English](README.en.md) · **Tiếng Việt**

Bộ khung để **học, nghiên cứu và phát triển** chương trình hợp ngữ RISC-V
(RV32IMC) trên ESP32-C3, kèm script cài đặt tự động và môi trường debug đầy đủ
trong VS Code.

Mã nguồn chú thích bằng **tiếng Anh theo chuẩn Doxygen**; tài liệu hướng dẫn
bằng tiếng Việt.

---

## Có sẵn những gì

| Thành phần | Nội dung |
|---|---|
| `main/asm_template.S` | Khung mẫu hợp ngữ: hàm lá, hàm có ngăn xếp, GPIO qua thanh ghi thô, đọc CSR |
| `main/asm_api.h` | Khai báo C cho mọi hàm assembly, tài liệu Doxygen đầy đủ |
| `main/main.c` | Gọi thử, tự kiểm tra kết quả, tạo 3 task FreeRTOS |
| `tools/setup.sh` | Cài đặt và cấu hình tự động cho Linux / macOS |
| `tools/setup.bat` + `setup.ps1` | Bản tương ứng cho Windows |
| `tools/recover-jtag.sh` | Gỡ JTAG bị kẹt, tự dò python ESP-IDF và cổng serial |
| `.vscode/` | Do script sinh ra: build, flash, debug, panel MEMORY và xRTOS |
| `Doxyfile` | Sinh tài liệu HTML từ chú thích, **đọc được cả file `.S`** |

Chương trình mẫu khi chạy sẽ:

1. đọc `misa` bằng assembly để nhận dạng lõi;
2. tính tổng 1..55 bằng **vòng lặp** và bằng **công thức Gauss**, tự kiểm tra;
3. đo **số chu kỳ CPU** của hai cách bằng bộ đếm hiệu năng;
4. ghi một bảng 8 word trong RAM để xem bằng **MEMORY view**;
5. tạo 3 task FreeRTOS để xem bằng **xRTOS view**.

Kết quả thật trên board ESP32-C3 SuperMini:

```
[1] misa = 0x40101104  -> C I M U   (MXL=1, 1 means RV32)
[2] asm_sum_loop(55)         = 1540
    asm_sum_closed_form(55)  = 1540
    self-check: PASS
[3] cycles: loop = 322, closed form = 16
[4] g_result_table at 0x3fc8bfc0  <- open the MEMORY view here
```

Vòng lặp tốn **322 chu kỳ**, công thức tốn **16** — hơn 20 lần, một ví dụ gọn
để nói về chi phí thuật toán.

---

## Cài đặt

### Linux / macOS

```bash
git clone https://github.com/long27032002/esp32c3-riscv-asm.git
cd esp32c3-riscv-asm
./tools/setup.sh
```

### Windows

```bat
git clone https://github.com/long27032002/esp32c3-riscv-asm.git
cd esp32c3-riscv-asm
tools\setup.bat
```

Script sẽ lần lượt:

1. kiểm tra **VS Code**, mời cài nếu chưa có (pacman / apt / dnf / brew /
   winget);
2. tìm **ESP-IDF**; nếu không có thì mời clone bản v5.3.5 và chạy `install.sh`;
3. **hỏi chính ESP-IDF** xem toolchain, GDB và OpenOCD nằm ở đâu;
4. cài 4 extension VS Code: ESP-IDF, C/C++, **memory-view** (tab MEMORY),
   **rtos-views** (tab xRTOS);
5. dò cổng serial của board theo **đường dẫn by-id cố định**;
6. sinh `.vscode/settings.json`, `launch.json`, `tasks.json` rồi **kiểm tra
   JSON hợp lệ**.

Tham số hữu ích:

```bash
./tools/setup.sh --check            # chỉ báo cáo, không sửa gì
./tools/setup.sh --no-install       # chỉ cấu hình, không cài đặt
./tools/setup.sh --idf-path ~/esp/esp-idf
./tools/setup.sh --port /dev/ttyACM0
```

### Vì sao script hỏi ESP-IDF thay vì tự dò đường dẫn

Dưới `~/.espressif/tools` thường có **nhiều phiên bản** của mỗi công cụ. Chọn
bản mới nhất theo tên thư mục là cách nhanh nhất để lệch phiên bản giữa
toolchain, GDB và OpenOCD. Script nạp `export.sh` trong một shell con rồi hỏi
`command -v`, nên luôn lấy đúng bộ công cụ của chính bản ESP-IDF đang dùng.

---

## Những thứ không bao giờ nằm trong repo

Ba thứ sau **chỉ tồn tại trên máy bạn**, `.gitignore` đã loại hẳn. Người clone
về sẽ không có chúng, và tự sinh ra khi chạy script hoặc build:

| Mục | Vì sao không commit | Ai tạo ra |
|---|---|---|
| `build/` | Kết quả biên dịch, nhúng đường dẫn tuyệt đối của máy build | `idf.py build` |
| `sdkconfig` | Cấu hình đã nở ra từ `sdkconfig.defaults`, ghim đường dẫn toolchain | lần build đầu |
| `.vscode/settings.json`, `launch.json`, `tasks.json` | Chứa đường dẫn tuyệt đối và **số serial của một board cụ thể** | `tools/setup.sh` |

Chỉ `sdkconfig.defaults` được commit — đó mới là file nguồn.

Muốn tự kiểm tra trước khi đẩy lên:

```bash
git ls-files                     # đúng những file sẽ công khai
git grep -n "/home/\|C:\\Users"   # không được ra kết quả nào
```

## Dùng hằng ngày

```bash
code .          # mở ĐÚNG thư mục này, không mở thư mục cha
```

| Thao tác | Cách làm |
|---|---|
| Build | `Ctrl+Shift+B` |
| Nạp + xem console | Terminal → Run Task → **flash + monitor** |
| Debug | **F5** (dừng sẵn ở nhãn `sum_loop`) |
| Sinh tài liệu | Terminal → Run Task → **docs (doxygen)** |

Không dùng VS Code:

```bash
. ~/esp/esp-idf/export.sh
idf.py build
idf.py -p "$(ls /dev/serial/by-id/usb-Espressif*)" flash monitor
```

### Khi debug

- **Registers** trong panel Variables: `t0`, `t1`, `a0` đổi sau mỗi bước
- **Disassembly**: chuột phải trong `.S` → *Open Disassembly View*, có cột địa chỉ
- **F11** chạy từng lệnh máy khi cửa sổ Disassembly đang được chọn
- **Call Stack** liệt kê từng task FreeRTOS theo tên
- **xRTOS**: bảng task, mức ưu tiên, ngăn xếp còn lại
- **MEMORY**: bấm **+**, nhập `&g_result_table` hoặc địa chỉ chương trình in ra
- **Debug Console**: gõ lệnh GDB với tiền tố `-exec`, ví dụ `-exec info threads`

Có 3 cấu hình debug trong `launch.json`:

| Cấu hình | Khi nào dùng |
|---|---|
| Debug (task starts OpenOCD) | **mặc định**, luôn chạy được |
| Debug (extension starts OpenOCD) | chỉ sau khi đăng ký ESP-IDF với extension |
| Debug (OpenOCD already running) | khi bạn tự chạy OpenOCD ở terminal riêng |

---

## Viết hàm assembly mới

Chép khung trong `asm_template.S`. Mỗi hàm cần đủ bốn thứ:

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

Rồi khai báo trong `asm_api.h` với khối Doxygen tương ứng, và thêm file `.S`
vào `main/CMakeLists.txt`.

### Quy ước của dự án

- Dùng tên thanh ghi theo psABI (`a0`, `t0`, `s0`), không dùng `x10`, `x5`
- Mọi địa chỉ ngoại vi phải là hằng có tên, **kèm tên header ESP-IDF** lấy ra
- Hàm có `call` phải mở khung ngăn xếp và cất `ra`
- `.global` / `.type` / `.size` quanh mọi ký hiệu xuất
- **Đặt các section dữ liệu ở cuối file**

Điểm cuối cùng là một cái bẫy thật: chỉ thị `.section` có hiệu lực cho tới chỉ
thị kế tiếp, nên một khối `.data` đặt giữa file sẽ **nuốt mọi hàm viết sau nó**
— code rơi vào `.data`, nhảy vào đó sinh lỗi *instruction access fault*.

---

## Gặp sự cố

### OpenOCD báo "Examination failed" hoặc "Unsupported DTM version: -1"

JTAG bị kẹt, thường do một phiên debug bị cắt ngang khi target đang halt.
**Reset thường không gỡ được** — `hard_reset` chỉ reset CPU. Dùng:

Terminal → Run Task → **recover JTAG (watchdog reset)**

hoặc:

```bash
./tools/recover-jtag.sh
```

Script tự tìm python của ESP-IDF và cổng serial, không cần nạp môi trường
trước. Lưu ý `python` của hệ thống **không có** module `esptool`, và tên thư
mục python env (`idf5.3_py3.14_env`...) khác nhau theo từng máy — đó là lý do
script phải dò chứ không ghi cứng đường dẫn.

### "couldn't bind ... port 6666: Address already in use"

Còn một OpenOCD cũ. Task **kill stray OpenOCD**, hoặc `pkill -x openocd`.

Lưu ý task dùng `pkill -x openocd`, khớp theo **tên tiến trình**. Đừng đổi sang
`pkill -f <đường_dẫn>`: `-f` khớp cả dòng lệnh, mà dòng lệnh của chính shell
đang chạy task cũng chứa đường dẫn OpenOCD, nên task sẽ tự giết shell của mình
và chết ngay với terminal trống.

### Cổng serial đổi tên sau khi reset

Board dùng USB tích hợp nên mỗi lần reset nó rời rồi nối lại USB; `ttyACM0` có
thể thành `ttyACM1`. Cấu hình đã dùng đường dẫn by-id cố định theo số serial.
Nếu đổi board, chạy lại `./tools/setup.sh`.

### Extension báo "OPENOCD_SCRIPTS environment variable is missing"

Chỉ xảy ra với cấu hình *Debug (extension starts OpenOCD)*. Extension không đọc
`OPENOCD_SCRIPTS` thẳng từ settings; nó lấy từ môi trường tính sẵn khi bạn chọn
một bản ESP-IDF trong extension (lưu ở `~/.espressif/esp_idf.json`). Dùng cấu
hình mặc định, hoặc đăng ký bản ESP-IDF: `F1` → *ESP-IDF: Configure ESP-IDF
extension* → **USE EXISTING SETUP**.

---

## Phần cứng

Mặc định cho **ESP32-C3 SuperMini** (chỉ một cổng USB-C, USB-Serial-JTAG tích
hợp, `303a:1001`):

- LED trên board: **GPIO8**, **tích cực mức thấp** (ghi 0 = sáng)
- Nút BOOT: **GPIO9**, tích cực mức thấp
- **GPIO18/19 là USB** — cấu hình lại sẽ mất kết nối
- GPIO0–7, 10 rảnh cho bài lab; board **không có sẵn** LED ở các chân này

Board khác: sửa `LED_GPIO` trong `main.c`. Nếu LED ngoài mắc chân → 330 Ω →
GND thì nó **tích cực mức cao**, cần đổi `asm_gpio_set` và `asm_gpio_clear`
cho nhau.

---

## Đã kiểm chứng

Toàn bộ nội dung dưới đây đã chạy thật trên board ESP32-C3 SuperMini với
ESP-IDF v5.3.5, GDB 16.3, OpenOCD v0.12.0-esp32:

- `setup.sh` ở cả chế độ `--check` và chạy thật, JSON sinh ra đều hợp lệ
- `idf.py build`: **0 cảnh báo, 0 lỗi**
- Nạp và chạy: tự kiểm tra **PASS**, đo được 322 / 16 chu kỳ
- `doxygen Doxyfile`: **0 cảnh báo**, tài liệu có đủ hàm trong `.S`
- Debug: OpenOCD lên đúng, **chỉ mở cổng 3333**, GDB dừng đúng `sum_loop`,
  đọc được thanh ghi, disassembly và danh sách task

**Chưa kiểm chứng:** `setup.ps1` và `setup.bat` — máy phát triển chạy Linux,
không có PowerShell để chạy thử. Logic đối chiếu 1-1 với `setup.sh`, nhưng ai
chạy Windows đầu tiên nên dùng `tools\setup.bat -Check` trước.

---

## Giấy phép

MIT. Xem phần `@copyright` trong từng file nguồn.
