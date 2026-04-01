# ZBM ↔ ntoskrnl 引导 ABI（Multiboot2 兼容信息块）

ZirconOS Boot Manager（BIOS 与 UEFI）在将控制权交给内核前，构造 **与 Multiboot2 规范一致** 的信息结构，以便单一解析路径适用于 x86_64、AArch64 与 LoongArch64（UEFI）。

## 入口约定

| 项目 | x86_64（AMD64 ABI） | AArch64（AAPCS64） | LoongArch64（LP64D） |
|------|---------------------|---------------------|----------------------|
| 入口符号 | 由内核 `.uefi_vector` 中 `kernel_entry` 指定（通常为 `kernel_main`） | 同上 | 同上（见 [`src/arch/loongarch64/uefi_vector.S`](../src/arch/loongarch64/uefi_vector.S)） |
| 魔数 | `RDI` = `0x36D76289` | `X0` = `0x36D76289` | `$a0` = `0x36D76289` |
| 信息块物理地址 | `RSI` | `X1` | `$a1` |
| 栈指针 | `RSP` = `uefi_vector.stack_addr` | `SP` = 同上 | `$sp` = 同上 |

内核符号 `kernel_main(magic: u32, info_addr: usize) callconv(.c)` 与上述寄存器传参一致。

## UEFI 向量表（`.uefi_vector`）

加载器在**已加载的 PT_LOAD 物理地址包络** `[min_paddr, max_end)` 内按 8 字节对齐步进扫描魔数 `0x55454649`（`"UEFI"`；`.uefi_vector` 在 `.text`/`.rodata` 之后，常远超过 64KiB）。结构布局与 AArch64 / LoongArch 汇编中 `.uefi_vector` 段一致（例如 [`src/arch/aarch64/uefi_vector.S`](../src/arch/aarch64/uefi_vector.S)）：

- `magic: u32`, `version: u32`
- `kernel_entry: u64` — 指向 `kernel_main`
- `stack_addr: u64` — 内核栈顶（已 16 字节对齐）

x86_64 若需 UEFI 启动，应在链接脚本中放入等效向量段（当前 x86_64 以 Multiboot2 头 + BIOS/ZBM 为主）。

## 信息块布局（必须标签）

解析实现：[`src/boot/multiboot2.zig`](../src/boot/multiboot2.zig)。

ZBM **应提供**：

1. **类型 1 — command line**：与菜单项一致的 ASCII 命令行（`console=`、`debug=`、`desktop=` 等）。
2. **类型 4 — basic memory info**：`mem_lower` / `mem_upper`（KB）。
3. **类型 6 — memory map**：`entry_size = 24`，条目为 `base(8) + length(8) + type(4) + reserved(4)`；类型值与 Multiboot2 一致（可用 RAM = 1）。
4. **类型 8 — framebuffer**（若 GOP 可用）：固定字节偏移解析，含 64 位物理地址、`pitch`、`width`、`height`、`bpp`、类型及可选扩展字节（BGR 标志）。
5. **类型 14 / 15 — ACPI RSDP**（UEFI 配置表导出）：内嵌 `RSD PTR ` 结构副本；内核解析后得到 `acpi_rsdp_phys` 并填入 [`ZirconBootContext`](../src/boot/zircon_boot_context.zig)。

**类型 0 — end** 结束标签。

UEFI 路径下 GOP 须在 **ExitBootServices 之前** 查询；信息块与 mmap 缓冲区须在退出引导服务前分配。

## 图形会话与输入（实现提示）

- 帧缓冲标签存在时，内核 GRE 在 `subsystems/zircon64/gre_early.zig` 中初始化线性 FB；配色常量语义见 `docs/DEVELOPMENT.md`（**0xRRGGBB**）。
- **x86_64**：PS/2 键盘/鼠标经 8042 + 8259 PIC，IRQ1 / IRQ12；QEMU 默认 `-machine q35`/`pc` 通常已提供 PS/2 鼠标，无需额外 `-device` 即可驱动当前 `ps2_mouse.zig` 桩。

## 参考实现位置

- Multiboot2 信息块构造（UEFI 共用）：[`boot/zbm/uefi/boot_info.zig`](../boot/zbm/uefi/boot_info.zig)。
- UEFI x86_64 / AArch64：`boot/zbm/uefi/main.zig`（跳转约定）。
- UEFI LoongArch64（Zig 对象 + 内置 crt0/reloc/lds + 交叉 gcc/objcopy → `BOOTLOONGARCH64.EFI`）：[`boot/zbm/uefi/main_loongarch64.zig`](../boot/zbm/uefi/main_loongarch64.zig)、[`boot/zbm/uefi/vendor/loongarch64/`](../boot/zbm/uefi/vendor/loongarch64/)、[`scripts/link_zbm_loongarch_efi.sh`](../scripts/link_zbm_loongarch_efi.sh)。
- Multiboot2 构造辅助（BIOS）：`boot/zbm/zbm.zig`。
- ELF 与 Multiboot2 头检测：`boot/zbm/loader.zig`。
