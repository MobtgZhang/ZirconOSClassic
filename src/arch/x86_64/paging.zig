//! x86_64 四级分页 (4-level paging)
//! PML4 -> PDPT -> PD -> PT -> 4KB Page

pub const PAGE_SIZE: usize = 4096;
pub const PAGE_MASK: usize = PAGE_SIZE - 1;

pub const Present: u64 = 1 << 0;
pub const Write: u64 = 1 << 1;
pub const User: u64 = 1 << 2;
pub const WriteThrough: u64 = 1 << 3;
pub const CacheDisable: u64 = 1 << 4;
pub const Accessed: u64 = 1 << 5;
pub const Dirty: u64 = 1 << 6;
pub const LargePage: u64 = 1 << 7;
pub const Global: u64 = 1 << 8;
pub const NoExecute: u64 = 1 << 63;
