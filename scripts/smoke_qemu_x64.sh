#!/usr/bin/env bash
# 冒烟：构建 x86_64 kernel+uefi 后以 QEMU + EDK2 Nightly 启动（等同 make run ARCH=x86_64）。
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
make -C "$ROOT" kernel uefi ARCH=x86_64
exec env \
  ROOT="$ROOT" \
  ARCH=x86_64 \
  QEMU_MEM="${QEMU_MEM:-512M}" \
  QEMU_ACCEL="${QEMU_ACCEL:-kvm:tcg}" \
  EDK2_NIGHTLY_DIR="${EDK2_NIGHTLY_DIR:-$ROOT/firmware/edk2-nightly}" \
  EDK2_BASE_URL="${EDK2_BASE_URL:-https://retrage.github.io/edk2-nightly/bin}" \
  ESP_ROOT="${ESP_DIR:-$ROOT/build/qemu-esp}" \
  ZIG_OUT="$ROOT/zig-out/bin" \
  "$ROOT/scripts/qemu_run.sh" "$@"
