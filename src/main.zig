//! ZirconOS Classic — 混合内核（ntoskrnl）入口。
//! 目录布局对齐 [ZirconOS](https://github.com/MobtgZhang/ZirconOS) `src/`；实现按阶段自上游移植。
const builtin = @import("builtin");
const std = @import("std");
const arch = @import("arch.zig");
const klog = @import("rtl/klog.zig");
const sysconfig = @import("config/config.zig");
const mm_mod = @import("mm/mod.zig");
const ob_mod = @import("ob/mod.zig");
const ps_mod = @import("ps/mod.zig");
const ke_sync = @import("ke/sync.zig");
const io_mod = @import("io/mod.zig");
const lpc_mod = @import("lpc/mod.zig");
const fs_mod = @import("fs/mod.zig");
const loader_mod = @import("loader/mod.zig");
const smss_mod = @import("servers/smss.zig");
const csrss_mod = @import("servers/csrss.zig");
const se_mod = @import("se/mod.zig");

const gre_early = if (builtin.target.cpu.arch == .x86_64 or
    builtin.target.cpu.arch == .aarch64 or
    builtin.target.cpu.arch == .loongarch64)
    @import("subsystems/zircon64/gre_early.zig")
else
    struct {
        pub fn initAfterBoot(_: u32, _: usize) void {}
    };

pub const panic = std.debug.FullPanic(panicImpl);

fn panicImpl(msg: []const u8, _: ?usize) noreturn {
    arch.impl.consoleWrite("ZirconOS Classic: KERNEL PANIC: ");
    arch.impl.consoleWrite(msg);
    arch.impl.consoleWrite("\r\n");
    arch.impl.halt();
}

extern const stack_top: u8;

comptime {
    switch (builtin.target.cpu.arch) {
        .aarch64 => _ = @import("arch/aarch64/mod.zig"),
        .riscv64 => _ = @import("arch/riscv64/mod.zig"),
        .loongarch64 => _ = @import("arch/loongarch64/mod.zig"),
        .mips64el => _ = @import("arch/mips64el/mod.zig"),
        .x86_64 => {
            _ = @import("arch/x86_64/mod.zig");
            _ = @import("arch/x86_64/zircon_syscall_table.zig");
        },
        else => {},
    }
    if (builtin.target.cpu.arch == .x86_64 or
        builtin.target.cpu.arch == .aarch64 or
        builtin.target.cpu.arch == .loongarch64)
    {
        _ = @import("subsystems/zircon64/mod.zig");
    }
    _ = @import("config/config.zig");
    _ = @import("config/defaults.zig");
    _ = @import("ke/mod.zig");
    _ = @import("mm/mod.zig");
    _ = @import("ob/mod.zig");
    _ = @import("ps/mod.zig");
    _ = @import("se/mod.zig");
    _ = @import("io/mod.zig");
    _ = @import("lpc/mod.zig");
    _ = @import("fs/mod.zig");
    _ = @import("boot/zircon_boot_context.zig");
    _ = @import("loader/mod.zig");
    _ = @import("libs/ntdll.zig");
    _ = @import("libs/zircon64_kernel_api.zig");
    _ = @import("libs/zircon64_user_api.zig");
    _ = @import("libs/zircon64_gdi_api.zig");
    _ = @import("classic/resources/mod.zig");
    _ = @import("servers/server.zig");
    _ = @import("servers/smss.zig");
    _ = @import("servers/csrss.zig");
    _ = @import("drivers/video/mod.zig");
    _ = @import("rtl/klog.zig");
}

/// Multiboot2 (x86_64) 或 UEFI/裸机桩参数。
pub export fn kernel_main(magic: u32, info_addr: usize) callconv(.c) noreturn {
    if (builtin.target.cpu.arch == .loongarch64) {
        const la = @import("arch/loongarch64/mod.zig");
        la.applyCrmdCachedDa();
        la.parkSecondaryCpusIfNeeded();
    }
    arch.impl.initSerial();
    sysconfig.init();

    klog.info("================================================================================", .{});
    klog.info("  %s — %s", .{ sysconfig.productName(), "ntoskrnl Phase 0–11 scaffold" });
    klog.info("  Architecture: %s", .{arch.impl.name});
    klog.info("  Layout: src/ per ZirconOS (NT 5.0 product line)", .{});
    klog.info("================================================================================", .{});

    if (builtin.target.cpu.arch == .x86_64 or
        builtin.target.cpu.arch == .aarch64 or
        builtin.target.cpu.arch == .loongarch64)
    {
        startMultibootKernel(magic, info_addr);
    } else {
        startGeneric(magic, info_addr);
    }
}

/// x86_64 / AArch64 / LoongArch64：ZBM（UEFI）提供 Multiboot2 兼容信息块。
fn startMultibootKernel(magic: u32, info_addr: usize) noreturn {
    const boot = arch.impl.boot;
    const frame_mod = @import("mm/frame.zig");
    const heap_mod = @import("mm/heap.zig");

    if (magic != boot.MULTIBOOT2_BOOTLOADER_MAGIC) {
        klog.err("Invalid multiboot2 magic: 0x%x (expected 0x%x)", .{ magic, boot.MULTIBOOT2_BOOTLOADER_MAGIC });
        arch.impl.halt();
    }

    const kernel_stack_addr = @intFromPtr(&stack_top);
    if (@hasDecl(arch.impl, "initGdt")) {
        arch.impl.initGdt(kernel_stack_addr);
        klog.info("Phase 1: GDT/TSS initialized (kernel stack=0x%x)", .{kernel_stack_addr});
    }

    if (builtin.target.cpu.arch == .x86_64) {
        @import("hal/x86_64/cpu_extensions.zig").initAfterPagingReady();
    }

    const stack_top_addr = @intFromPtr(&stack_top);
    const kernel_end = ((stack_top_addr + (4 * 1024 * 1024) - 1) / (4 * 1024 * 1024)) * (4 * 1024 * 1024);
    const boot_info = boot.parse(magic, info_addr);
    if (boot_info) |bi| {
        @import("boot/zircon_boot_context.zig").setFromMultiboot2(bi);
        if (bi.acpi_rsdp_phys) |rp| {
            klog.info("Phase 1: ACPI RSDP (Multiboot2 tag) at phys 0x%x", .{rp});
        }
    }

    if (builtin.target.cpu.arch == .x86_64) {
        @import("hal/x86_64/acpi_early.zig").validateAndLogFromBootContext();
        @import("hal/x86_64/lapic_early.zig").enableLocalApic();
        @import("hal/x86_64/hpet_probe.zig").logStub();
        @import("hal/x86_64/lapic_timer_stub.zig").logTimerStub();
        @import("hal/x86_64/pci_ecam.zig").initStubFromMcfg();
        @import("arch/x86_64/zircon_syscall_table.zig").initExecutive();
    }

    var frame_alloc: frame_mod.FrameAllocator = undefined;
    frame_alloc.init(boot_info, kernel_end, info_addr);
    klog.info("Phase 1: Frame allocator init (total=%u frames)", .{frame_alloc.total_frames});

    heap_mod.init();
    klog.info("Phase 1: Heap init (%u KB)", .{heap_mod.totalBytes() / 1024});

    mm_mod.initExecutive(&frame_alloc);
    ob_mod.initExecutive();
    ps_mod.initExecutive();
    ke_sync.initExecutive();
    se_mod.initExecutive();

    // LoongArch：先 ramfb（fw_cfg）；若无线性 FB 再试 virtio-gpu（`execGpu` 有自旋上限，TCG 下仍可能略慢）。
    // 另有 UEFI GOP → Multiboot2 tag 8，由 `gre_early` 设置。
    if (builtin.target.cpu.arch == .loongarch64) {
        const la_ramfb = @import("hal/loongarch64/ramfb.zig");
        _ = la_ramfb.tryInitFramebuffer();
        if (!@import("hal/fb_console.zig").isReady()) {
            @import("hal/loongarch64/virtio_gpu.zig").tryInitQemuVirtioGpuFramebuffer();
        }
    }
    if (builtin.target.cpu.arch == .x86_64) {
        @import("hal/display/bootstrap.zig").tryInitEarlyDisplay();
    }

    if (@import("build_options").enable_idt and @hasDecl(arch.impl, "initIdt")) {
        arch.impl.initIdt();
        klog.info("Phase 2: IDT initialized (48 vectors)", .{});
    }

    if (@import("build_options").enable_idt) {
        const timer_mod = @import("ke/timer.zig");
        const scheduler_mod = @import("ke/scheduler.zig");
        scheduler_mod.init();
        timer_mod.init();
        klog.info("Phase 2: Scheduler + Timer ready", .{});
        if (builtin.target.cpu.arch == .x86_64) {
            @import("hal/x86_64/ps2_mouse.zig").init();
            @import("hal/x86_64/ps2_keyboard.zig").init();
        }
        if (@hasDecl(arch.impl, "enableInterrupts")) {
            arch.impl.enableInterrupts();
            klog.info("Phase 2: Interrupts enabled", .{});
        }
    }

    io_mod.initExecutive();
    @import("drivers/video/mod.zig").initStub();
    lpc_mod.initExecutive();
    fs_mod.initExecutive();
    loader_mod.initExecutive();
    smss_mod.runBootstrapSequence();
    csrss_mod.initStub();

    gre_early.initAfterBoot(magic, info_addr);

    if (builtin.target.cpu.arch == .loongarch64) {
        // GRE 可能用 Multiboot2 GOP 覆盖 ramfb 尺寸/地址后再同步指针；键鼠 PCI 与 FB 解耦，放 GRE 之后更稳。
        @import("hal/loongarch64/virtio_hid.zig").Input.init();
    }

    if (@import("build_options").enable_idt) {
        const sched = @import("ke/scheduler.zig");
        sched.enableScheduling();
    }

    if (builtin.target.cpu.arch == .x86_64 or builtin.target.cpu.arch == .aarch64) {
        if (@import("build_options").enable_idt) {
            klog.info("Phase P5+: GRE desktop session (SMSS→CSRSS, int-driven clock)", .{});
            const desktop_session = @import("subsystems/zircon64/desktop_session.zig");
            desktop_session.runSessionLoop();
        }
    } else if (builtin.target.cpu.arch == .loongarch64) {
        const fb = @import("hal/fb_console.zig");
        // LoongArch：CSR 定时器中断里 poll virtio-input，主循环 `idle` 可低功耗唤醒。
        if (fb.isReady()) {
            klog.info("Phase P5+: LoongArch64 GRE desktop (ramfb/virtio-gpu + timer IRQ + virtio-hid)", .{});
            const desktop_session = @import("subsystems/zircon64/desktop_session.zig");
            desktop_session.runSessionLoop();
        }
        if (!fb.isReady()) {
            klog.info("Phase P5: LoongArch64: no linear framebuffer — QEMU 请加 `-device ramfb` 或 virtio-gpu-pci（见 qemu_run.sh）；仅串口时 WFI idle。", .{});
        }
        while (true) {
            arch.impl.waitForInterrupt();
        }
    }

    klog.info("Phase P5: GRE idle (no IDT or non-Multiboot arch). Halting.", .{});
    arch.impl.halt();
}

fn startGeneric(magic: u32, info_addr: usize) noreturn {
    _ = magic;
    _ = info_addr;
    klog.info("Generic arch: stub boot path. Halting.", .{});
    arch.impl.halt();
}
