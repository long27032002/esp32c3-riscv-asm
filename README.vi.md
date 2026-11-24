# ESP32-C3 RISC-V Assembly Template

[English](README.md) · **Tiếng Việt**

[![CI](https://github.com/long27032002/esp32c3-riscv-asm/actions/workflows/ci.yml/badge.svg)](https://github.com/long27032002/esp32c3-riscv-asm/actions/workflows/ci.yml)

Một **component** ESP-IDF gồm các hàm hợp ngữ RISC-V (RV32IMC) cho ESP32-C3,
kèm công cụ để phát triển: một example hoàn chỉnh, khung dự án rỗng, script
cài đặt tự động và cấu hình debug VS Code có panel MEMORY và xRTOS.

Mã nguồn chú thích bằng **tiếng Anh theo chuẩn Doxygen**; tài liệu hướng dẫn
bằng tiếng Việt.

## Bắt đầu nhanh

Chọn cách hợp với việc bạn đang làm.

```bash
# 1. Chạy example, tải thẳng từ registry
idf.py create-project-from-example "long27032002/esp32c3_riscv_asm^1.1.0:hello_asm"

# 2. Thêm thư viện vào dự án sẵn có
idf.py add-dependency "long27032002/esp32c3_riscv_asm^1.1.0"

# 3. Bắt đầu dự án mới, từ bản clone repo này
git clone https://github.com/long27032002/esp32c3-riscv-asm.git
cd esp32c3-riscv-asm && ./tools/setup.sh
./tools/new-project.sh my_robot
```

Trong code của bạn:

```c
#include "riscv_asm.h"

uint32_t tong = asm_sum_loop(55);      /* 1540 */
asm_gpio_output_init(8);
asm_gpio_clear(8);                     /* LED sáng, tích cực mức thấp */
```

## Bố cục

```
components/esp32c3_riscv_asm/     component, đem publish lên registry
├── include/riscv_asm.h           API công khai, có tài liệu
├── asm/riscv_asm.S               phần hợp ngữ
├── idf_component.yml             manifest
└── examples/hello_asm/           example hoàn chỉnh

templates/blank_asm/              khung rỗng cho tools/new-project.sh
tools/                            cài đặt, tạo dự án, tài liệu, gỡ kẹt
```

Gốc repo **không phải** là project: gốc là component, còn project hoàn chỉnh
nằm trong `examples/` và nơi `new-project.sh` tạo ra.

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
| `tools/recover-jtag.ps1` + `.bat` | Bản Windows của recover-jtag |
| `tools/check-release.sh` | Quét đường dẫn máy, số serial, khoá — chạy trước khi public |
| `.gitattributes` | Khoá kết thúc dòng: `.sh` luôn LF, `.bat`/`.ps1` luôn CRLF |
| `.vscode/` | Do script sinh ra: build, flash, debug, panel MEMORY và xRTOS |
| `Doxyfile` + `Doxyfile.vi` | Sinh tài liệu HTML hai thứ tiếng, **đọc được cả file `.S`** |
| `tools/build-docs.sh` | Dựng cả hai bản và trang chọn ngôn ngữ |

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
./tools/setup.sh                 # cấu hình cho example có sẵn
./tools/setup.sh --project DIR   # hoặc cho dự án của bạn
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


## CI tự động (GitHub Actions)

Mỗi lần push hoặc mở pull request, GitHub chạy 6 job song song. Xem ở tab
**Actions** của repo, hoặc bấm badge ở đầu trang.

| Job | Chạy trên | Kiểm cái gì |
|---|---|---|
| `build` | container `espressif/idf:v5.3.5` | Biên dịch với `-Werror`; in kích thước; kiểm 7 ký hiệu assembly có thật trong ELF; tải lên `.bin`/`.elf`/`.map` |
| `generate` | container ESP-IDF | Chạy `setup.sh` thật, kiểm JSON sinh ra hợp lệ, **không còn placeholder `@...@`**, và vẫn bị `.gitignore` loại |
| `leaks` | ubuntu | `check-release.sh`: đường dẫn máy, số serial, khoá |
| `docs` | ubuntu | Doxygen phải **0 cảnh báo**; tải lên trang HTML |
| `shell` | ubuntu | `bash -n`, `shellcheck`, và kết thúc dòng phải LF |
| `windows` | **windows-latest** | Parse `.ps1` bằng chính parser PowerShell; chạy `setup.ps1 -Check` xem có báo lỗi tử tế không; `.bat` phải CRLF |

### CI **không** làm được gì

Máy ảo GitHub **không có board ESP32-C3 cắm vào**. Nên CI không thể:

- nạp firmware, chạy thật, xem LED nháy
- debug JTAG, đọc thanh ghi, đo số chu kỳ
- kiểm cổng serial, nút BOOT, loopback UART/SPI

Những thứ đó vẫn phải làm tay trên board thật. CI chỉ bắt loại lỗi *im lặng*:
code không biên dịch nữa, script hỏng cú pháp, tài liệu sinh lỗi, hoặc ai đó
lỡ commit đường dẫn máy mình.

### Vì sao có job `windows`

Máy phát triển chạy Linux nên không thử được `setup.ps1`, `recover-jtag.ps1`.
Job này chạy trên Windows thật, ít nhất bảo đảm chúng **parse được** và thất
bại có thông báo rõ ràng thay vì văng stack trace. Chạy đầy đủ với ESP-IDF và
board thật thì vẫn cần người dùng Windows thử.

### Chạy lại bằng tay

Tab **Actions** → chọn workflow **CI** → **Run workflow** (nhờ
`workflow_dispatch`).

## Những thứ không bao giờ nằm trong repo

Ba thứ sau **chỉ tồn tại trên máy bạn**, `.gitignore` đã loại hẳn. Người clone
về sẽ không có chúng, và tự sinh ra khi chạy script hoặc build:

| Mục | Vì sao không commit | Ai tạo ra |
|---|---|---|
| `build/` | Kết quả biên dịch, nhúng đường dẫn tuyệt đối của máy build | `idf.py build` |
| `sdkconfig` | Cấu hình đã nở ra từ `sdkconfig.defaults`, ghim đường dẫn toolchain | lần build đầu |
| `.vscode/settings.json`, `launch.json`, `tasks.json` | Chứa đường dẫn tuyệt đối và **số serial của một board cụ thể** | `tools/setup.sh` |

Chỉ `sdkconfig.defaults` và `.vscode/extensions.json` được commit — file thứ
hai chỉ chứa **mã định danh extension**, không có đường dẫn nào, nên VS Code sẽ
tự mời cài 4 extension cần thiết khi người ta mở thư mục lần đầu.

### Vì sao `.vscode/settings.json` phải ghi đường dẫn tuyệt đối

Không có cách nào khác. ESP-IDF Extension đọc các giá trị `idf.*` **nguyên
văn** — nó không hiểu `${env:HOME}` hay bất cứ biến nào (đã kiểm chứng bằng
cách tìm trong mã nguồn extension: không có chỗ nào xử lý). Thêm nữa, tên thư
mục công cụ còn mã hoá phiên bản (`16.3_20250913`,
`v0.12.0-esp32-20251215`), khác nhau theo từng máy kể cả khi cùng hệ điều hành.

Nên lời giải không phải là viết cho "đẹp" mà là **sinh lại trên từng máy**:
`setup.sh` tạo file, `.gitignore` chặn không cho commit.

### Tự kiểm tra trước khi công bố

```bash
./tools/check-release.sh
```

Script kiểm 5 nhóm: file sinh ra bị track, đường dẫn `/home/...` hoặc
`C:\Users\...`, python env ghi cứng, số serial của board, và khoá/token.
`setup.sh` cũng cài sẵn **git hook `pre-commit`** gọi script này, nên một lần
`git add -f` lỡ tay sẽ bị chặn ngay. Muốn bỏ qua một lần:
`git commit --no-verify`.

## Dùng hằng ngày

```bash
# Mở PROJECT, không mở gốc repo — gốc là component, không có gì để debug.
code components/esp32c3_riscv_asm/examples/hello_asm
```

| Thao tác | Cách làm |
|---|---|
| Build | `Ctrl+Shift+B` |
| Nạp + xem console | Terminal → Run Task → **flash + monitor** |
| Debug | **F5** (dừng sẵn ở nhãn `sum_loop`) |
| Sinh tài liệu | Terminal → Run Task → **docs (doxygen, en + vi)** |

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

### Script `.sh` báo `env: 'bash\r': No such file or directory`

File bị đổi sang kết thúc dòng CRLF — thường do checkout trên Windows với
`core.autocrlf=true` rồi copy sang Linux/WSL. Nhân hệ điều hành đọc tên trình
thông dịch thành `bash\r` nên không tìm thấy.

`.gitattributes` trong repo đã khoá `.sh` ở LF nên clone mới sẽ không gặp. Nếu
vẫn dính (ví dụ file đến qua đường zip hay USB):

```bash
sed -i 's/\r$//' tools/*.sh
```

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

Đã nạp lại lên board sau khi tái cấu trúc: nạp từ
`components/esp32c3_riscv_asm/examples/hello_asm`, self-check **PASS**,
322 / 16 chu kỳ, y như trước khi chuyển.

Việc tải lên registry đã được kiểm bằng `compote component upload --dry-run`,
registry trả lời "Uploaded archive is valid". Chưa phát hành gì cả.

**Chưa kiểm chứng:** `setup.ps1` và `setup.bat` — máy phát triển chạy Linux,
không có PowerShell để chạy thử. Logic đối chiếu 1-1 với `setup.sh`, nhưng ai
chạy Windows đầu tiên nên dùng `tools\setup.bat -Check` trước.

---

## Giấy phép

MIT. Xem phần `@copyright` trong từng file nguồn.
