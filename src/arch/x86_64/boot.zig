//! Multiboot2 header symbol (x86_64) + shared boot info types/parser.

extern const multiboot2_header: [48]u8;

const mb = @import("../../boot/multiboot2.zig");

pub const MULTIBOOT2_BOOTLOADER_MAGIC = mb.MULTIBOOT2_BOOTLOADER_MAGIC;
pub const BootInfoHeader = mb.BootInfoHeader;
pub const TagHeader = mb.TagHeader;
pub const TagType = mb.TagType;
pub const BasicMemInfoTag = mb.BasicMemInfoTag;
pub const MmapEntryType = mb.MmapEntryType;
pub const MmapEntry = mb.MmapEntry;
pub const MmapTag = mb.MmapTag;
pub const FramebufferInfo = mb.FramebufferInfo;
pub const DesktopTheme = mb.DesktopTheme;
pub const BootMode = mb.BootMode;
pub const BootInfo = mb.BootInfo;

pub fn parse(magic: u32, phys_addr: usize) ?BootInfo {
    return mb.parse(magic, phys_addr);
}
