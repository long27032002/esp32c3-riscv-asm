# esp32c3_riscv_asm

[English](README.md) · **Tiếng Việt**

[![CI](https://github.com/long27032002/esp32c3-riscv-asm/actions/workflows/ci.yml/badge.svg)](https://github.com/long27032002/esp32c3-riscv-asm/actions/workflows/ci.yml)

Các hàm hợp ngữ RISC-V (RV32IMC) cho ESP32-C3, gọi được từ C, kèm toàn bộ công
cụ để biên dịch, chạy, debug và sinh tài liệu.

Dự án này viết ra để **đọc** chứ không chỉ để dùng. Mỗi hàm có khối Doxygen nói
rõ nó phá những thanh ghi nào và trả về gì; mỗi địa chỉ ngoại vi là một hằng có
tên, kèm tên header ESP-IDF lấy ra; mỗi chỗ xử lý khác thường trong script đều
giải thích nó đang phòng lỗi gì. Nếu bạn đang học hợp ngữ RISC-V trên phần cứng
thật, phần chú thích chính là nội dung chính.

Chú thích trong mã nguồn viết bằng tiếng Anh; tài liệu hướng dẫn có cả tiếng
Việt.

**Mục lục**

1. [Cần những gì](#cần-những-gì)
2. [Bắt đầu nhanh](#bắt-đầu-nhanh)
3. [Giao diện hàm hợp ngữ](#giao-diện-hàm-hợp-ngữ)
4. [Cấu trúc thư mục](#cấu-trúc-thư-mục)
5. [Build, nạp, xem log](#build-nạp-xem-log)
6. [Debug trong VS Code](#debug-trong-vs-code)
7. [Debug từ terminal](#debug-từ-terminal)
8. [Chạy khi không có board: QEMU](#chạy-khi-không-có-board-qemu)
9. [Tạo dự án của riêng bạn](#tạo-dự-án-của-riêng-bạn)
10. [Tra cứu công cụ](#tra-cứu-công-cụ)
11. [Tài liệu](#tài-liệu)
12. [Xử lý sự cố](#xử-lý-sự-cố)
13. [Tích hợp liên tục](#tích-hợp-liên-tục)
14. [Giấy phép](#giấy-phép)

---

## Cần những gì

**Phần cứng.** Một board ESP32-C3 và một sợi cáp USB-C. Không cần gì thêm — chip
có sẵn cầu USB-Serial-JTAG tích hợp, nên nạp chương trình, console và debugger
đều đi chung sợi cáp đó. Không cần mạch nạp rời.

Mặc định theo **ESP32-C3 SuperMini**: LED trên board ở **GPIO8, tích cực mức
thấp** (ghi 0 thì sáng), nút BOOT ở **GPIO9**. Board khác thì đổi số chân trong
`main.c`; ngoài chỗ đó không có gì phụ thuộc board.

> **Chỉ dùng cho ESP32-C3.** Các địa chỉ thanh ghi và CSR bộ đếm hiệu năng dùng
> ở đây là riêng của chip này. Và đừng điều khiển **GPIO18/GPIO19**: trên board
> dùng USB tích hợp, đó là USB D−/D+ — chạm vào là mất đúng đường kết nối đang
> dùng để nạp và debug.

**Phần mềm.** ESP-IDF **v5.0 trở lên** (phát triển và kiểm thử trên v5.3.5). Nếu
chưa có:

```bash
git clone -b v5.3.5 --recursive https://github.com/espressif/esp-idf.git ~/esp/esp-idf
~/esp/esp-idf/install.sh esp32c3
```

Tùy chọn: VS Code kèm extension ESP-IDF (`tools/setup.sh` tự cài), Doxygen và
Graphviz để sinh tài liệu, và QEMU của Espressif nếu muốn chạy mà không có
board.

---

## Bắt đầu nhanh

Có hai đường vào, tùy bạn muốn *dùng* các hàm này hay *phát triển* chúng.

### A. Thêm component vào dự án của bạn

```bash
idf.py add-dependency "long27032002/esp32c3_riscv_asm^1.1.0"
```

```c
#include "riscv_asm.h"

void app_main(void)
{
    uint32_t tong = asm_sum_loop(55);           /* 1540 */

    asm_gpio_output_init(8);
    asm_gpio_clear(8);                          /* LED sáng — tích cực mức thấp */

    printf("misa = 0x%08lx\n", asm_read_misa());
}
```

### B. Clone repo và làm việc bên trong

```bash
git clone https://github.com/long27032002/esp32c3-riscv-asm.git
cd esp32c3-riscv-asm
./tools/setup.sh                    # tìm ESP-IDF, cài extension VS Code,
                                    # sinh .vscode/ cho example
cd examples/hello_asm
idf.py set-target esp32c3
idf.py -p /dev/ttyACM0 flash monitor
```

`tools/setup.sh` tự dò cổng serial; lệnh trên ghi rõ ra chỉ để thấy dạng lệnh.
Trên Windows dùng `tools\setup.bat`.

Example in ra chuỗi ISA giải mã từ `misa`, tính 1+2+…+55 bằng hai cách rồi đối
chiếu, đo số chu kỳ mỗi cách, điền một bảng trong RAM để có thứ mà xem trong
panel MEMORY, chạy phần hợp ngữ riêng của nó trong `main/app_asm.S`, rồi khởi
động ba task FreeRTOS — một nháy LED, một tính toán, một báo cáo danh sách task.

---

## Giao diện hàm hợp ngữ

Tham chiếu đầy đủ, kèm danh sách thanh ghi bị phá và ghi chú ở mức thanh ghi:
[`components/esp32c3_riscv_asm/riscv_asm.h`](components/esp32c3_riscv_asm/riscv_asm.h).

### Số học

| Hàm | Công dụng |
|---|---|
| `uint32_t asm_sum_loop(uint32_t n)` | 1 + 2 + … + n bằng vòng lặp tường minh. Nhãn `sum_loop` nằm ngay thân vòng lặp, là chỗ đặt breakpoint tự nhiên nhất. |
| `uint32_t asm_sum_closed_form(uint32_t n)` | Cùng kết quả bằng `n(n+1)/2` — một phép nhân thay vì n vòng lặp. Đem so số chu kỳ. |
| `void asm_fill_table(uint32_t n)` | Ghi `g_result_table[]`. Cấp phát khung ngăn xếp thật và lưu các thanh ghi mà ABI yêu cầu, nên minh hoạ đúng việc một hàm không phải lá phải làm. |

`extern uint32_t g_result_table[ASM_RESULT_WORDS]` là mảng nháp trong RAM.
Example in ra địa chỉ của nó; dán địa chỉ đó vào panel MEMORY để xem
`asm_fill_table` ghi vào.

### GPIO

| Hàm | Công dụng |
|---|---|
| `void asm_gpio_output_init(uint32_t pin)` | Định tuyến chân qua IO_MUX và GPIO matrix, rồi bật mạch lái ngõ ra. |
| `void asm_gpio_set(uint32_t pin)` | Kéo chân lên mức cao qua `GPIO_OUT_W1TS`. |
| `void asm_gpio_clear(uint32_t pin)` | Kéo chân xuống mức thấp qua `GPIO_OUT_W1TC`. |
| `uint32_t asm_gpio_read_all(void)` | Trả về nguyên thanh ghi `GPIO_IN`; bit *n* là mức của GPIO *n*. |

`W1TS`/`W1TC` là thanh ghi ghi-1-để-set và ghi-1-để-xoá: mỗi lần ghi chỉ tác
động đúng những bit bạn nêu tên, nên không cần đọc-sửa-ghi và không tranh chấp
với ngắt đang đổi một chân khác.

### Quan sát hệ thống

| Hàm | Công dụng |
|---|---|
| `uint32_t asm_read_misa(void)` | Đọc CSR `misa`, mã hoá các phần mở rộng ISA được cài đặt. |
| `void asm_perf_counter_start(uint32_t event)` | Đặt lại và khởi động bộ đếm hiệu năng. Bit 0 của `event` đếm chu kỳ CPU, bit 1 đếm số lệnh hoàn tất. |
| `uint32_t asm_perf_counter_read(void)` | Đọc bộ đếm. |

### Quy ước gọi hàm

Các hàm tuân theo ABI RISC-V ILP32 chuẩn, nên với trình biên dịch chúng là hàm C
bình thường:

- tham số ở `a0`–`a7`, giá trị trả về ở `a0`;
- `t0`–`t6` và `a0`–`a7` do bên gọi giữ — được phép phá thoải mái;
- `s0`–`s11`, `sp` và `ra` do bên bị gọi giữ — dùng thì phải lưu và khôi phục;
- ngăn xếp luôn căn 16 byte.

Dòng `@clobber` của mỗi hàm nêu chính xác nó động vào thanh ghi nào, nên bạn vừa
chạy từng lệnh vừa đối chiếu mã với chính cam kết của nó được.

---

## Cấu trúc thư mục

```
components/esp32c3_riscv_asm/   component đưa lên registry
    riscv_asm.S                 phần hợp ngữ
    riscv_asm.h                 giao diện C, tài liệu đầy đủ
    CMakeLists.txt
    idf_component.yml           manifest; trỏ sang ../../examples
    README.md  LICENSE          nội dung trang registry hiển thị

examples/hello_asm/             example hoàn chỉnh, chạy được
    main/main.c                 gọi hết các hàm và in kết quả
    main/app_asm.S              hợp ngữ của riêng example — để bạn sửa
    components/riscv_asm/       bản copy riêng, build không cần tải gì
    sdkconfig.defaults          cấu hình cho board
    sdkconfig.qemu              lớp phủ cho máy ảo

templates/blank_asm/            khung rỗng tối thiểu, new-project.sh copy từ đây
tools/                          cài đặt, tạo dự án, QEMU, tài liệu, gỡ kẹt JTAG
.github/workflows/              CI và publish lên registry
```

Có hai thứ trông như trùng lặp nhưng không phải:

**`examples/hello_asm/components/riscv_asm/`** là bản copy của component. Chính
nó làm example tự chứa: build y hệt nhau dù lấy từ git clone hay từ
`idf.py create-project-from-example`, không phải lấy gì từ registry. Thư mục đó
**cố ý không** đặt tên `riscv` — ESP-IDF có sẵn một component tên như vậy, và va
tên làm build hỏng với `fatal error: riscv/rv_utils.h: No such file or directory`.

**`build/`, `sdkconfig` và `.vscode/*.json` sinh ra đều không commit.** Chúng
chứa đường dẫn tuyệt đối và số serial của một board cụ thể, đem sang máy khác là
sai. Mỗi người tự sinh lại bằng `tools/setup.sh`.

---

## Build, nạp, xem log

```bash
cd examples/hello_asm
idf.py set-target esp32c3          # một lần cho mỗi dự án
idf.py build
idf.py -p <CỔNG> flash monitor     # Ctrl-] để thoát monitor
```

`<CỔNG>` thường là `/dev/ttyACM0` trên Linux, `/dev/cu.usbmodem*` trên macOS,
`COM*` trên Windows. Cấu hình do `tools/setup.sh` sinh ra dùng đường dẫn cố định
`/dev/serial/by-id/...`, vì USB tích hợp nối lại sau mỗi lần reset và số `ttyACM`
có thể đổi.

Vài lệnh hay dùng thêm:

```bash
idf.py size                                              # dung lượng flash và RAM
idf.py monitor                                           # chỉ xem log, không nạp lại
riscv32-esp-elf-objdump -d build/hello_asm.elf | less    # toàn bộ disassembly
riscv32-esp-elf-nm build/hello_asm.elf | grep asm_       # kiểm tra symbol có mặt
```

---

## Debug trong VS Code

```bash
./tools/setup.sh                             # example đi kèm
./tools/setup.sh --project ~/work/my_robot   # dự án của bạn
```

Script tìm ESP-IDF, OpenOCD, gdb của toolchain và cổng serial, cài extension VS
Code, rồi sinh `.vscode/settings.json`, `launch.json` và `tasks.json` với đường
dẫn tuyệt đối đã điền sẵn.

> Mở thư mục **project** trong VS Code (`examples/hello_asm`), đừng mở gốc repo.
> VS Code phân giải `${workspaceFolder}` theo thư mục bạn mở, và mọi đường dẫn
> trong cấu hình sinh ra đều tính theo project.

Bấm **F5**. Task `openocd` chạy trước, debugger gắn vào, rồi dừng ở `sum_loop` —
bên trong phần hợp ngữ, không phải ở `app_main`.

### Từng panel cho bạn thấy gì

| Panel | Nội dung |
|---|---|
| **Disassembly** (chuột phải một dòng → *Open Disassembly View*) | Lệnh thật kèm địa chỉ, xen với mã nguồn. `Ctrl+F5` chạy một *lệnh máy*; `F10`/`F11` chạy một dòng nguồn. |
| **Variables → Registers** | Đủ 32 thanh ghi đa dụng cộng `pc`, cập nhật trực tiếp, sửa được. |
| **Debug Console** | Dấu nhắc gdb đầy đủ: `info registers`, `p/x $mcause`, `x/16xw $sp`, `set $a0 = 99`, `info all-registers`. |
| **MEMORY** | Bộ nhớ thô. Dán địa chỉ `g_result_table` mà example in ra rồi xem `asm_fill_table` ghi vào. |
| **xRTOS** | Danh sách task FreeRTOS kèm trạng thái và ngăn xếp từng task. Cần `CONFIG_FREERTOS_USE_TRACE_FACILITY`, `sdkconfig.defaults` đã bật sẵn. |
| **Call Stack** | Khung hàm xuyên biên giới C/hợp ngữ — `asm_sum_loop` → `app_main` → `main_task`. |

Breakpoint đặt thẳng trong file `.S`: bấm vào lề cạnh bất kỳ nhãn nào.

### Các cấu hình debug

| Cấu hình | Dùng khi nào |
|---|---|
| **Debug (task starts OpenOCD)** | Mặc định. Một task của VS Code khởi động OpenOCD bằng đường dẫn tuyệt đối, nên chạy được dù extension có đăng ký ESP-IDF hay không. |
| **Debug on QEMU (no board)** | Không có phần cứng. Xem [QEMU](#chạy-khi-không-có-board-qemu). |
| **Debug (extension starts OpenOCD)** | Để extension ESP-IDF tự quản OpenOCD. Cần extension biết một bản cài ESP-IDF, nếu không nó báo `OPENOCD_SCRIPTS … missing`. |
| **Debug (OpenOCD already running)** | Bạn tự chạy OpenOCD ở một terminal. |

### Các task

**Terminal → Run Task**: `build`, `flash + monitor`, `qemu (run)`,
`qemu (gdb server)`, `recover JTAG (watchdog reset)`, `kill stray OpenOCD`,
`docs (doxygen, en + vi)`.

---

## Debug từ terminal

Hai cửa sổ. Cửa sổ thứ nhất:

```bash
openocd -f board/esp32c3-builtin.cfg
```

Cửa sổ thứ hai:

```bash
cd examples/hello_asm
riscv32-esp-elf-gdb build/hello_asm.elf \
    -ex "target extended-remote :3333" \
    -ex "monitor reset halt" \
    -ex "break sum_loop" \
    -ex "continue"
```

Những lệnh đáng nhớ khi đã dừng bên trong hợp ngữ:

```
info registers          toàn bộ thanh ghi đa dụng và pc
p/x $misa               một CSR, in hệ hex
x/8i $pc                tám lệnh kế tiếp
x/16xw $sp              đỉnh ngăn xếp
stepi / si              chạy một lệnh máy
layout asm              cửa sổ chia đôi nguồn/hợp ngữ
info threads            task FreeRTOS (OpenOCD cung cấp; QEMU thì không)
```

OpenOCD lắng nghe ở **3333** (gdb), 4444 (telnet) và 6666 (tcl). Task sinh ra có
tắt hai cổng không dùng, vì nếu còn tiến trình cũ thì lỗi lại được báo ở cổng
6666 — chẳng liên quan gì tới nguyên nhân thật.

---

## Chạy khi không có board: QEMU

Espressif duy trì một nhánh QEMU mô phỏng ESP32-C3. Cài một lần:

```bash
python "$IDF_PATH/tools/idf_tools.py" install qemu-riscv32
```

Trên Linux nó còn cần libslirp, thứ mà phần lớn bản phân phối không cài sẵn —
`sudo pacman -S libslirp` trên Arch, `sudo apt install libslirp0` trên Debian và
Ubuntu, `brew install libslirp` trên macOS.

```bash
./tools/qemu.sh                     # chạy; Ctrl-A X để thoát
./tools/qemu.sh --gdb               # giữ ở reset vector, mở cổng 3333
./tools/qemu.sh --attach            # nửa debugger, ở terminal thứ hai
```

Trong VS Code, chọn **Debug on QEMU (no board)** rồi bấm F5.

### Cái gì chạy được, cái gì máy ảo không nói cho bạn biết

Breakpoint, chạy từng lệnh, panel Disassembly, đủ 32 thanh ghi đa dụng cùng
`pc` trong **Variables → Registers**, ghi vào thanh ghi, và panel MEMORY đều
hoạt động y như qua JTAG.

Những thứ không chuyển sang được:

- **Không có thế giới điện.** `asm_gpio_set`/`asm_gpio_clear` vẫn ghi thanh ghi
  và `asm_gpio_read_all` vẫn đọc lại được, nhưng không LED nào sáng và nút BOOT
  thì không bao giờ bấm được.
- **Thời gian không phải của chip.** Bộ đếm hiệu năng tăng theo lệnh mô phỏng,
  không theo pipeline thật. Thời gian truy cập flash không được mô hình hoá.
- **Không có danh sách task xRTOS.** Khả năng nhận biết task đến từ `-rtos` của
  OpenOCD; gdbstub của QEMU chỉ báo một thread cho mỗi CPU mô phỏng.
- **Không gọi được CSR theo tên.** QEMU quảng cáo nhiều CSR hơn số nó chịu
  phục vụ, mà panel Registers hỏi tất cả thanh ghi trong **một** lệnh, nên chỉ
  cần một lần từ chối — đầu tiên là `htimedelta`, một CSR hypervisor — là cả
  panel trống. Vì vậy cấu hình QEMU đưa cho gdb một mô tả rút gọn
  (`tools/templates/riscv-qemu.xml`), và cái giá là mất tên CSR: `p/x $misa`
  trả về `void`. Hãy đọc chúng từ chính chương trình — `asm_read_misa()` làm
  đúng việc đó — hoặc debug trên board, nơi OpenOCD chỉ khai những thanh ghi
  nó phục vụ được nên cả panel lẫn tên CSR đều chạy. Muốn đánh đổi theo chiều
  ngược lại, xoá dòng `set tdesc filename` trong `.vscode/launch.json`.
- **`misa` khác.** QEMU báo `0x401411ad`; header ghi giá trị của chip là
  `0x40101104`. Nếu bạn đang khảo sát silicon thật có những phần mở rộng nào,
  phải dùng board.

### Cơ chế bên trong, phòng khi bạn cần sửa

Bản build đi vào **`build-qemu/` với `sdkconfig` riêng**. Không phải cho gọn:
example chạy console qua USB-Serial-JTAG, thứ QEMU không mô phỏng, nên bản build
cho board sẽ **im lặng hoàn toàn** sau bootloader — không phân biệt được với
crash sớm. `sdkconfig.qemu` chuyển console sang UART0. Mà `sdkconfig` có sẵn lại
đè `SDKCONFIG_DEFAULTS`, nên lớp phủ chỉ có tác dụng vì bản build được trỏ sang
một file config riêng; điều đó cũng ngăn máy ảo ghi đè cấu hình của board. Thư
mục tách rời còn tránh phải build lại từ đầu mỗi lần đổi qua đổi lại.

### QEMU có xung đột với board đang cắm không?

**Có đúng một chỗ: cổng 3333.** `idf.py qemu --gdb` ghim cứng `-gdb tcp::3333`
và QEMU chỉ nhận `-gdb` đầu tiên trên dòng lệnh, nên không đổi cổng từ bên ngoài
được. Đó cũng là cổng gdb của OpenOCD, nên **không thể debug board và máy ảo
cùng lúc**. Cả hai chiều đều đã xử lý: `--gdb` dừng OpenOCD đang chạy trước, và
task `openocd` dừng QEMU đang chạy.

Ngoài ra chúng không ảnh hưởng nhau. QEMU không bao giờ mở cổng serial, nên
`idf.py flash monitor` trên board vẫn chạy song song; và QEMU không ghi gì vào
board — nó không gọi esptool, không chạm JTAG. Thư mục build và cấu hình tách
rời nên không bên nào đè bên nào.

> **Đừng nạp `build-qemu/*.bin` lên board thật.** Console của nó ở UART0
> (GPIO20/21), nạp lên board rồi mở monitor qua USB sẽ không thấy gì — đúng
> triệu chứng "crash im lặng" nói ở trên. Nạp board thì lấy từ `build/`.

---

## Tạo dự án của riêng bạn

```bash
./tools/new-project.sh my_robot                   # từ khung rỗng
./tools/new-project.sh my_robot --from hello_asm  # từ một example
./tools/new-project.sh --list                     # xem copy được từ đâu
```

Dự án mới có bản copy component riêng trong `components/esp32c3_riscv_asm/`, nên
build không cần tải gì và phần hợp ngữ nằm ngay đó để sửa. Thêm `--from-registry`
nếu muốn phụ thuộc vào component đã publish.

```bash
cd my_robot
idf.py set-target esp32c3 && idf.py build
~/esp32c3-riscv-asm/tools/setup.sh --project "$PWD"   # rồi bấm F5 trong VS Code
```

Hoặc bắt đầu thẳng từ registry, không cần clone:

```bash
idf.py create-project-from-example "long27032002/esp32c3_riscv_asm^1.1.0:hello_asm"
```

### Tự viết một hàm hợp ngữ

`main/app_asm.S`, có trong cả khung rỗng lẫn example, là của bạn. Khuôn để theo:

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

Khai báo nó trong một header (`uint32_t app_double(uint32_t);`), thêm file `.S`
vào `SRCS` trong `main/CMakeLists.txt`, rồi gọi từ C. Ba chỉ thị `.global`,
`.type` và `.size` chính là thứ đưa symbol vào ELF với kích thước đúng, để gdb và
panel Disassembly tìm thấy nó.

---

## Tra cứu công cụ

Mọi script đều nhận `--help` và không đoán bừa: thiếu ESP-IDF hay thiếu board
thì nó nói thẳng, kèm lệnh để khắc phục.

| Script | Làm gì | Tham số |
|---|---|---|
| `tools/setup.sh` | Tìm ESP-IDF, cài extension VS Code, sinh `.vscode/` | `--check`, `--no-install`, `--idf-path DIR`, `--port DEV`, `--project DIR`, `--breakpoint SYM` |
| `tools/new-project.sh` | Tạo dự án từ khung rỗng hoặc từ example | `--list`, `--from NAME`, `--dir DIR`, `--author NAME`, `--from-registry` |
| `tools/qemu.sh` | Chạy hoặc debug trên máy ảo | `--gdb`, `--attach`, `--project DIR`, `--no-build`, `--no-monitor` |
| `tools/recover-jtag.sh` | Watchdog reset cho debug module bị kẹt | `--port DEV`, `--idf-path DIR` |
| `tools/build-docs.sh` | Doxygen, tiếng Anh và tiếng Việt, có cảnh báo là fail | — |
| `tools/check-release.sh` | Quét đường dẫn máy, serial board, khoá, build lỡ commit | — |

Bản Windows: `tools\setup.bat`, `tools\qemu.bat`, `tools\recover-jtag.bat` (và
các script `.ps1` phía sau, dùng tham số kiểu PowerShell: `-Gdb`, `-Project`,
`-NoBuild`).

---

## Tài liệu

```bash
./tools/build-docs.sh        # → docs/html/index.html
```

Sinh hai bộ tài liệu đầy đủ từ cùng mã nguồn: tiếng Anh ở `docs/html/en/`, tiếng
Việt ở `docs/html/vi/`, kèm trang chọn ngôn ngữ ở `docs/html/index.html`. Chú
thích trong mã viết bằng tiếng Anh; bản tiếng Việt dịch phần điều hướng của
Doxygen.

Graphviz là tùy chọn — có `dot` thì bật đồ thị lời gọi, không có thì bỏ qua.
Script fail nếu Doxygen có **bất kỳ** cảnh báo nào, vì thiếu một `@param` chính
là cách tài liệu tham chiếu mục ruỗng dần.

---

## Xử lý sự cố

| Triệu chứng | Nguyên nhân và cách gỡ |
|---|---|
| `Examination failed`, `Unsupported DTM version: -1`, `Timed out … waiting for busy to go low` | Debug module bị kẹt, thường do phiên debug bị cắt ngang lúc target đang halt. Reset thường không đủ — nó chỉ khởi động lại CPU, debug module vẫn kẹt. Chạy `./tools/recover-jtag.sh`, lệnh này gửi watchdog reset, khởi động lại cả lõi số. |
| `couldn't bind to socket on port 6666` | Còn OpenOCD cũ. `pkill -x openocd`. Lỗi báo ở 6666 dù cổng thật sự quan trọng là 3333. |
| QEMU: `Failed to bind socket`, hoặc debugger không kết nối được | OpenOCD hoặc một QEMU cũ đang giữ 3333. `pkill -x openocd; pkill -f '[q]emu-system-riscv32'`. Lưu ý `pkill -x qemu-system-riscv32` không khớp gì cả: `/proc/PID/comm` cắt tên còn 15 ký tự. |
| QEMU khởi động, in bootloader rồi im | Console đang ở USB-Serial-JTAG, QEMU không mô phỏng. Dùng `tools/qemu.sh`, nó nạp thêm `sdkconfig.qemu`. |
| QEMU: `libslirp.so.0: cannot open shared object file` | Cài libslirp (Debian và Ubuntu: `libslirp0`). |
| `"monitor" command not supported by this target.` | Một cấu hình dành cho board chạy khi không có OpenOCD: kết nối hỏng, rồi các lệnh sau-kết-nối chạy trên phiên chưa kết nối. Thường là do đang mở **gốc repo** trong VS Code thay vì thư mục project — `.vscode/launch.json` cũ ở đó chào mời các cấu hình board trỏ vào một ELF không còn tồn tại. Hãy mở `examples/hello_asm`; `tools/setup.sh` sẽ xoá các file cũ ở gốc. |
| Panel Registers chỉ hiện `Could not fetch register "h…"` | QEMU khai cả những CSR nó không phục vụ, và chỉ một lần từ chối là hỏng cả lệnh. Sinh lại bằng `tools/setup.sh`, nó trỏ gdb sang một mô tả thanh ghi rút gọn. |
| Debug console của QEMU hiện `unknown command: 'reset'` | Vô hại. Extension tự chèn `monitor reset halt`; gdbstub của QEMU không có lệnh đó, mà kết nối thì đã lên rồi. Cũng chẳng cần reset — QEMU giữ CPU ở reset vector tới khi debugger gắn vào. |
| `A program is being debugged already` / `could not connect: Connection timed out` | Có thứ gì đó connect hai lần. `initCommands` được gửi *sau* khi adapter đã kết nối, nên để `target remote` ở đó — hoặc trong `connectCommands` — là connect lần nữa. Sinh lại bằng `tools/setup.sh`. |
| Cổng serial đổi tên sau khi reset | USB tích hợp nối lại. Cấu hình sinh ra dùng đường dẫn cố định `/dev/serial/by-id/...`; muốn ép thì truyền `--port`. |
| Extension báo `OPENOCD_SCRIPTS environment variable is missing` | Bạn chọn *Debug (extension starts OpenOCD)* mà chưa đăng ký bản cài ESP-IDF. Dùng cấu hình mặc định, hoặc F1 → *ESP-IDF: Configure ESP-IDF extension* → **USE EXISTING SETUP**. |
| `env: 'bash\r': No such file or directory` | Script shell bị checkout với kết thúc dòng CRLF. `sed -i 's/\r$//' tools/*.sh`, và kiểm tra `.gitattributes` còn nguyên. |
| `fatal error: riscv/rv_utils.h: No such file or directory` | Một thư mục component của bạn đang tên `riscv`, va với component có sẵn của ESP-IDF. Đổi tên nó. |
| LED không nháy nhưng console vẫn bình thường | Sai chân hoặc sai cực tính với board của bạn. Mặc định là GPIO8, tích cực mức thấp. |

---

## Tích hợp liên tục

Mỗi lần push và mỗi pull request chạy tám job:

| Job | Chứng minh điều gì |
|---|---|
| **build** | Mọi example biên dịch sạch với cảnh báo bị coi là lỗi, dự án sinh từ khung rỗng cũng biên dịch được, và các symbol mong đợi có thật trong ELF. |
| **qemu** | Firmware *chạy* thật: các tổng ra đúng, phần hợp ngữ riêng của example trả về đúng giá trị, cả hai task khởi động, và không có panic. |
| **generate** | `setup.sh` vẫn sinh JSON hợp lệ, không sót placeholder, và các file sinh ra vẫn nằm ngoài git. |
| **component** | Component đóng gói được cho registry, có README và LICENSE trong archive, không lẫn output build. |
| **leaks** | Không có đường dẫn máy, số serial board hay khoá nào bị commit. |
| **docs** | Doxygen build cả hai ngôn ngữ không cảnh báo, có và không có Graphviz. |
| **shell** | `bash -n` và shellcheck đều sạch; kết thúc dòng là LF. |
| **windows** | Script PowerShell parse được trên máy Windows thật và fail sạch khi thiếu ESP-IDF; file batch đúng CRLF. |

Những gì CI không làm được: nạp board, điều khiển JTAG, nháy LED hay đo số chu
kỳ thật. Mấy việc đó vẫn phải kiểm bằng tay.

---

## Giấy phép

MIT — xem [LICENSE](LICENSE). Hoan nghênh đóng góp; CI phải xanh và
`tools/check-release.sh` phải sạch.
