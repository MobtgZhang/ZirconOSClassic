//! QEMU `loongarch64` `virt`：UEFI 无线性 GOP 时枚举 PCI virtio-gpu-pci（0x1af4/0x1050），
//! 建立 control virtqueue，提交 2D resource + scanout，供 `fb_console` / GRE 使用。
//! ECAM：VIRT_PCI_CFG_BASE = 0x2000_0000（QEMU `virt.h`）。

const builtin = @import("builtin");
const std = @import("std");
const dfs = @import("../../config/desktop_fb.zig");
const klog = @import("../../rtl/klog.zig");
const fb = @import("../fb_console.zig");
const dcache = @import("dcache.zig");

comptime {
    if (builtin.target.cpu.arch != .loongarch64) {
        @compileError("virtio_gpu.zig is LoongArch64-only");
    }
}

const VIRT_PCI_CFG_BASE: usize = 0x2000_0000;

const VIRTIO_PCI_VENDOR: u16 = 0x1af4;
const VIRTIO_GPU_DEVICE_MODERN: u16 = 0x1050;

const PCI_CAP_VENDOR: u8 = 0x09;

const VIRTIO_PCI_CAP_COMMON_CFG: u8 = 1;
const VIRTIO_PCI_CAP_NOTIFY_CFG: u8 = 2;
const VIRTIO_PCI_CAP_DEVICE_CFG: u8 = 4;

const VIRTIO_CONFIG_S_ACKNOWLEDGE: u8 = 1;
const VIRTIO_CONFIG_S_DRIVER: u8 = 2;
const VIRTIO_CONFIG_S_DRIVER_OK: u8 = 4;
const VIRTIO_CONFIG_S_FEATURES_OK: u8 = 8;

const VIRTIO_F_VERSION_1: u64 = 1 << 32;

const VIRTQ_DESC_F_NEXT: u16 = 1;
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

const VIRTIO_GPU_CMD_GET_DISPLAY_INFO: u32 = 0x0100;
const VIRTIO_GPU_CMD_RESOURCE_CREATE_2D: u32 = 0x0101;
const VIRTIO_GPU_CMD_SET_SCANOUT: u32 = 0x0103;
const VIRTIO_GPU_CMD_RESOURCE_FLUSH: u32 = 0x0104;
const VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING: u32 = 0x0107;
const VIRTIO_GPU_RESP_OK_DISPLAY_INFO: u32 = 0x1101;
const VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM: u32 = 2;

const GpuCtrlHdr = extern struct {
    type: u32,
    flags: u32,
    fence_id: u64,
    ctx_id: u32,
    ring_idx: u8,
    padding: [3]u8,
};

const GpuRect = extern struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
};

const GpuResourceCreate2d = extern struct {
    hdr: GpuCtrlHdr,
    resource_id: u32,
    format: u32,
    width: u32,
    height: u32,
};

const GpuMemEntry = extern struct {
    addr: u64,
    length: u32,
    padding: u32,
};

const GpuResourceAttachBacking = extern struct {
    hdr: GpuCtrlHdr,
    resource_id: u32,
    nr_entries: u32,
};

const GpuSetScanout = extern struct {
    hdr: GpuCtrlHdr,
    r: GpuRect,
    scanout_id: u32,
    resource_id: u32,
};

const GpuResourceFlush = extern struct {
    hdr: GpuCtrlHdr,
    r: GpuRect,
    resource_id: u32,
    padding: u32,
};

const GpuRespDisplayInfo = extern struct {
    hdr: GpuCtrlHdr,
    pmodes: [16]extern struct {
        r: GpuRect,
        enabled: u32,
        flags: u32,
    },
};

const VringDesc = extern struct {
    addr: u64,
    len: u32,
    flags: u16,
    next: u16,
};

const QSIZE: usize = 8;

const VringAvail = extern struct {
    flags: u16,
    idx: u16,
    ring: [QSIZE]u16,
    used_event: u16,
};

const VringUsedElem = extern struct {
    id: u32,
    len: u32,
};

const VringUsed = extern struct {
    flags: u16,
    idx: u16,
    ring: [QSIZE]VringUsedElem,
    avail_event: u16,
};

// VirtIO 1.0：描述符环 / avail / used 建议页对齐，避免固件或 Zig 指针对齐断言。
var gpu_desc: [QSIZE]VringDesc align(4096) = undefined;
var gpu_avail: VringAvail align(4096) = undefined;
var gpu_used: VringUsed align(4096) = undefined;

var gpu_cmd_buf: [512]u8 align(4096) = undefined;
var gpu_resp_buf: [4096]u8 align(4096) = undefined;

const gpu_pixel_bytes = dfs.width * dfs.height * 4;
var gpu_pixels: [gpu_pixel_bytes]u8 align(4096) = undefined;

var gpu_queue_ready: bool = false;
var gpu_last_used_idx: u16 = 0;

var gpu_notify_addr: usize = 0;
/// `common_cfg` MMIO 基址；在 execGpu 轮询中周期性读 STATUS，迫使 QEMU TCG 退出翻译块并运行 virtio-gpu 的 `qemu_bh`（否则仅 `schedule` BH 时忙等会永远超时）。
var gpu_common_cfg: usize = 0;

/// `tryInit` 成功后为 true；`flushScanoutIfActive` 在每帧提交 RESOURCE_FLUSH。
var gpu_scanout_active: bool = false;
var gpu_fb_w: u32 = 0;
var gpu_fb_h: u32 = 0;

/// `reg` 为 PCI 配置空间字节偏移。勿用 `u8`：能力链表上 `cap + 8` / `cap + 16` 会超过 255，
/// 在 u8 上回绕后 `pciRead32` 会落到奇数偏移，`@ptrFromInt`→`*u32` 即触发 incorrect alignment panic。
fn pciCfgAddr(bus: u8, dev: u8, func: u8, reg: usize) usize {
    return VIRT_PCI_CFG_BASE +
        (@as(usize, bus) << 20) +
        (@as(usize, dev) << 15) +
        (@as(usize, func) << 12) +
        reg;
}

fn pciRead8(bus: u8, dev: u8, func: u8, reg: usize) u8 {
    return @as(*const volatile u8, @ptrFromInt(pciCfgAddr(bus, dev, func, reg))).*;
}

/// PCI 配置空间 dword，小端；用字节访问避免 `reg` 或 ECAM 组合地址非 4 对齐时 `*u32` 触发 Zig panic。
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

/// VirtIO common/notify BAR 内寄存器：`common_base + cap.offset` 在规范上多为 4 对齐，但用 `*u32`/`*u16`
/// 在任意 `base+off` 上仍会触发运行时对齐检查；统一按小端字节访问。
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

fn mmioW8(base: usize, off: usize, v: u8) void {
    @as(*volatile u8, @ptrFromInt(base +% off)).* = v;
}

/// 门铃：QEMU virtio-pci 通常按 **一次 MMIO 写** 识别 kick；连续 4×`u8` 可能无法触发队列处理（表现为 GET_DISPLAY_INFO 超时）。
/// 在地址已对齐时用 `u32`；否则退化为 `u16`/`u8` 以免 Zig 对齐 panic。
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
    asm volatile ("dbar 0"
        :
        :
        : .{ .memory = true }
    );
}

fn descVolatile(i: usize) *volatile VringDesc {
    return @ptrCast(&gpu_desc[i]);
}

fn availVolatile() *volatile VringAvail {
    return @ptrCast(&gpu_avail);
}

/// 设备写 `used.idx`；必须 volatile 读且屏障，避免优化成寄存器常驻。
fn usedIdxRead() u16 {
    dbar();
    const p: *const volatile u16 = @ptrFromInt(@intFromPtr(&gpu_used) + @offsetOf(VringUsed, "idx"));
    return p.*;
}

fn flushVirtqueueForDevice(cmd_len: usize) void {
    dcache.syncToDevice(@intFromPtr(&gpu_desc), @sizeOf([QSIZE]VringDesc));
    dcache.syncToDevice(@intFromPtr(&gpu_avail), @sizeOf(VringAvail));
    dcache.syncToDevice(@intFromPtr(&gpu_cmd_buf), cmd_len);
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

const CapInfo = struct {
    common_off: u32,
    common_len: u32,
    common_bar: u8,
    notify_off: u32,
    notify_bar: u8,
    notify_mul: u32,
};

fn readVirtioCaps(bus: u8, dev: u8, func: u8) ?CapInfo {
    const hdr0 = pciRead32(bus, dev, func, 0);
    if ((hdr0 & 0xFFFF) == 0xFFFF) return null;
    var cap_ptr: usize = pciRead8(bus, dev, func, 0x34);
    var out = CapInfo{
        .common_off = 0,
        .common_len = 0,
        .common_bar = 0,
        .notify_off = 0,
        .notify_bar = 0,
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
            switch (cfg_type) {
                VIRTIO_PCI_CAP_COMMON_CFG => {
                    found_common = true;
                    out.common_bar = bar;
                    out.common_off = off;
                    out.common_len = length;
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
                VIRTIO_PCI_CAP_DEVICE_CFG => {},
                else => {},
            }
        }
        cap_ptr = @as(usize, next);
    }
    if (!found_common or !found_notify) return null;
    _ = out.common_len;
    return out;
}

fn barBase(bus: u8, dev: u8, func: u8, bar_idx: u8) ?usize {
    return pciBarPhys(bus, dev, func, bar_idx);
}

/// `notify_mmio` = notify BAR 物理基址 + capability offset（见 virtio_pci_cap.offset）。
fn setupQueueOnce(common: usize, notify_mmio: usize, notify_mul: u32) void {
    if (gpu_queue_ready) return;

    @memset(std.mem.asBytes(&gpu_desc), 0);
    @memset(std.mem.asBytes(&gpu_avail), 0);
    @memset(std.mem.asBytes(&gpu_used), 0);

    const desc_phys = @intFromPtr(&gpu_desc);
    const avail_phys = @intFromPtr(&gpu_avail);
    const used_phys = @intFromPtr(&gpu_used);

    mmioW16(common, VIRTIO_PCI_COMMON_Q_SELECT, 0);
    // QEMU virtio-pci 拒绝向 queue_enable 写 0（会打印 wrong value for queue_enable 0），勿先 disable。
    mmioW16(common, VIRTIO_PCI_COMMON_Q_SIZE, QSIZE);
    mmioW32(common, VIRTIO_PCI_COMMON_Q_DESCLO, @truncate(desc_phys));
    mmioW32(common, VIRTIO_PCI_COMMON_Q_DESCHI, @truncate(desc_phys >> 32));
    mmioW32(common, VIRTIO_PCI_COMMON_Q_AVAILLO, @truncate(avail_phys));
    mmioW32(common, VIRTIO_PCI_COMMON_Q_AVAILHI, @truncate(avail_phys >> 32));
    mmioW32(common, VIRTIO_PCI_COMMON_Q_USEDLO, @truncate(used_phys));
    mmioW32(common, VIRTIO_PCI_COMMON_Q_USEDHI, @truncate(used_phys >> 32));
    mmioW16(common, VIRTIO_PCI_COMMON_Q_ENABLE, 1);
    dbar();

    const qnoff = mmioR32(common, VIRTIO_PCI_COMMON_Q_NOFF) & 0xFFFF;
    gpu_notify_addr = notify_mmio + @as(usize, qnoff) * @as(usize, notify_mul);

    gpu_queue_ready = true;
    gpu_last_used_idx = usedIdxRead();
}

fn execGpu(cmd_len: usize, resp_max: usize) bool {
    const cmd_phys = @intFromPtr(&gpu_cmd_buf);
    const resp_phys = @intFromPtr(&gpu_resp_buf);

    descVolatile(0).* = .{
        .addr = cmd_phys,
        .len = @intCast(cmd_len),
        .flags = VIRTQ_DESC_F_NEXT,
        .next = 1,
    };
    descVolatile(1).* = .{
        .addr = resp_phys,
        .len = @intCast(resp_max),
        .flags = VIRTQ_DESC_F_WRITE,
        .next = 0,
    };
    dbar();

    const av = availVolatile();
    const slot = @as(usize, av.idx) % QSIZE;
    av.ring[slot] = 0;
    av.idx = av.idx +% 1;
    dbar();

    flushVirtqueueForDevice(cmd_len);
    virtioQueueNotifyWrite(gpu_notify_addr);

    const target = gpu_last_used_idx +% 1;
    var spin: u32 = 0;
    while (spin < 50_000_000) : (spin += 1) {
        if (usedIdxRead() == target) {
            gpu_last_used_idx = target;
            dcache.syncFromDevice(@intFromPtr(&gpu_resp_buf), resp_max);
            return true;
        }
        // virtio-gpu 的 notify 回调只 qemu_bh_schedule；TCG 若整段翻译此循环，BH 不跑则设备永不写 used。
        if ((spin & 0xFF) == 0 and gpu_common_cfg != 0) {
            _ = mmioR32(gpu_common_cfg, VIRTIO_PCI_COMMON_STATUS);
        }
    }
    return false;
}

fn findGpuPci() ?struct { bus: u8, dev: u8, func: u8 } {
    var dev: u8 = 0;
    while (dev < 32) : (dev += 1) {
        const v0 = pciRead32(0, dev, 0, 0);
        const ven = @as(u16, @truncate(v0));
        if (ven == 0xFFFF) continue;
        const did = @as(u16, @truncate(v0 >> 16));
        if (ven == VIRTIO_PCI_VENDOR and did == VIRTIO_GPU_DEVICE_MODERN) {
            return .{ .bus = 0, .dev = dev, .func = 0 };
        }
    }
    return null;
}

pub fn tryInitQemuVirtioGpuFramebuffer() void {
    if (fb.isReady()) return;

    const loc = findGpuPci() orelse {
        klog.info("virtio-gpu: no PCI 1af4:1050", .{});
        return;
    };
    const b = loc.bus;
    const d = loc.dev;
    const f = loc.func;

    const caps = readVirtioCaps(b, d, f) orelse {
        klog.info("virtio-gpu: missing virtio PCI caps", .{});
        return;
    };

    const cmdw = pciRead32(b, d, f, 0x04) & 0xFFFF;
    pciWrite32(b, d, f, 0x04, cmdw | 0x6);

    const common_base = barBase(b, d, f, caps.common_bar) orelse {
        klog.info("virtio-gpu: bad common BAR", .{});
        return;
    };
    const notify_base = barBase(b, d, f, caps.notify_bar) orelse {
        klog.info("virtio-gpu: bad notify BAR", .{});
        return;
    };
    const common = common_base + caps.common_off;
    const notify = notify_base + caps.notify_off;
    gpu_common_cfg = common;

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

    if ((mmioR32(common, VIRTIO_PCI_COMMON_STATUS) & 0xFF) & VIRTIO_CONFIG_S_FEATURES_OK == 0) {
        klog.info("virtio-gpu: FEATURES_OK not set", .{});
        return;
    }

    setupQueueOnce(common, notify, caps.notify_mul);

    mmioW8(common, VIRTIO_PCI_COMMON_STATUS, VIRTIO_CONFIG_S_ACKNOWLEDGE | VIRTIO_CONFIG_S_DRIVER | VIRTIO_CONFIG_S_FEATURES_OK | VIRTIO_CONFIG_S_DRIVER_OK);
    dbar();

    // GET_DISPLAY_INFO
    var sw: u32 = dfs.width;
    var sh: u32 = dfs.height;
    {
        const hdr: *GpuCtrlHdr = @ptrCast(&gpu_cmd_buf);
        hdr.* = std.mem.zeroes(GpuCtrlHdr);
        hdr.type = VIRTIO_GPU_CMD_GET_DISPLAY_INFO;
        if (!execGpu(@sizeOf(GpuCtrlHdr), @sizeOf(GpuRespDisplayInfo))) {
            klog.info("virtio-gpu: GET_DISPLAY_INFO timeout", .{});
            return;
        }
        const rh = @as(*const GpuCtrlHdr, @ptrCast(&gpu_resp_buf));
        if (rh.type == VIRTIO_GPU_RESP_OK_DISPLAY_INFO) {
            const di: *const GpuRespDisplayInfo = @ptrCast(&gpu_resp_buf);
            for (di.pmodes) |pm| {
                if (pm.enabled != 0 and pm.r.width > 0 and pm.r.height > 0) {
                    sw = pm.r.width;
                    sh = pm.r.height;
                    break;
                }
            }
        }
    }
    if (sw > dfs.width) sw = dfs.width;
    if (sh > dfs.height) sh = dfs.height;
    const pitch = sw * 4;
    if (pitch * sh > gpu_pixels.len) {
        klog.info("virtio-gpu: mode %ux%u too large", .{ sw, sh });
        return;
    }

    const px_phys = @intFromPtr(&gpu_pixels);

    {
        const c: *GpuResourceCreate2d = @ptrCast(&gpu_cmd_buf);
        c.hdr = std.mem.zeroes(GpuCtrlHdr);
        c.hdr.type = VIRTIO_GPU_CMD_RESOURCE_CREATE_2D;
        c.resource_id = 1;
        c.format = VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM;
        c.width = sw;
        c.height = sh;
        if (!execGpu(@sizeOf(GpuResourceCreate2d), 128)) {
            klog.info("virtio-gpu: RESOURCE_CREATE_2D timeout", .{});
            return;
        }
    }

    {
        const base_len = @sizeOf(GpuResourceAttachBacking);
        const total = base_len + @sizeOf(GpuMemEntry);
        const a: *GpuResourceAttachBacking = @ptrCast(&gpu_cmd_buf);
        a.hdr = std.mem.zeroes(GpuCtrlHdr);
        a.hdr.type = VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING;
        a.resource_id = 1;
        a.nr_entries = 1;
        const ent: *GpuMemEntry = @ptrCast(gpu_cmd_buf[base_len..][0..@sizeOf(GpuMemEntry)].ptr);
        ent.addr = px_phys;
        ent.length = @intCast(pitch * sh);
        ent.padding = 0;
        if (!execGpu(total, 128)) {
            klog.info("virtio-gpu: ATTACH_BACKING timeout", .{});
            return;
        }
    }

    {
        const s: *GpuSetScanout = @ptrCast(&gpu_cmd_buf);
        s.hdr = std.mem.zeroes(GpuCtrlHdr);
        s.hdr.type = VIRTIO_GPU_CMD_SET_SCANOUT;
        s.r = .{ .x = 0, .y = 0, .width = sw, .height = sh };
        s.scanout_id = 0;
        s.resource_id = 1;
        if (!execGpu(@sizeOf(GpuSetScanout), 128)) {
            klog.info("virtio-gpu: SET_SCANOUT timeout", .{});
            return;
        }
    }

    {
        const fl: *GpuResourceFlush = @ptrCast(&gpu_cmd_buf);
        fl.hdr = std.mem.zeroes(GpuCtrlHdr);
        fl.hdr.type = VIRTIO_GPU_CMD_RESOURCE_FLUSH;
        fl.r = .{ .x = 0, .y = 0, .width = sw, .height = sh };
        fl.resource_id = 1;
        fl.padding = 0;
        _ = execGpu(@sizeOf(GpuResourceFlush), 128);
    }

    fb.initEx(px_phys, sw, sh, pitch, 32, true);
    gpu_scanout_active = true;
    gpu_fb_w = sw;
    gpu_fb_h = sh;
    klog.info("virtio-gpu: QEMU display %ux%u @0x%x", .{ sw, sh, px_phys });
}

/// GRE 改像素后需通知 hypervisor 刷新 scanout（否则 QEMU 窗口不更新）。
pub fn flushScanoutIfActive() void {
    if (!gpu_scanout_active or !gpu_queue_ready) return;
    const fl: *GpuResourceFlush = @ptrCast(&gpu_cmd_buf);
    fl.hdr = std.mem.zeroes(GpuCtrlHdr);
    fl.hdr.type = VIRTIO_GPU_CMD_RESOURCE_FLUSH;
    fl.r = .{ .x = 0, .y = 0, .width = gpu_fb_w, .height = gpu_fb_h };
    fl.resource_id = 1;
    fl.padding = 0;
    _ = execGpu(@sizeOf(GpuResourceFlush), 64);
}
