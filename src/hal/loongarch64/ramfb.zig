//! QEMU **ramfb**：通过 fw_cfg DMA 向客户机注册线性帧缓冲，无需 virtio 队列。
//! 参考 [ZirconOSAero ramfb.zig](https://github.com/MobtgZhang/ZirconOSAero/blob/main/src/hal/loongarch64/ramfb.zig)；
//! QEMU 需 `-device ramfb`（见 `scripts/qemu_run.sh`）。

const std = @import("std");
const dfs = @import("../../config/desktop_fb.zig");
const klog = @import("../../rtl/klog.zig");
const fb = @import("../fb_console.zig");

pub const FW_CFG_BASE: usize = 0x1e020000;
pub const FW_CFG_SELECTOR: usize = FW_CFG_BASE + 8;
pub const FW_CFG_DMA: usize = FW_CFG_BASE + 16;

pub const FW_CFG_FILE_DIR: u16 = 0x0019;
pub const FW_CFG_DMA_CTL_SELECT: u32 = 1 << 3;
pub const FW_CFG_DMA_CTL_WRITE: u32 = 1 << 4;
pub const RAMFB_FOURCC_AR24: u32 = 0x34325241; // 'AR24'

/// 与 ZirconOSAero 一致：固定物理区，避免与内核映像（~0x200000 起）重叠。
pub const RESERVED_BASE: usize = 0x0F000000;
pub const RESERVED_SIZE: usize = dfs.stride * dfs.height;

const RAMFBCfg = extern struct {
    addr: u64,
    fourcc: u32,
    flags: u32,
    width: u32,
    height: u32,
    stride: u32,
};

fn writeU32Be(addr: usize, v: u32) void {
    const p: *[4]u8 = @ptrFromInt(addr);
    p[0] = @truncate(v >> 24);
    p[1] = @truncate(v >> 16);
    p[2] = @truncate(v >> 8);
    p[3] = @truncate(v);
}

fn writeU64Be(addr: usize, v: u64) void {
    writeU32Be(addr, @truncate(v >> 32));
    writeU32Be(addr + 4, @truncate(v));
}

fn readU32Be(addr: usize) u32 {
    const p: *const [4]u8 = @ptrFromInt(addr);
    return @as(u32, p[0]) << 24 | @as(u32, p[1]) << 16 | @as(u32, p[2]) << 8 | @as(u32, p[3]);
}

/// 查找 fw_cfg 目录中 `etc/ramfb` 的 selector。
fn findRamfbKey() ?u16 {
    const selector_be: *volatile u16 = @ptrFromInt(FW_CFG_SELECTOR);
    const data: *volatile u64 = @ptrFromInt(FW_CFG_BASE);
    const be_key = @byteSwap(FW_CFG_FILE_DIR);
    selector_be.* = be_key;

    var buf: [4096]u8 = undefined;
    var off: usize = 0;
    while (off < buf.len) : (off += 8) {
        const v = data.*;
        @memcpy(buf[off..][0..8], &@as([8]u8, @bitCast(v)));
    }
    const num_files = (@as(u32, buf[0]) << 24) | (@as(u32, buf[1]) << 16) | (@as(u32, buf[2]) << 8) | buf[3];
    if (num_files > 64) {
        if (klog.DEBUG_MODE) klog.info("ramfb: dir num_files=%u too large", .{num_files});
        return null;
    }
    var i: u32 = 0;
    while (i < num_files) : (i += 1) {
        const entry = buf[4 + i * 64 ..][0..64];
        const select = @as(u16, entry[4]) << 8 | entry[5];
        const name = entry[8..64];
        if (std.mem.indexOf(u8, name, "ramfb") != null) return select;
    }
    if (klog.DEBUG_MODE) klog.info("ramfb: no etc/ramfb in fw_cfg (%u files)", .{num_files});
    return null;
}

var ramfb_dma_buf: [16]u8 align(8) = undefined;
var ramfb_cfg_buf: [32]u8 align(8) = undefined;

fn writeRamfbConfig(key: u16, cfg_bytes: [*]const u8) bool {
    const dma_phys = @intFromPtr(&ramfb_dma_buf);
    const ctrl = (FW_CFG_DMA_CTL_SELECT | FW_CFG_DMA_CTL_WRITE) | (@as(u32, key) << 16);
    writeU32Be(dma_phys, ctrl);
    writeU32Be(dma_phys + 4, @sizeOf(RAMFBCfg));
    writeU64Be(dma_phys + 8, @intFromPtr(cfg_bytes));
    const dma_reg: *volatile u64 = @ptrFromInt(FW_CFG_DMA);
    dma_reg.* = dma_phys;
    var timeout: u32 = 1_000_000;
    while (timeout > 0) : (timeout -= 1) {
        if ((readU32Be(dma_phys) & 1) == 0) return true;
    }
    return false;
}

/// 若 QEMU 提供 ramfb，初始化 `fb_console` 并返回 true；否则 false（可再尝试 virtio-gpu）。
pub fn tryInitFramebuffer() bool {
    if (fb.isReady()) return true;

    const key = findRamfbKey() orelse {
        klog.info("ramfb: fw_cfg has no ramfb (add -device ramfb to QEMU)", .{});
        return false;
    };

    writeU64Be(@intFromPtr(&ramfb_cfg_buf), RESERVED_BASE);
    writeU32Be(@intFromPtr(&ramfb_cfg_buf) + 8, RAMFB_FOURCC_AR24);
    writeU32Be(@intFromPtr(&ramfb_cfg_buf) + 12, 0);
    writeU32Be(@intFromPtr(&ramfb_cfg_buf) + 16, dfs.width);
    writeU32Be(@intFromPtr(&ramfb_cfg_buf) + 20, dfs.height);
    writeU32Be(@intFromPtr(&ramfb_cfg_buf) + 24, dfs.stride);

    if (!writeRamfbConfig(key, @ptrCast(&ramfb_cfg_buf))) {
        klog.info("ramfb: fw_cfg DMA timeout", .{});
        return false;
    }

    fb.initEx(RESERVED_BASE, dfs.width, dfs.height, dfs.stride, 32, true);
    @import("virtio_hid.zig").Input.syncPointerAfterFramebufferChange();
    klog.info("ramfb: linear FB %ux%u @0x%x (QEMU ramfb)", .{ dfs.width, dfs.height, RESERVED_BASE });
    return true;
}
