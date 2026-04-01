//! Model-specific registers (x86_64).

pub const IA32_EFER: u32 = 0xC0000080;
pub const IA32_APIC_BASE: u32 = 0x0000001B;

pub fn rdmsr(msr: u32) struct { low: u32, high: u32 } {
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("rdmsr"
        : [lo] "={eax}" (low),
          [hi] "={edx}" (high),
        : [cx] "{ecx}" (msr),
        : .{ .memory = true });
    return .{ .low = low, .high = high };
}

pub fn wrmsr(msr: u32, low: u32, high: u32) void {
    asm volatile ("wrmsr"
        :
        : [cx] "{ecx}" (msr),
          [lo] "{eax}" (low),
          [hi] "{edx}" (high),
        : .{ .memory = true });
}

pub fn rdmsr64(msr: u32) u64 {
    const p = rdmsr(msr);
    return (@as(u64, p.high) << 32) | p.low;
}

pub fn wrmsr64(msr: u32, value: u64) void {
    wrmsr(msr, @truncate(value), @truncate(value >> 32));
}
