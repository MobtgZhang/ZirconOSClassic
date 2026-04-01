//! 内核可见的 UEFI/ZBM 启动上下文（自命名结构，非 Windows LOADER_PARAMETER_BLOCK）。
//! 数据来自 Multiboot2 信息块解析结果，供 HAL/ACPI 等后续子系统只读使用。

const mb = @import("multiboot2.zig");

pub const ZirconBootContext = struct {
    mem_lower_kb: u32,
    mem_upper_kb: u32,
    mmap_ptr: [*]const u8,
    mmap_entry_count: usize,
    mmap_entry_size: u32,
    cmdline_ptr: ?[*]const u8,
    cmdline_len: usize,
    framebuffer: ?mb.FramebufferInfo,
    acpi_rsdp_phys: ?u64,
    multiboot_info_phys: u64,

    pub fn fromMultiboot2(b: mb.BootInfo) ZirconBootContext {
        return .{
            .mem_lower_kb = b.mem_lower_kb,
            .mem_upper_kb = b.mem_upper_kb,
            .mmap_ptr = b.mmap_ptr,
            .mmap_entry_count = b.mmap_entry_count,
            .mmap_entry_size = b.mmap_entry_size,
            .cmdline_ptr = b.cmdline_ptr,
            .cmdline_len = b.cmdline_len,
            .framebuffer = b.fb_info,
            .acpi_rsdp_phys = b.acpi_rsdp_phys,
            .multiboot_info_phys = b.multiboot_info_phys,
        };
    }
};

var storage: ZirconBootContext = undefined;
var valid: bool = false;

pub fn setFromMultiboot2(b: mb.BootInfo) void {
    storage = ZirconBootContext.fromMultiboot2(b);
    valid = true;
}

pub fn get() ?*const ZirconBootContext {
    if (!valid) return null;
    return &storage;
}
