# LoongArch QEMU `virt` 固件（龙芯官方）

`make run`（`ARCH=loongarch64`）时，`scripts/qemu_run.sh` 会从此目录读取（若缺失则自动下载）：

| 文件 | 说明 |
|------|------|
| `QEMU_EFI.fd` | UEFI 代码镜像 |
| `QEMU_VARS.fd` | NVRAM（当前启动线仅用 `-bios QEMU_EFI.fd`；VARS 预取供自行改用 pflash/blockdev 时备用） |

上游与用法说明：[loongson/Firmware — LoongArchVirtMachine](https://github.com/loongson/Firmware/tree/main/LoongArchVirtMachine)。

下载直链（`main` 分支）：

- <https://raw.githubusercontent.com/loongson/Firmware/main/LoongArchVirtMachine/QEMU_EFI.fd>
- <https://raw.githubusercontent.com/loongson/Firmware/main/LoongArchVirtMachine/QEMU_VARS.fd>

目录可通过环境变量 **`LOONGARCH_FW_DIR`** 覆盖（Makefile 会传入绝对路径）。

## QEMU（`scripts/qemu_run.sh`）

- ESP 使用 **`virtio-blk-pci` + `bootindex=1`**（勿仅用 `-drive if=virtio`，否则部分 EDK2 不把 FAT 当启动盘）。
- **`nec-usb-xhci` + `usb-kbd`**：ZBM 菜单需要 ConIn。
- 可选环境变量：`QEMU_LA_SMP`（默认 2）、`QEMU_LA_GPU=0`（不挂 `virtio-gpu-pci`，纯串口）、`QEMU_LA_MONITOR=none`。
