//! 交互会话主循环：GRE 初始化、消息泵、定时刷新任务栏时钟。
//! 指针：`pointer_input.zig` 统一 PS/2 与 VirtIO-input；软件光标绘制见 `cursor_overlay.zig`（写入当前 `fb_console` 后再 virtio-gpu flush）。

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
const pointer_input = @import("pointer_input.zig");

var pump_rr: usize = 0;
var timer_ticks: u64 = 0;
/// 与 `arch/loongarch64/mod.zig` 的 `loongarch_timer_ticks` 对齐，用于在主线程泵里调用 `onTimerIrq`。
var loongarch_timer_seen: u64 = 0;

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

fn pointerPos() pointer_input.Point {
    return pointer_input.clampedPosition();
}

pub fn pumpDesktop() void {
    shell_click.pumpStartMenuTimers();

    if (builtin.target.cpu.arch == .loongarch64) {
        const la = @import("../../arch/loongarch64/mod.zig");
        while (loongarch_timer_seen < la.loongarch_timer_ticks) : (loongarch_timer_seen += 1) {
            onTimerIrq();
        }
    }

    pointer_input.poll();
    // 指针由 cursor_overlay.present 单独擦/画，勿在每次移动时整屏 WM_PAINT（会严重闪屏）。
    _ = pointer_input.consumeMoved();
    const ptr = pointer_input.clampedPosition();
    if (fb.isReady() and ntuser.isStartMenuOpen()) {
        shell_click.pumpStartMenuPointers(ptr.x, ptr.y);
    }
    if (pointer_input.leftPressedEdge()) shell_click.handleLeftDown(ptr.x, ptr.y);
    if (pointer_input.rightPressedEdge()) shell_click.handleRightDown(ptr.x, ptr.y);
    shell_click.pumpWelcomeDrag(ptr.x, ptr.y, pointer_input.btnLeft());

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
/// **LoongArch64**：`virtio-input` 无可靠 MSI 唤醒时，**必须**在主线程里持续 `poll`（见 `pumpDesktop` / 本循环末尾），
/// 不能依赖 `idle` 等定时器——CSR 定时器在部分环境不触发会导致整桌卡死、鼠标看似「不动」。
/// 定时器仍可在 IRQ 里额外 `poll`，任务栏时钟由 `loongarch_timer_ticks` 在泵里消费。
///
/// **可见性**：须先向当前 `fb_console` 画软件光标，再 `flushScanoutIfActive`，否则 virtio-gpu 扫描的是未含光标的后备缓冲。
pub fn runSessionLoop() noreturn {
    klog.info("DESKTOP: entering session loop", .{});
    while (true) {
        pumpDesktop();
        if (fb.isReady()) {
            const p = pointerPos();
            cursor_overlay.present(p.x, p.y);
        }
        if (builtin.target.cpu.arch == .loongarch64) {
            @import("../../hal/loongarch64/virtio_gpu.zig").flushScanoutIfActive();
            pointer_input.poll();
            continue;
        }
        if (builtin.target.cpu.arch == .x86_64) {
            @import("../../hal/x86_64/virtio_gpu.zig").flushScanoutIfActive();
        }
        arch.impl.waitForInterrupt();
    }
}
