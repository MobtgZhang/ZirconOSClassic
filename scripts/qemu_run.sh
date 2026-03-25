#!/usr/bin/env bash
# QEMU 启动 ZirconOS Classic（UEFI ZBM + ESP）。
# x86_64 / aarch64：EDK2 Nightly；loongarch64：龙芯 LoongArchVirtMachine（-bios，不用 if=pflash）。
#
# LoongArch64：默认 QEMU_LA_GPU=1 时加 ramfb + virtio-gpu-pci；内核优先用 ramfb 线性 FB（无需 virtqueue）。
# 仅串口、不要窗口：QEMU_LA_GPU=0（会加 -display none）。固件 GOP 为 BLT-only 时仍会无 tag 8，见 ZBM 提示。
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

ARCH="${ARCH:-x86_64}"
QEMU_MEM="${QEMU_MEM:-512M}"
BOOT_METHOD="${BOOT_METHOD:-uefi}"
EDK2_BASE_URL="${EDK2_BASE_URL:-https://retrage.github.io/edk2-nightly/bin}"
EDK2_NIGHTLY_DIR="${EDK2_NIGHTLY_DIR:-$ROOT/firmware/edk2-nightly}"
LOONGARCH_FW_DIR="${LOONGARCH_FW_DIR:-$ROOT/firmware/loongarch-virt}"
LOONGARCH_FW_URL_BASE="https://raw.githubusercontent.com/loongson/Firmware/main/LoongArchVirtMachine"
ESP_ROOT="${ESP_ROOT:-$ROOT/build/qemu-esp}"
ZIG_BIN="${ZIG_OUT:-$ROOT/zig-out/bin}"
QEMU_ACCEL="${QEMU_ACCEL:-kvm:tcg}"

if [[ "$BOOT_METHOD" != "uefi" ]]; then
  echo "qemu_run.sh: 仅支持 BOOT_METHOD=uefi（当前为 $BOOT_METHOD）。" >&2
  exit 1
fi

die() { echo "qemu_run.sh: $*" >&2; exit 1; }

fetch() {
  local url="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$out" "$url" || die "下载失败: $url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$out" "$url" || die "下载失败: $url"
  else
    die "需要 curl 或 wget 以下载 EDK2 Nightly 固件"
  fi
}

ensure_edk2_x64() {
  local code="$EDK2_NIGHTLY_DIR/DEBUGX64_OVMF_CODE.fd"
  local vars="$EDK2_NIGHTLY_DIR/DEBUGX64_OVMF_VARS.fd"
  [[ -f "$code" ]] || fetch "$EDK2_BASE_URL/DEBUGX64_OVMF_CODE.fd" "$code"
  [[ -f "$vars" ]] || fetch "$EDK2_BASE_URL/DEBUGX64_OVMF_VARS.fd" "$vars"
  echo "$code" "$vars"
}

ensure_edk2_aarch64() {
  local code="$EDK2_NIGHTLY_DIR/DEBUGAARCH64_QEMU_EFI.fd"
  local vars="$EDK2_NIGHTLY_DIR/DEBUGAARCH64_QEMU_VARS.fd"
  [[ -f "$code" ]] || fetch "$EDK2_BASE_URL/DEBUGAARCH64_QEMU_EFI.fd" "$code"
  [[ -f "$vars" ]] || fetch "$EDK2_BASE_URL/DEBUGAARCH64_QEMU_VARS.fd" "$vars"
  echo "$code" "$vars"
}

# 龙芯官方 virt 固件（-bios；QEMU 8.x virt 无 pflash0 属性，勿用 -drive if=pflash）
ensure_loongarch_virt_fw() {
  local efi="$LOONGARCH_FW_DIR/QEMU_EFI.fd"
  local vars="$LOONGARCH_FW_DIR/QEMU_VARS.fd"
  mkdir -p "$LOONGARCH_FW_DIR"
  [[ -f "$efi" ]] || fetch "$LOONGARCH_FW_URL_BASE/QEMU_EFI.fd" "$efi"
  [[ -f "$vars" ]] || fetch "$LOONGARCH_FW_URL_BASE/QEMU_VARS.fd" "$vars"
  echo "$efi" "$vars"
}

[[ -f "$ZIG_BIN/kernel" ]] || die "缺少 $ZIG_BIN/kernel，请先 make kernel"

rm -rf "$ESP_ROOT"
mkdir -p "$ESP_ROOT/EFI/Boot" "$ESP_ROOT/boot"

case "$ARCH" in
  x86_64|aarch64)
    # Zig 将 UEFI 应用安装为 zbmfw.efi（部分环境也可能为 zbmfw）
    ZBM_SRC=""
    if [[ -f "$ZIG_BIN/zbmfw.efi" ]]; then
      ZBM_SRC="$ZIG_BIN/zbmfw.efi"
    elif [[ -f "$ZIG_BIN/zbmfw" ]]; then
      ZBM_SRC="$ZIG_BIN/zbmfw"
    else
      die "缺少 $ZIG_BIN/zbmfw.efi（或 zbmfw）；请先 make uefi"
    fi
    ;;
  loongarch64)
    [[ -f "$ZIG_BIN/BOOTLOONGARCH64.EFI" ]] || die "缺少 $ZIG_BIN/BOOTLOONGARCH64.EFI；请先 make loongarch-efi"
    ;;
  *)
    die "不支持的 ARCH=$ARCH（UEFI 下支持 x86_64 | aarch64 | loongarch64）"
    ;;
esac

case "$ARCH" in
  x86_64)
    cp "$ZBM_SRC" "$ESP_ROOT/EFI/Boot/BOOTX64.EFI"
    ;;
  aarch64)
    cp "$ZBM_SRC" "$ESP_ROOT/EFI/Boot/BOOTAA64.EFI"
    ;;
  loongarch64)
    cp "$ZIG_BIN/BOOTLOONGARCH64.EFI" "$ESP_ROOT/EFI/Boot/BOOTLOONGARCH64.EFI"
    ;;
esac
cp "$ZIG_BIN/kernel" "$ESP_ROOT/boot/kernel.elf"

# LoongArch：部分固件在空 NVRAM 时更易从「PCI 磁盘」走默认启动；startup.nsh 作兜底（Shell 环境）
if [[ "$ARCH" == "loongarch64" ]]; then
  printf 'fs0:\r\ncd \\EFI\\Boot\r\nBOOTLOONGARCH64.EFI\r\n' >"$ESP_ROOT/startup.nsh"
fi

case "$ARCH" in
  x86_64)
    read -r OVMF_CODE OVMF_VARS < <(ensure_edk2_x64)
    exec qemu-system-x86_64 \
      -machine "q35,accel=$QEMU_ACCEL" \
      -cpu qemu64 \
      -m "$QEMU_MEM" \
      -serial stdio \
      -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
      -drive "if=pflash,format=raw,file=$OVMF_VARS" \
      -drive "if=virtio,format=raw,file=fat:rw:$ESP_ROOT" \
      "$@"
    ;;
  aarch64)
    read -r EFI_CODE EFI_VARS < <(ensure_edk2_aarch64)
    exec qemu-system-aarch64 \
      -machine "virt,accel=$QEMU_ACCEL" \
      -cpu cortex-a72 \
      -m "$QEMU_MEM" \
      -serial stdio \
      -drive "if=pflash,format=raw,readonly=on,file=$EFI_CODE" \
      -drive "if=pflash,format=raw,file=$EFI_VARS" \
      -drive "if=virtio,format=raw,file=fat:rw:$ESP_ROOT" \
      "$@"
    ;;
  loongarch64)
    read -r LA_EFI _LA_VARS < <(ensure_loongarch_virt_fw)
    # QEMU loongarch virt：固件要求 ram_size > 1GiB（512M/1G 会报错）
    LA_MEM="${QEMU_MEM_LOONGARCH:-$QEMU_MEM}"
    case "$LA_MEM" in
      512M|256M|384M|128M|768M|896M|1024M|1G|1g|512m|1024m)
        LA_MEM=2G
        ;;
    esac
    LA_ACCEL="${QEMU_ACCEL_LOONGARCH:-tcg}"
    LA_SMP="${QEMU_LA_SMP:-2}"
    # 勿用 -drive if=virtio：常为 mmio virtio，BDS 不当作可启动硬盘。用 virtio-blk-pci + bootindex（与龙芯文档中的 PCI 盘一致）。
    # USB：ZBM 文本菜单需 ConIn；参考 <https://github.com/loongson/Firmware/tree/main/LoongArchVirtMachine>
    LA_QEMU=(qemu-system-loongarch64
      -machine "virt,accel=$LA_ACCEL,usb=on"
      -cpu la464
      -smp "$LA_SMP"
      -m "$LA_MEM"
      -bios "$LA_EFI"
      -serial stdio
      -drive "if=none,id=esp0,format=raw,file=fat:rw:$ESP_ROOT"
      -device "virtio-blk-pci,drive=esp0,bootindex=1"
      -device nec-usb-xhci,id=la_xhci
      -device "usb-kbd,bus=la_xhci.0"
      -boot "menu=on,strict=off,order=d")
    # ramfb：fw_cfg 线性帧缓冲；virtio-gpu-pci：固件 GOP（你日志里 640×480 即此路径）。
    # virtio-input：QEMU 仅在 `display=` 指向**当前窗口所用的图形设备**时才 bind UI 指针/键盘；
    # 否则 `qemu_input_handler_bind` 不执行，客户机 virtqueue 永远收不到 REL 事件（指针居中但不动）。
    if [[ "${QEMU_LA_GPU:-1}" == "1" ]]; then
      LA_QEMU+=(-device ramfb,id=la_ramfb -device virtio-gpu-pci,id=la_gpu)
      LA_QEMU+=(-device virtio-keyboard-pci,display=la_gpu -device virtio-mouse-pci,display=la_gpu)
    else
      LA_QEMU+=(-display none)
      LA_QEMU+=(-device virtio-keyboard-pci -device virtio-mouse-pci)
    fi
    if [[ "${QEMU_LA_MONITOR:-}" == "none" ]]; then
      LA_QEMU+=(-monitor none)
    fi
    exec "${LA_QEMU[@]}" "$@"
    ;;
esac
