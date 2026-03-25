# ZirconOS Classic — Makefile 封装 `zig build` + QEMU（EDK2 Nightly 固件）
# 依赖：Zig ≥ 0.15.2；make run 需 qemu-system-*、curl 或 wget
#
# 默认目标：make == make run（构建 kernel/uefi 后在 QEMU 中启动）
# 固件：<https://retrage.github.io/edk2-nightly/>（首次运行自动下载到 EDK2_NIGHTLY_DIR）
#
# 配置：根目录 build.conf（GNU Make 赋值语法）
# 覆盖示例：make ARCH=aarch64 DESKTOP=none build

ZIG ?= zig
SHELL := /bin/bash

# 用户配置（build.conf 中建议使用 `KEY = value` 形式，与 ZirconOS 一致）
-include build.conf

# 未在 build.conf 中设置时的默认值
ARCH ?= x86_64
DESKTOP ?= ntclassic
OPTIMIZE ?= Debug
ENABLE_IDT ?= true
BOOT_METHOD ?= uefi
BOOTLOADER ?= zbm
RESOLUTION ?= 1024x768x32
QEMU_MEM ?= 512M
QEMU_ACCEL ?= kvm:tcg
# 追加 QEMU 参数（build.conf 中可设，例如 -display none）
QEMU_EXTRA ?=
EDK2_BASE_URL ?= https://retrage.github.io/edk2-nightly/bin
EDK2_NIGHTLY_DIR ?= firmware/edk2-nightly
LOONGARCH_FW_DIR ?= firmware/loongarch-virt
ESP_ROOT ?= build/qemu-esp

EDK2_ABS := $(abspath $(EDK2_NIGHTLY_DIR))
LOONGARCH_FW_ABS := $(abspath $(LOONGARCH_FW_DIR))
ESP_ABS := $(abspath $(ESP_ROOT))

# 与上游 ZirconOS build.conf 对齐：DEBUG_LOG 映射为 zig -Ddebug=
ifneq ($(strip $(DEBUG_LOG)),)
  DEBUG := $(DEBUG_LOG)
endif
DEBUG ?= true

# 与 build.zig 中 option 名称一致
ZIG_COMMON := -Ddebug=$(DEBUG) -Ddefault_desktop=$(DESKTOP) -Denable_idt=$(ENABLE_IDT)
ZIG_BASE := -Darch=$(ARCH) $(ZIG_COMMON)
ifneq ($(OPTIMIZE),Debug)
  ZIG_BASE += -Doptimize=$(OPTIMIZE)
endif

ZIG_LOONGARCH := -Darch=loongarch64 $(ZIG_COMMON)
ifneq ($(OPTIMIZE),Debug)
  ZIG_LOONGARCH += -Doptimize=$(OPTIMIZE)
endif

export ROOT := $(CURDIR)

.PHONY: all run build kernel uefi zbm zbm-loongarch-uefi loongarch-efi fetch-edk2 clean distclean help

# 默认：构建并在 QEMU 中运行（UEFI）
all: run

build:
	$(ZIG) build $(ZIG_BASE)

run:
	@case "$(ARCH)" in \
		loongarch64) $(MAKE) kernel loongarch-efi ;; \
		*) $(MAKE) kernel uefi ;; \
	esac
	@if [[ "$(BOOT_METHOD)" != "uefi" ]]; then \
		echo "make run 当前仅支持 BOOT_METHOD=uefi（build.conf 中为 $(BOOT_METHOD)）。" >&2; \
		exit 1; \
	fi
	@ARCH=$(ARCH) \
		QEMU_MEM=$(QEMU_MEM) \
		QEMU_ACCEL=$(QEMU_ACCEL) \
		BOOT_METHOD=$(BOOT_METHOD) \
		EDK2_BASE_URL=$(EDK2_BASE_URL) \
		EDK2_NIGHTLY_DIR=$(EDK2_ABS) \
		LOONGARCH_FW_DIR=$(LOONGARCH_FW_ABS) \
		ESP_ROOT=$(ESP_ABS) \
		ZIG_OUT=$(CURDIR)/zig-out/bin \
		ROOT=$(CURDIR) \
		"$(CURDIR)/scripts/qemu_run.sh" $(QEMU_EXTRA)

kernel:
	$(ZIG) build kernel $(ZIG_BASE)

uefi:
	$(ZIG) build uefi $(ZIG_BASE)

zbm:
	$(ZIG) build zbm -Darch=x86_64 -Ddebug=$(DEBUG)

zbm-loongarch-uefi:
	$(ZIG) build zbm-loongarch-uefi $(ZIG_LOONGARCH)

# Zig 对象 + GNU-EFI → zig-out/bin/BOOTLOONGARCH64.EFI（需 loongarch 交叉 gcc 与 gnu-efi）
loongarch-efi: zbm-loongarch-uefi
	bash "$(CURDIR)/scripts/link_zbm_loongarch_efi.sh"

# 预取 EDK2 Nightly 固件（可选；make run 也会在缺失时自动下载；需 curl 或 wget）
fetch-edk2:
	@mkdir -p "$(EDK2_ABS)"
	@echo "Fetching EDK2 Nightly from $(EDK2_BASE_URL) -> $(EDK2_ABS)"
	@fget() { if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$$1" "$$2"; else wget -q -O "$$1" "$$2"; fi; }; \
	fget "$(EDK2_ABS)/DEBUGX64_OVMF_CODE.fd" "$(EDK2_BASE_URL)/DEBUGX64_OVMF_CODE.fd"; \
	fget "$(EDK2_ABS)/DEBUGX64_OVMF_VARS.fd" "$(EDK2_BASE_URL)/DEBUGX64_OVMF_VARS.fd"; \
	fget "$(EDK2_ABS)/DEBUGAARCH64_QEMU_EFI.fd" "$(EDK2_BASE_URL)/DEBUGAARCH64_QEMU_EFI.fd"; \
	fget "$(EDK2_ABS)/DEBUGAARCH64_QEMU_VARS.fd" "$(EDK2_BASE_URL)/DEBUGAARCH64_QEMU_VARS.fd"; \
	mkdir -p "$(LOONGARCH_FW_ABS)"; \
	fget "$(LOONGARCH_FW_ABS)/QEMU_EFI.fd" "https://raw.githubusercontent.com/loongson/Firmware/main/LoongArchVirtMachine/QEMU_EFI.fd"; \
	fget "$(LOONGARCH_FW_ABS)/QEMU_VARS.fd" "https://raw.githubusercontent.com/loongson/Firmware/main/LoongArchVirtMachine/QEMU_VARS.fd"
	@echo "Done."

clean:
	rm -rf zig-out .zig-cache

distclean: clean
	rm -rf "$(ESP_ABS)"

help:
	@echo "ZirconOS Classic — targets"
	@echo "  make / make run     构建 kernel+uefi，QEMU UEFI 启动（默认；固件见 edk2-nightly）"
	@echo "  make build          仅 zig build（不启动 QEMU）"
	@echo "  make kernel         仅构建 kernel.elf"
	@echo "  make uefi           仅构建 UEFI ZBM（ARCH 需 x86_64 或 aarch64）"
	@echo "  make fetch-edk2     预下载 x86/aarch64 EDK2 Nightly + LoongArch virt 固件（龙芯官方）"
	@echo "  make zbm            ZBM 静态库（x86_64 宿主）"
	@echo "  make zbm-loongarch-uefi  LoongArch ZBM 目标文件（.o）"
	@echo "  make loongarch-efi   LoongArch BOOTLOONGARCH64.EFI（需 GNU-EFI + 交叉 gcc）"
	@echo "  make clean          删除 zig-out 与 .zig-cache"
	@echo "  make distclean      clean + 删除 QEMU ESP 目录 ($(ESP_ROOT))"
	@echo ""
	@echo "配置: 编辑 build.conf；固件说明见 firmware/edk2-nightly/README.md"
	@echo "当前: ARCH=$(ARCH) DEBUG=$(DEBUG) DESKTOP=$(DESKTOP) QEMU_MEM=$(QEMU_MEM)"
	@echo "      EDK2_NIGHTLY_DIR=$(EDK2_NIGHTLY_DIR) BOOT_METHOD=$(BOOT_METHOD)"
	@echo "make run 支持 ARCH: x86_64 | aarch64 | loongarch64（loongarch 需 qemu-system-loongarch64 + make loongarch-efi）"
