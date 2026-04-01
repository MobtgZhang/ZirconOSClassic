# 内核映像格式（ELF 与 PE32+）

## 当前状态（权威）

- **ZirconOS Boot Manager（ZBM）** 在 x86_64 UEFI 路径下加载 **`\\boot\\kernel.elf`**（ELF64，由 `zig build` + `link/x86_64.ld` 产出）。
- 引导器将 **Multiboot2 兼容信息块**（命令行、内存映射、可选 GOP 帧缓冲、**ACPI RSDP tag 14/15**）置于约定物理内存，再跳转到内核 `kernel_main`（见 [`BOOT_ABI.md`](BOOT_ABI.md)）。

## PE32+ 内核（可选远期）

- 路线图曾讨论将 ntoskrnl 以 **PE32+** 形式加载（与部分 NT 风格工具链一致）。本仓库**尚未**实现 PE 内核加载器；若未来增加：
  - 须在 ZBM 中实现 PE 头解析、重定位与（若需要）导入解析；
  - 或保留 ELF 为主目标，仅将驱动以 PE 形式加载。
- 在实现或文档变更时，请同步更新本文与 [`ideas/content1.2.md`](../ideas/content1.2.md) 中的工具链/引导章节。

## 合规提示

- PE/COFF 结构可参考 **公开规范** 与官方文档中的描述；**不要**复制受版权保护的私有头文件或泄露源码中的魔数注释作为「唯一依据」。
