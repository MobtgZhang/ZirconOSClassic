# EDK2 Nightly 固件（QEMU）

`make run` 会从 [EDK2 Nightly Build](https://retrage.github.io/edk2-nightly/) 自动下载所需文件到此目录（若尚不存在）：

| 架构 | 文件 |
|------|------|
| x86_64 | `DEBUGX64_OVMF_CODE.fd`、`DEBUGX64_OVMF_VARS.fd` |
| aarch64 | `DEBUGAARCH64_QEMU_EFI.fd`、`DEBUGAARCH64_QEMU_VARS.fd` |

**LoongArch64** 不使用本目录，改用龙芯官方 `virt` 固件，见 [`firmware/loongarch-virt/README.md`](../loongarch-virt/README.md)。

也可手动下载后放到本目录，或通过环境变量 `EDK2_NIGHTLY_DIR` 指向其他路径。
