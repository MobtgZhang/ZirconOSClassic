//! QEMU `virtio-keyboard-pci` + `virtio-mouse-pci`（PCI 1af4:1052，VIRTIO_ID_INPUT）。
//!
//! **QEMU 命令行**：若同时有 `ramfb` 与 `virtio-gpu-pci`，须为键鼠指定 `display=<virtio-gpu-pci 的 id>`，
//! 否则 QEMU 不把 UI 指针事件绑到可见 console，驱动侧 virtqueue 会一直空闲（见 `scripts/qemu_run.sh`）。
//!
//! 要点（此前版本无输入的原因）：
//! - **禁止**在 `evt_used` 已清零前读 `used.idx` 作为 `last_used`，否则为未初始化垃圾值，永远无法与设备写入的 idx 对齐。
//! - QEMU 中 evt/sts 两队列默认长度均为 **64**（见 `hw/input/virtio-input.c`），sts 若只建 8 项可能与设备假设不一致。
//! - **按事件类型分发**（REL / BTN_* / 其它 KEY）：为每个 `1af4:1052` 各建一套 vring 并轮询，不依赖「哪个 PCI 是键盘」的枚举顺序。
//! - TCG 下 virtio 通知常走 BH：在 `poll`/`drain` 中周期性读 common **STATUS** MMIO，迫使退出翻译块（与 virtio-gpu 相同思路）。

const builtin = @import("builtin");
const std = @import("std");
const dfs = @import("../../config/desktop_fb.zig");
const klog = @import("../../rtl/klog.zig");
const fb = @import("../fb_console.zig");
const ntuser = @import("../../subsystems/win32/ntuser.zig");
const dcache = @import("dcache.zig");

comptime {
    if (builtin.target.cpu.arch != .loongarch64) {
        @compileError("virtio_hid.zig is LoongArch64-only");
    }
}

const VIRT_PCI_CFG_BASE: usize = 0x2000_0000;
const VIRTIO_PCI_VENDOR: u16 = 0x1af4;
const VIRTIO_INPUT_DEVICE_MODERN: u16 = 0x1052;

const PCI_CAP_VENDOR: u8 = 0x09;
const VIRTIO_PCI_CAP_COMMON_CFG: u8 = 1;
const VIRTIO_PCI_CAP_NOTIFY_CFG: u8 = 2;
const VIRTIO_PCI_CAP_DEVICE_CFG: u8 = 4;

const VIRTIO_CONFIG_S_ACKNOWLEDGE: u8 = 1;
const VIRTIO_CONFIG_S_DRIVER: u8 = 2;
const VIRTIO_CONFIG_S_DRIVER_OK: u8 = 4;
const VIRTIO_CONFIG_S_FEATURES_OK: u8 = 8;
const VIRTIO_F_VERSION_1: u64 = 1 << 32;

const VIRTQ_DESC_F_WRITE: u16 = 2;

const VIRTIO_PCI_COMMON_DFSELECT: usize = 0;
const VIRTIO_PCI_COMMON_DF: usize = 4;
const VIRTIO_PCI_COMMON_GFSELECT: usize = 8;
const VIRTIO_PCI_COMMON_GF: usize = 12;
const VIRTIO_PCI_COMMON_STATUS: usize = 20;
const VIRTIO_PCI_COMMON_Q_SELECT: usize = 22;
const VIRTIO_PCI_COMMON_Q_SIZE: usize = 24;
const VIRTIO_PCI_COMMON_Q_ENABLE: usize = 28;
const VIRTIO_PCI_COMMON_Q_NOFF: usize = 30;
const VIRTIO_PCI_COMMON_Q_DESCLO: usize = 32;
const VIRTIO_PCI_COMMON_Q_DESCHI: usize = 36;
const VIRTIO_PCI_COMMON_Q_AVAILLO: usize = 40;
const VIRTIO_PCI_COMMON_Q_AVAILHI: usize = 44;
const VIRTIO_PCI_COMMON_Q_USEDLO: usize = 48;
const VIRTIO_PCI_COMMON_Q_USEDHI: usize = 52;

// Linux input uapi
const EV_SYN: u16 = 0x00;
const EV_KEY: u16 = 0x01;
const EV_REL: u16 = 0x02;
const KEY_ESC: u16 = 1;
const KEY_1: u16 = 2;
const KEY_9: u16 = 10;
const KEY_0: u16 = 11;
const KEY_BACKSPACE: u16 = 14;
const KEY_TAB: u16 = 15;
const KEY_Q: u16 = 16;
const KEY_P: u16 = 25;
const KEY_ENTER: u16 = 28;
const KEY_LEFTCTRL: u16 = 29;
const KEY_A: u16 = 30;
const KEY_Z: u16 = 44;
const KEY_LEFTSHIFT: u16 = 42;
const KEY_RIGHTSHIFT: u16 = 54;
const KEY_SPACE: u16 = 57;
const KEY_F1: u16 = 59;
const KEY_F12: u16 = 70;
const KEY_UP: u16 = 103;
const KEY_LEFT: u16 = 105;
const KEY_RIGHT: u16 = 106;
const KEY_DOWN: u16 = 108;
const KEY_LEFTMETA: u16 = 125;
const KEY_RIGHTMETA: u16 = 126;
const BTN_LEFT: u16 = 0x110;
const BTN_RIGHT: u16 = 0x111;
const BTN_MIDDLE: u16 = 0x112;

const VirtioInputEvent = extern struct {
    type: u16,
    code: u16,
    value: u32,
};

const VringDesc = extern struct {
    addr: u64,
    len: u32,
    flags: u16,
    next: u16,
};

const VringUsedElem = extern struct {
    id: u32,
    len: u32,
};

/// QEMU `virtio_add_queue(..., 64, ...)` 对 evt 与 sts 均为 64。
const Q_EVT: usize = 64;
const Q_STS: usize = 64;

fn VringAvail(comptime qn: usize) type {
    return extern struct {
        flags: u16,
        idx: u16,
        ring: [qn]u16,
        used_event: u16,
    };
}

fn VringUsed(comptime qn: usize) type {
    return extern struct {
        flags: u16,
        idx: u16,
        ring: [qn]VringUsedElem,
        avail_event: u16,
    };
}

const VringAvailEvt = VringAvail(Q_EVT);
const VringUsedEvt = VringUsed(Q_EVT);
const VringAvailSts = VringAvail(Q_STS);
const VringUsedSts = VringUsed(Q_STS);

const CapInfo = struct {
    common_bar: u8,
    common_off: u32,
    notify_bar: u8,
    notify_off: u32,
    notify_mul: u32,
    device_bar: u8 = 0,
    device_off: u32 = 0,
    has_device: bool = false,
};

const PciLoc = struct { bus: u8, dev: u8, func: u8 };

/// 最多枚举到的 virtio-input PCI 功能数（键盘 + 鼠标各一，留余量给将来设备）。
const MAX_INPUT_DEVS: usize = 4;

pub var pos_x: i32 = @intCast(dfs.width / 2);
pub var pos_y: i32 = @intCast(dfs.height / 2);
pub var btn_left: bool = false;
pub var btn_right: bool = false;
pub var btn_middle: bool = false;
var left_was_down: bool = false;
var right_was_down: bool = false;
pub var moved_since_frame: bool = false;

var hid_ready: bool = false;

/// `fb_console` 上次已知的宽高；与 `desktop_fb.zig` 或 ramfb 不一致时，GOP tag 会在 GRE 阶段覆盖 FB，
/// 若仍保留按 1280×800 算的指针坐标，在小分辨率下会被夹到右下角且看起来像「卡住不动」。
var last_pointer_fb_w: usize = 0;
var last_pointer_fb_h: usize = 0;

const InputDev = struct {
    common: usize,
    notify_evt: usize,
    evt_desc: [Q_EVT]VringDesc align(4096) = undefined,
    evt_avail: VringAvailEvt align(4096) = undefined,
    evt_used: VringUsedEvt align(4096) = undefined,
    evt_buf: [Q_EVT]VirtioInputEvent align(16) = undefined,
    sts_desc: [Q_STS]VringDesc align(4096) = undefined,
    sts_avail: VringAvailSts align(4096) = undefined,
    sts_used: VringUsedSts align(4096) = undefined,
    last_used: u16 = 0,

    fn usedIdxRead(self: *const InputDev) u16 {
        dbar();
        const p: *const volatile u16 = @ptrFromInt(@intFromPtr(&self.evt_used) + @offsetOf(VringUsedEvt, "idx"));
        return p.*;
    }

    /// 设备写 `used.ring`；须按槽 volatile 读，避免优化/缓存与 `virtio_gpu` 的 `usedIdxRead` 同理。
    fn usedElemRead(self: *const InputDev, slot: usize) VringUsedElem {
        dbar();
        const base = @intFromPtr(&self.evt_used) + @offsetOf(VringUsedEvt, "ring");
        const off = slot % Q_EVT * @sizeOf(VringUsedElem);
        const idp: *const volatile u32 = @ptrFromInt(base + off);
        const lenp: *const volatile u32 = @ptrFromInt(base + off + 4);
        return .{ .id = idp.*, .len = lenp.* };
    }
};

var input_devs: [MAX_INPUT_DEVS]InputDev = undefined;
var input_dev_count: usize = 0;

fn pciCfgAddr(bus: u8, dev: u8, func: u8, reg: usize) usize {
    return VIRT_PCI_CFG_BASE + (@as(usize, bus) << 20) + (@as(usize, dev) << 15) + (@as(usize, func) << 12) + reg;
}

fn pciRead8(bus: u8, dev: u8, func: u8, reg: usize) u8 {
    return @as(*const volatile u8, @ptrFromInt(pciCfgAddr(bus, dev, func, reg))).*;
}

fn pciRead32(bus: u8, dev: u8, func: u8, reg: usize) u32 {
    const a = pciCfgAddr(bus, dev, func, reg);
    var v: u32 = 0;
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        v |= @as(u32, @as(*const volatile u8, @ptrFromInt(a + i)).*) << @intCast(8 * i);
    }
    return v;
}

fn pciWrite32(bus: u8, dev: u8, func: u8, reg: usize, v: u32) void {
    const a = pciCfgAddr(bus, dev, func, reg);
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        @as(*volatile u8, @ptrFromInt(a + i)).* = @truncate(v >> @intCast(8 * i));
    }
}

fn mmioR32(base: usize, off: usize) u32 {
    const p = base +% off;
    var v: u32 = 0;
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        v |= @as(u32, @as(*const volatile u8, @ptrFromInt(p + i)).*) << @intCast(8 * i);
    }
    return v;
}

fn mmioW32(base: usize, off: usize, v: u32) void {
    const p = base +% off;
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        @as(*volatile u8, @ptrFromInt(p + i)).* = @truncate(v >> @intCast(8 * i));
    }
}

fn mmioW16(base: usize, off: usize, v: u16) void {
    const p = base +% off;
    @as(*volatile u8, @ptrFromInt(p)).* = @truncate(v);
    @as(*volatile u8, @ptrFromInt(p + 1)).* = @truncate(v >> 8);
}

fn mmioR16(base: usize, off: usize) u16 {
    const p = base +% off;
    const lo = @as(*const volatile u8, @ptrFromInt(p)).*;
    const hi = @as(*const volatile u8, @ptrFromInt(p + 1)).*;
    return @as(u16, lo) | (@as(u16, hi) << 8);
}

fn mmioW8(base: usize, off: usize, v: u8) void {
    @as(*volatile u8, @ptrFromInt(base +% off)).* = v;
}

fn virtioQueueNotifyWrite(notify_addr: usize) void {
    dbar();
    const a = notify_addr;
    if (a & 3 == 0) {
        @as(*volatile u32, @ptrFromInt(a)).* = 0;
    } else if (a & 1 == 0) {
        @as(*volatile u16, @ptrFromInt(a)).* = 0;
    } else {
        @as(*volatile u8, @ptrFromInt(a)).* = 0;
    }
    dbar();
}

fn dbar() void {
    asm volatile ("dbar 0" ::: .{ .memory = true });
}

fn pciBarPhys(bus: u8, dev: u8, func: u8, bar_idx: u8) ?usize {
    const reg: usize = 0x10 + @as(usize, bar_idx) * 4;
    const lo = pciRead32(bus, dev, func, reg);
    if ((lo & 1) != 0) return null;
    const typ = lo & 0x6;
    var addr: usize = @as(usize, lo & 0xFFFF_FFF0);
    if (typ == 4) {
        const hi = pciRead32(bus, dev, func, reg + 4);
        addr |= @as(usize, hi) << 32;
    }
    if (addr == 0) return null;
    return addr;
}

fn readVirtioCaps(bus: u8, dev: u8, func: u8) ?CapInfo {
    const hdr0 = pciRead32(bus, dev, func, 0);
    if ((hdr0 & 0xFFFF) == 0xFFFF) return null;
    var cap_ptr: usize = pciRead8(bus, dev, func, 0x34);
    var out = CapInfo{
        .common_bar = 0,
        .common_off = 0,
        .notify_bar = 0,
        .notify_off = 0,
        .notify_mul = 1,
    };
    var found_common = false;
    var found_notify = false;
    while (cap_ptr != 0) {
        const id = pciRead8(bus, dev, func, cap_ptr);
        const next = pciRead8(bus, dev, func, cap_ptr + 1);
        const len = pciRead8(bus, dev, func, cap_ptr + 2);
        if (id == PCI_CAP_VENDOR and len >= 16) {
            const cfg_type = pciRead8(bus, dev, func, cap_ptr + 3);
            const bar = pciRead8(bus, dev, func, cap_ptr + 4);
            const off = pciRead32(bus, dev, func, cap_ptr + 8);
            const length = pciRead32(bus, dev, func, cap_ptr + 12);
            _ = length;
            switch (cfg_type) {
                VIRTIO_PCI_CAP_COMMON_CFG => {
                    found_common = true;
                    out.common_bar = bar;
                    out.common_off = off;
                },
                VIRTIO_PCI_CAP_NOTIFY_CFG => {
                    found_notify = true;
                    out.notify_bar = bar;
                    out.notify_off = off;
                    if (len >= 20) {
                        const mul = pciRead32(bus, dev, func, cap_ptr + 16);
                        out.notify_mul = if (mul == 0) 1 else mul;
                    }
                },
                VIRTIO_PCI_CAP_DEVICE_CFG => {
                    out.has_device = true;
                    out.device_bar = bar;
                    out.device_off = off;
                },
                else => {},
            }
        }
        cap_ptr = @as(usize, next);
    }
    if (!found_common or !found_notify) return null;
    return out;
}

fn readMaxQueueSize(common: usize, q_sel: u16) u16 {
    mmioW16(common, VIRTIO_PCI_COMMON_Q_SELECT, q_sel);
    dbar();
    return mmioR16(common, VIRTIO_PCI_COMMON_Q_SIZE);
}

fn setupOneQueue(
    common: usize,
    notify_mmio: usize,
    notify_mul: u32,
    q_select: u16,
    q_size: u16,
    desc_phys: usize,
    avail_phys: usize,
    used_phys: usize,
) usize {
    mmioW16(common, VIRTIO_PCI_COMMON_Q_SELECT, q_select);
    mmioW16(common, VIRTIO_PCI_COMMON_Q_SIZE, q_size);
    mmioW32(common, VIRTIO_PCI_COMMON_Q_DESCLO, @truncate(desc_phys));
    mmioW32(common, VIRTIO_PCI_COMMON_Q_DESCHI, @truncate(desc_phys >> 32));
    mmioW32(common, VIRTIO_PCI_COMMON_Q_AVAILLO, @truncate(avail_phys));
    mmioW32(common, VIRTIO_PCI_COMMON_Q_AVAILHI, @truncate(avail_phys >> 32));
    mmioW32(common, VIRTIO_PCI_COMMON_Q_USEDLO, @truncate(used_phys));
    mmioW32(common, VIRTIO_PCI_COMMON_Q_USEDHI, @truncate(used_phys >> 32));
    mmioW16(common, VIRTIO_PCI_COMMON_Q_ENABLE, 1);
    dbar();
    const qnoff = mmioR32(common, VIRTIO_PCI_COMMON_Q_NOFF) & 0xFFFF;
    return notify_mmio + @as(usize, qnoff) * @as(usize, notify_mul);
}

fn linuxKeyToVk(code: u16) ?u32 {
    return switch (code) {
        KEY_ESC => 0x1B,
        KEY_TAB => 0x09,
        KEY_ENTER => 0x0D,
        KEY_SPACE => 0x20,
        KEY_BACKSPACE => 0x08,
        KEY_LEFTMETA, KEY_RIGHTMETA => 0x5B,
        KEY_LEFT => 0x25,
        KEY_UP => 0x26,
        KEY_RIGHT => 0x27,
        KEY_DOWN => 0x28,
        KEY_LEFTSHIFT, KEY_RIGHTSHIFT => 0x10,
        KEY_LEFTCTRL => 0x11,
        else => blk: {
            if (code >= KEY_A and code <= KEY_Z) {
                break :blk @as(u32, 'A' + (code - KEY_A));
            }
            if (code >= KEY_1 and code <= KEY_9) {
                break :blk @as(u32, '1' + (code - KEY_1));
            }
            if (code == KEY_0) break :blk @as(u32, '0');
            if (code >= KEY_F1 and code <= KEY_F12) {
                break :blk @as(u32, 0x70 + (code - KEY_F1));
            }
            if (code >= KEY_Q and code <= KEY_P) {
                const row: *const [10:0]u8 = "qwertyuiop";
                const idx: usize = @intCast(code - KEY_Q);
                break :blk @as(u32, std.ascii.toUpper(row[idx]));
            }
            break :blk null;
        },
    };
}

/// 与 x86 PS/2 按「包内容」处理一致：不按 PCI 功能猜角色，避免枚举顺序把键鼠对调后 REL 被丢。
fn dispatchVirtioInputEvent(ev: *const VirtioInputEvent) void {
    switch (ev.type) {
        EV_SYN => {},
        EV_REL => handleMouseEvent(ev),
        EV_KEY => {
            const c = ev.code;
            if (c == BTN_LEFT or c == BTN_RIGHT or c == BTN_MIDDLE) {
                handleMouseEvent(ev);
            } else {
                handleKbdEvent(ev);
            }
        },
        else => {},
    }
}

fn handleKbdEvent(ev: *const VirtioInputEvent) void {
    const t = ev.type;
    const c = ev.code;
    const v = ev.value;
    if (t == EV_SYN) return;
    if (t != EV_KEY) return;
    if (linuxKeyToVk(c)) |vk| {
        if (v != 0) {
            _ = ntuser.postKeyDownToDesktop(vk);
        } else {
            _ = ntuser.postKeyUpToDesktop(vk);
        }
    }
}

fn readInputEventVolatile(buf: *const VirtioInputEvent) VirtioInputEvent {
    dbar();
    const p: [*]const volatile u8 = @ptrCast(buf);
    var e: VirtioInputEvent = undefined;
    var i: usize = 0;
    while (i < @sizeOf(VirtioInputEvent)) : (i += 1) {
        @as([*]u8, @ptrCast(&e))[i] = p[i];
    }
    return e;
}

fn handleMouseEvent(ev: *const VirtioInputEvent) void {
    const t = ev.type;
    const c = ev.code;
    const v: i32 = @bitCast(ev.value);
    if (t == EV_SYN) return;

    if (t == EV_REL) {
        // 与 `ps2_mouse.zig` 相同：**水平** `pos_x += dx`。垂直：Linux evdev 的 REL_Y 正值=光标下移
        //（帧缓冲 Y 向下）；PS/2 包内 dy 符号与此相反故 `ps2_mouse` 用 `pos_y -= dy`。virtio-input 走 evdev 语义，用 `+=`。
        if (c == 0) {
            pos_x += v;
            moved_since_frame = true;
        } else if (c == 1) {
            pos_y += v;
            moved_since_frame = true;
        }
        const sw: i32 = @intCast(fb.screenWidth());
        const sh: i32 = @intCast(fb.screenHeight());
        if (pos_x < 0) pos_x = 0;
        if (pos_y < 0) pos_y = 0;
        if (pos_x >= sw) pos_x = sw - 1;
        if (pos_y >= sh) pos_y = sh - 1;
        return;
    }
    if (t == EV_KEY) {
        const down = v != 0;
        if (c == BTN_LEFT) btn_left = down;
        if (c == BTN_RIGHT) btn_right = down;
        if (c == BTN_MIDDLE) btn_middle = down;
    }
}

fn flushEvtAvail(dev: *InputDev) void {
    dcache.syncToDevice(@intFromPtr(&dev.evt_avail), @sizeOf(VringAvailEvt));
}

fn flushEvtDesc(dev: *InputDev) void {
    dcache.syncToDevice(@intFromPtr(&dev.evt_desc), @sizeOf([Q_EVT]VringDesc));
}

fn syncFromEvtUsed(dev: *InputDev) void {
    dcache.syncFromDevice(@intFromPtr(&dev.evt_used), @sizeOf(VringUsedEvt));
}

fn syncFromEvtBuf(dev: *InputDev, id: usize) void {
    dcache.syncFromDevice(@intFromPtr(&dev.evt_buf[id]), @sizeOf(VirtioInputEvent));
}

/// 在提交 avail 前把整个 `InputDev` 的 vring 与缓冲清零，并令 `last_used = 0`（与 `used.idx`==0 一致）。
fn zeroInputVrings(dev: *InputDev) void {
    @memset(std.mem.asBytes(&dev.evt_desc), 0);
    @memset(std.mem.asBytes(&dev.evt_avail), 0);
    @memset(std.mem.asBytes(&dev.evt_used), 0);
    @memset(std.mem.asBytes(&dev.evt_buf), 0);
    @memset(std.mem.asBytes(&dev.sts_desc), 0);
    @memset(std.mem.asBytes(&dev.sts_avail), 0);
    @memset(std.mem.asBytes(&dev.sts_used), 0);
    dev.last_used = 0;
}

fn postInitialEvtBuffers(dev: *InputDev) void {
    var i: usize = 0;
    while (i < Q_EVT) : (i += 1) {
        const p = @intFromPtr(&dev.evt_buf[i]);
        dev.evt_desc[i] = .{
            .addr = p,
            .len = @sizeOf(VirtioInputEvent),
            .flags = VIRTQ_DESC_F_WRITE,
            .next = 0,
        };
    }
    i = 0;
    while (i < Q_EVT) : (i += 1) {
        dev.evt_avail.ring[i] = @truncate(i);
    }
    dev.evt_avail.idx = @truncate(Q_EVT);
    dbar();
    flushEvtDesc(dev);
    flushEvtAvail(dev);
    virtioQueueNotifyWrite(dev.notify_evt);
}

fn drainDevice(dev: *InputDev) void {
    var iter: u32 = 0;
    while (iter < 4096) : (iter += 1) {
        _ = mmioR32(dev.common, VIRTIO_PCI_COMMON_STATUS);

        syncFromEvtUsed(dev);
        const used_head = dev.usedIdxRead();
        if (used_head == dev.last_used) break;

        const slot = @as(usize, @intCast(dev.last_used % Q_EVT));
        const elem = dev.usedElemRead(slot);
        dev.last_used +%= 1;

        const id = @as(usize, @intCast(elem.id));
        if (id >= Q_EVT) continue;
        syncFromEvtBuf(dev, id);
        const ev_copy = readInputEventVolatile(&dev.evt_buf[id]);
        dispatchVirtioInputEvent(&ev_copy);

        const av: *volatile VringAvailEvt = @ptrCast(&dev.evt_avail);
        const s = @as(usize, av.idx) % Q_EVT;
        av.ring[s] = @truncate(id);
        av.idx = av.idx +% 1;
        dbar();
        flushEvtAvail(dev);
        virtioQueueNotifyWrite(dev.notify_evt);
    }
}

fn initInputPciInto(dev_out: *InputDev, loc: PciLoc) bool {
    const b = loc.bus;
    const d = loc.dev;
    const f = loc.func;
    const caps = readVirtioCaps(b, d, f) orelse return false;

    const cmdw = pciRead32(b, d, f, 0x04) & 0xFFFF;
    pciWrite32(b, d, f, 0x04, cmdw | 0x6);

    const common_base = pciBarPhys(b, d, f, caps.common_bar) orelse return false;
    const notify_base = pciBarPhys(b, d, f, caps.notify_bar) orelse return false;
    const common = common_base + caps.common_off;
    const notify_bar = notify_base + caps.notify_off;

    mmioW8(common, VIRTIO_PCI_COMMON_STATUS, 0);
    dbar();
    mmioW8(common, VIRTIO_PCI_COMMON_STATUS, VIRTIO_CONFIG_S_ACKNOWLEDGE | VIRTIO_CONFIG_S_DRIVER);
    dbar();
    mmioW32(common, VIRTIO_PCI_COMMON_GFSELECT, 0);
    mmioW32(common, VIRTIO_PCI_COMMON_GF, @truncate(VIRTIO_F_VERSION_1));
    mmioW32(common, VIRTIO_PCI_COMMON_GFSELECT, 1);
    mmioW32(common, VIRTIO_PCI_COMMON_GF, @truncate(VIRTIO_F_VERSION_1 >> 32));
    dbar();
    mmioW8(common, VIRTIO_PCI_COMMON_STATUS, VIRTIO_CONFIG_S_ACKNOWLEDGE | VIRTIO_CONFIG_S_DRIVER | VIRTIO_CONFIG_S_FEATURES_OK);
    dbar();
    if ((mmioR32(common, VIRTIO_PCI_COMMON_STATUS) & 0xFF) & VIRTIO_CONFIG_S_FEATURES_OK == 0) return false;

    {
        const max_evt = readMaxQueueSize(common, 0);
        const max_sts = readMaxQueueSize(common, 1);
        if (max_evt != 0 and max_evt < Q_EVT) return false;
        if (max_sts != 0 and max_sts < Q_STS) return false;
    }

    dev_out.* = .{
        .common = common,
        .notify_evt = 0,
    };
    zeroInputVrings(dev_out);

    const d_evt = @intFromPtr(&dev_out.evt_desc);
    const a_evt = @intFromPtr(&dev_out.evt_avail);
    const u_evt = @intFromPtr(&dev_out.evt_used);
    dev_out.notify_evt = setupOneQueue(common, notify_bar, caps.notify_mul, 0, Q_EVT, d_evt, a_evt, u_evt);

    const d_sts = @intFromPtr(&dev_out.sts_desc);
    const a_sts = @intFromPtr(&dev_out.sts_avail);
    const u_sts = @intFromPtr(&dev_out.sts_used);
    _ = setupOneQueue(common, notify_bar, caps.notify_mul, 1, Q_STS, d_sts, a_sts, u_sts);

    mmioW8(common, VIRTIO_PCI_COMMON_STATUS, VIRTIO_CONFIG_S_ACKNOWLEDGE | VIRTIO_CONFIG_S_DRIVER | VIRTIO_CONFIG_S_FEATURES_OK | VIRTIO_CONFIG_S_DRIVER_OK);
    dbar();

    dev_out.last_used = 0;
    postInitialEvtBuffers(dev_out);
    return true;
}

fn collectInputPci(out: *[8]PciLoc, n: *usize) void {
    n.* = 0;
    var dev: u8 = 0;
    while (dev < 32) : (dev += 1) {
        var func: u8 = 0;
        while (func < 8) : (func += 1) {
            const v0 = pciRead32(0, dev, func, 0);
            const ven = @as(u16, @truncate(v0));
            if (ven == 0xFFFF) continue;
            const did = @as(u16, @truncate(v0 >> 16));
            if (ven == VIRTIO_PCI_VENDOR and did == VIRTIO_INPUT_DEVICE_MODERN) {
                if (n.* < out.len) {
                    out[n.*] = .{ .bus = 0, .dev = dev, .func = func };
                    n.* += 1;
                }
            }
        }
    }
}

/// 在 `gre_early` 用 Multiboot2 GOP 覆盖 ramfb 后、或任意改变分辨率后调用；也可由桌面每帧通过 `pointerPos` 间接调用。
pub fn syncPointerWithFramebuffer() void {
    if (!fb.isReady()) return;
    const sw = fb.screenWidth();
    const sh = fb.screenHeight();
    if (sw == 0 or sh == 0) return;

    if (last_pointer_fb_w != sw or last_pointer_fb_h != sh) {
        last_pointer_fb_w = sw;
        last_pointer_fb_h = sh;
        pos_x = @intCast(@max(1, sw) / 2);
        pos_y = @intCast(@max(1, sh) / 2);
        return;
    }

    const swi: i32 = @intCast(sw);
    const shi: i32 = @intCast(sh);
    if (pos_x < 0) pos_x = 0;
    if (pos_y < 0) pos_y = 0;
    if (pos_x >= swi) pos_x = swi - 1;
    if (pos_y >= shi) pos_y = shi - 1;
}

pub fn init() void {
    if (hid_ready) return;

    input_dev_count = 0;
    var locs: [8]PciLoc = undefined;
    var n: usize = 0;
    collectInputPci(&locs, &n);
    if (n == 0) {
        klog.info("virtio-hid: no 1af4:1052 (add -device virtio-keyboard-pci -device virtio-mouse-pci)", .{});
        return;
    }

    if (fb.isReady()) {
        syncPointerWithFramebuffer();
    } else {
        pos_x = @intCast(dfs.width / 2);
        pos_y = @intCast(dfs.height / 2);
    }

    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (input_dev_count >= MAX_INPUT_DEVS) break;
        if (initInputPciInto(&input_devs[input_dev_count], locs[i])) {
            klog.info("virtio-hid: ok bus%u dev%u func%u", .{ locs[i].bus, locs[i].dev, locs[i].func });
            input_dev_count += 1;
        } else {
            klog.info("virtio-hid: init failed bus%u dev%u func%u", .{ locs[i].bus, locs[i].dev, locs[i].func });
        }
    }

    hid_ready = input_dev_count > 0;
    if (!hid_ready) {
        klog.info("virtio-hid: no device initialized (check PCI caps / queue size)", .{});
    } else {
        klog.info("virtio-hid: %u input PCI function(s) active", .{input_dev_count});
    }
}

pub fn poll() void {
    var round: u32 = 0;
    while (round < 32) : (round += 1) {
        var di: usize = 0;
        while (di < input_dev_count) : (di += 1) {
            drainDevice(&input_devs[di]);
            _ = mmioR32(input_devs[di].common, VIRTIO_PCI_COMMON_STATUS);
        }
    }
}

pub fn consumeMoved() bool {
    const m = moved_since_frame;
    moved_since_frame = false;
    return m;
}

pub fn leftPressedEdge() bool {
    const p = btn_left and !left_was_down;
    left_was_down = btn_left;
    return p;
}

pub fn rightPressedEdge() bool {
    const p = btn_right and !right_was_down;
    right_was_down = btn_right;
    return p;
}
