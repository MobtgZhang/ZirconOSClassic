//! Architecture dispatch for the NT 5.0–style kernel (ntoskrnl phase-0).
const builtin = @import("builtin");

pub const impl = switch (builtin.target.cpu.arch) {
    .x86_64 => @import("arch/x86_64/mod.zig"),
    .aarch64 => @import("arch/aarch64/mod.zig"),
    .riscv64 => @import("arch/riscv64/mod.zig"),
    .loongarch64 => @import("arch/loongarch64/mod.zig"),
    .mips64el => @import("arch/mips64el/mod.zig"),
    else => @compileError("unsupported CPU architecture for ZirconOS Classic"),
};

pub const PAGE_SIZE: usize = impl.PAGE_SIZE;
