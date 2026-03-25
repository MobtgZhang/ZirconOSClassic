//! 交互会话主循环：GRE 初始化、消息泵、定时刷新任务栏时钟。

const builtin = @import("builtin");
const arch = @import("../../arch.zig");
const klog = @import("../../rtl/klog.zig");
const boot = @import("../../boot/multiboot2.zig");
const fb = @import("../../hal/fb_console.zig");
const ke_timer = @import("../../ke/timer.zig");
const theme_mod = @import("theme.zig");
const ntuser = @import("ntuser.zig");
const ntgdi = @import("ntgdi.zig");
const cursor_overlay = @import("cursor_overlay.zig");
const shell_click = @import("shell_click.zig");

var pump_rr: usize = 0;
var timer_ticks: u64 = 0;

pub fn bootstrapFromBootInfo(bi: boot.BootInfo) void {
    var t = bi.desktop_theme;
    if (t == .none) t = .ntclassic;
    theme_mod.setFromBoot(t);
    if (!fb.isReady()) return;
    ntuser.init();
    drainPaintMessages();
    klog.info("DESKTOP: session bootstrap (theme=%u)", .{@intFromEnum(theme_mod.active)});
}

pub fn drainPaintMessages() void {
    pump_rr = 0;
    var guard: usize = 0;
    while (guard < 128) : (guard += 1) {
        const m = ntuser.popMessageRoundRobin(&pump_rr) orelse break;
        if (m.msg == .wm_paint) {
            ntgdi.defWindowProc(m.hwnd, m.msg, m.wparam, m.lparam);
        }
    }
}

fn pointerPos() struct { x: i32, y: i32 } {
    if (builtin.target.cpu.arch == .x86_64) {
        const ps2 = @import("../../hal/x86_64/ps2_mouse.zig");
        return .{ .x = ps2.pos_x, .y = ps2.pos_y };
    }
    if (builtin.target.cpu.arch == .loongarch64) {
        const hid = @import("../../hal/loongarch64/virtio_hid.zig");
        hid.syncPointerWithFramebuffer();
        return .{ .x = hid.pos_x, .y = hid.pos_y };
    }
    return .{
        .x = @as(i32, @intCast(fb.screenWidth() / 2)),
        .y = @as(i32, @intCast(fb.screenHeight() / 2)),
    };
}

pub fn pumpDesktop() void {
    shell_click.pumpStartMenuTimers();

    if (builtin.target.cpu.arch == .x86_64) {
        const ps2 = @import("../../hal/x86_64/ps2_mouse.zig");
        ps2.poll();
        // 指针由 cursor_overlay.present 单独擦/画，勿在每次移动时整屏 WM_PAINT（会严重闪屏）。
        _ = ps2.consumeMoved();
        if (fb.isReady() and ntuser.isStartMenuOpen()) {
            shell_click.pumpStartMenuPointers(ps2.pos_x, ps2.pos_y);
        }
        if (ps2.leftPressedEdge()) shell_click.handleLeftDown(ps2.pos_x, ps2.pos_y);
        if (ps2.rightPressedEdge()) shell_click.handleRightDown(ps2.pos_x, ps2.pos_y);
        shell_click.pumpWelcomeDrag(ps2.pos_x, ps2.pos_y, ps2.btn_left);
    }
    if (builtin.target.cpu.arch == .loongarch64) {
        const hid = @import("../../hal/loongarch64/virtio_hid.zig");
        hid.poll();
        _ = hid.consumeMoved();
        if (fb.isReady() and ntuser.isStartMenuOpen()) {
            shell_click.pumpStartMenuPointers(hid.pos_x, hid.pos_y);
        }
        if (hid.leftPressedEdge()) shell_click.handleLeftDown(hid.pos_x, hid.pos_y);
        if (hid.rightPressedEdge()) shell_click.handleRightDown(hid.pos_x, hid.pos_y);
        shell_click.pumpWelcomeDrag(hid.pos_x, hid.pos_y, hid.btn_left);
    }

    pump_rr = 0;
    var guard: usize = 0;
    while (guard < 64) : (guard += 1) {
        const m = ntuser.popMessageRoundRobin(&pump_rr) orelse break;
        switch (m.msg) {
            .wm_paint => ntgdi.defWindowProc(m.hwnd, m.msg, m.wparam, m.lparam),
            .wm_keydown => {
                const k: u32 = @truncate(m.wparam);
                if (ntuser.isStartMenuOpen() and shell_click.startMenuHandleKeyDown(k)) {} else ntuser.onVirtualKeyDown(k);
            },
            .wm_keyup => ntuser.onVirtualKeyUp(@truncate(m.wparam)),
            else => {},
        }
    }
}

pub fn onTimerIrq() void {
    if (!fb.isReady()) return;
    timer_ticks +%= 1;
    const hz = ke_timer.getHz();
    if (hz > 0 and timer_ticks % hz == 0) {
        ntuser.invalidateWindow(ntuser.HWND_TASKBAR);
    }
}

/// P5 之后主循环：消息泵 + 低功耗等待中断（x86_64 / AArch64）。
///
/// **LoongArch64（QEMU virt）**：本机未接 PS/2 键鼠 IRQ；`virtio-keyboard/mouse-pci` 仅通过 virtqueue
/// 写内存，**不会**因移动鼠标产生能唤醒 `idle` 的中断。若此处像 x86 一样在每次刷新后 `waitForInterrupt()`，
/// 主循环只跑第一帧，指针坐标永远不更新。因此在 LA 上持续轮询（与 x86 在 `pumpDesktop` 里调用 `ps2.poll()` 的
/// “主动收包”思路一致；x86 另有 IRQ1/12 可唤醒 HLT）。
pub fn runSessionLoop() noreturn {
    klog.info("DESKTOP: entering session loop (GRE pump + WFI/HLT)", .{});
    while (true) {
        pumpDesktop();
        if (fb.isReady()) {
            const p = pointerPos();
            cursor_overlay.present(p.x, p.y);
        }
        if (builtin.target.cpu.arch == .loongarch64) {
            @import("../../hal/loongarch64/virtio_gpu.zig").flushScanoutIfActive();
            // 不得在此 `idle` 等 virtio 输入：无 MSI 时事件只进 RAM，CPU 会永远睡死。
            continue;
        }
        arch.impl.waitForInterrupt();
    }
}
