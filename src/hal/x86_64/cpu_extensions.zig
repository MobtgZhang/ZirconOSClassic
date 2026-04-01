//! 可选 CPU 特性：NX、SMEP、SMAP。在 GDT/IDT 就绪后由内核早期调用。

const msr = @import("msr.zig");
const klog = @import("../../rtl/klog.zig");

const EFER_NXE: u64 = 1 << 11;
const CR4_SMEP: u64 = 1 << 20;
const CR4_SMAP: u64 = 1 << 21;

fn readCr4() u64 {
    return asm volatile ("mov %%cr4, %[r]"
        : [r] "=r" (-> u64),
    );
}

fn writeCr4(v: u64) void {
    asm volatile ("mov %[r], %%cr4"
        :
        : [r] "r" (v),
        : .{ .memory = true });
}

/// 启用 IA32_EFER.NXE（页表 NX 位生效需分页已配置 PAT/页项）。
pub fn enableNxEfer() void {
    const efer = msr.rdmsr64(msr.IA32_EFER);
    if ((efer & EFER_NXE) != 0) return;
    msr.wrmsr64(msr.IA32_EFER, efer | EFER_NXE);
    klog.info("HAL x86_64: EFER.NXE enabled", .{});
}

/// SMEP：禁止内核执行用户页。SMAP：禁止内核意外访问用户页（需 `stac`/`clac` 配对使用）。
pub fn enableSmepSmap() void {
    const cr4 = readCr4();
    const want = cr4 | CR4_SMEP | CR4_SMAP;
    if (cr4 == want) return;
    writeCr4(want);
    klog.info("HAL x86_64: CR4.SMEP+SMAP enabled", .{});
}

pub fn initAfterPagingReady() void {
    enableNxEfer();
    enableSmepSmap();
}
