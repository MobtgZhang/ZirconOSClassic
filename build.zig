const std = @import("std");
const mem = std.mem;

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const arch_opt = b.option(
        []const u8,
        "arch",
        "Target architecture (x86_64, loongarch64, aarch64, riscv64, mips64el)",
    ) orelse "x86_64";
    const debug_mode = b.option(bool, "debug", "Verbose boot/kernel logging") orelse false;
    const enable_idt = b.option(bool, "enable_idt", "Enable IDT/timer/syscall stubs (x86_64)") orelse true;

    var cpu_arch: std.Target.Cpu.Arch = .x86_64;
    if (mem.eql(u8, arch_opt, "x86_64")) {
        cpu_arch = .x86_64;
    } else if (mem.eql(u8, arch_opt, "loongarch64")) {
        cpu_arch = .loongarch64;
    } else if (mem.eql(u8, arch_opt, "aarch64")) {
        cpu_arch = .aarch64;
    } else if (mem.eql(u8, arch_opt, "riscv64")) {
        cpu_arch = .riscv64;
    } else if (mem.eql(u8, arch_opt, "mips64el")) {
        cpu_arch = .mips64el;
    } else {
        @panic("Unsupported arch; expected: x86_64, loongarch64, aarch64, riscv64, mips64el");
    }

    const target = b.resolveTargetQuery(.{
        .cpu_arch = cpu_arch,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const desktop_default = b.option(
        []const u8,
        "default_desktop",
        "Default shell/desktop hint for ZBM UEFI (ntclassic | none)",
    ) orelse "ntclassic";

    const code_model: std.builtin.CodeModel = switch (cpu_arch) {
        .x86_64 => .kernel,
        .aarch64 => .small,
        .riscv64 => .medium,
        else => .default,
    };

    const kernel_opts = b.addOptions();
    kernel_opts.addOption(bool, "debug", debug_mode);
    kernel_opts.addOption(bool, "enable_idt", enable_idt);

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = false,
        .code_model = code_model,
        .pic = false,
        .red_zone = if (cpu_arch == .x86_64) false else null,
        .strip = false,
    });
    root_mod.addOptions("build_options", kernel_opts);

    const kernel_exe = b.addExecutable(.{
        .name = "kernel",
        .root_module = root_mod,
    });

    kernel_exe.entry = .{ .symbol_name = "_start" };
    kernel_exe.link_gc_sections = false;
    kernel_exe.pie = false;
    kernel_exe.link_z_max_page_size = 0x1000;

    const linker_script = switch (cpu_arch) {
        .x86_64 => b.path("link/x86_64.ld"),
        .aarch64 => b.path("link/aarch64.ld"),
        .loongarch64 => b.path("link/loongarch64.ld"),
        .riscv64 => b.path("link/riscv64.ld"),
        .mips64el => b.path("link/mips64el.ld"),
        else => b.path("link/x86_64.ld"),
    };
    kernel_exe.setLinkerScript(linker_script);

    if (cpu_arch == .x86_64) {
        kernel_exe.addAssemblyFile(b.path("src/arch/x86_64/start.s"));
        if (enable_idt) {
            kernel_exe.addAssemblyFile(b.path("src/arch/x86_64/isr_common.s"));
            kernel_exe.addAssemblyFile(b.path("src/arch/x86_64/syscall_entry.s"));
        }
    } else if (cpu_arch == .aarch64) {
        kernel_exe.addAssemblyFile(b.path("src/arch/aarch64/uefi_vector.S"));
    } else if (cpu_arch == .loongarch64) {
        kernel_exe.addAssemblyFile(b.path("src/arch/loongarch64/crt0.S"));
        kernel_exe.addAssemblyFile(b.path("src/arch/loongarch64/uefi_vector.S"));
    }

    // kernel 步骤必须安装到 zig-out/bin，供 ZBM / make run 读取（仅编译不会复制产物）。
    const install_kernel = b.addInstallArtifact(kernel_exe, .{});
    b.getInstallStep().dependOn(&install_kernel.step);

    const kernel_step = b.step("kernel", "Build ntoskrnl (kernel.elf)");
    kernel_step.dependOn(&install_kernel.step);

    buildUefi(b, cpu_arch, optimize, debug_mode, desktop_default);
    buildZbm(b, cpu_arch, optimize, debug_mode);
    if (cpu_arch == .loongarch64) {
        buildLoongArchZbmEfiObject(b, optimize, desktop_default, debug_mode);
    }
}

fn buildZbm(b: *std.Build, cpu_arch: std.Target.Cpu.Arch, optimize: std.builtin.OptimizeMode, debug_mode: bool) void {
    _ = optimize;
    if (cpu_arch != .x86_64) return;

    const zbm_opts = b.addOptions();
    zbm_opts.addOption(bool, "debug", debug_mode);

    const zbm_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const zbm_mod = b.createModule(.{
        .root_source_file = b.path("boot/zbm/zbm.zig"),
        .target = zbm_target,
        .optimize = .ReleaseSmall,
        .link_libc = false,
        .code_model = .kernel,
        .pic = false,
        .red_zone = false,
        .strip = false,
    });
    zbm_mod.addOptions("build_options", zbm_opts);

    const zbm_lib = b.addLibrary(.{
        .name = "zbm",
        .linkage = .static,
        .root_module = zbm_mod,
    });

    const install_zbm = b.addInstallArtifact(zbm_lib, .{});
    const zbm_step = b.step("zbm", "Build ZirconOS Boot Manager (ZBM) static library");
    zbm_step.dependOn(&install_zbm.step);
}

fn buildUefi(
    b: *std.Build,
    cpu_arch: std.Target.Cpu.Arch,
    optimize: std.builtin.OptimizeMode,
    debug_mode: bool,
    desktop_default: []const u8,
) void {
    if (cpu_arch != .x86_64 and cpu_arch != .aarch64) return;

    const uefi_target = b.resolveTargetQuery(.{
        .cpu_arch = cpu_arch,
        .os_tag = .uefi,
        .abi = .none,
    });

    const uefi_opts = b.addOptions();
    uefi_opts.addOption(bool, "debug", debug_mode);
    uefi_opts.addOption([]const u8, "desktop", desktop_default);

    const uefi_mod = b.createModule(.{
        .root_source_file = b.path("boot/zbm/uefi/main.zig"),
        .target = uefi_target,
        .optimize = optimize,
    });
    uefi_mod.addOptions("build_options", uefi_opts);

    const uefi_exe = b.addExecutable(.{
        .name = "zbmfw",
        .root_module = uefi_mod,
    });

    const install_uefi = b.addInstallArtifact(uefi_exe, .{});
    const uefi_step = b.step("uefi", "Build ZBM UEFI application (BOOTX64.EFI / BOOTAA64.EFI → install as zbmfw.efi)");
    uefi_step.dependOn(&install_uefi.step);
}

fn buildLoongArchZbmEfiObject(b: *std.Build, optimize: std.builtin.OptimizeMode, desktop_default: []const u8, debug_mode: bool) void {
    // 默认 loongarch64（含 f/d、lp64d），与交叉 gcc 链接一致。UEFI 下 EUEN 由 crt0 在 efi_main 前写入。
    const la_target = b.resolveTargetQuery(.{
        .cpu_arch = .loongarch64,
        .os_tag = .freestanding,
        .abi = .none,
    });
    const zbm_opts = b.addOptions();
    zbm_opts.addOption(bool, "debug", debug_mode);
    zbm_opts.addOption([]const u8, "desktop", desktop_default);
    const zbm_mod = b.createModule(.{
        .root_source_file = b.path("boot/zbm/uefi/main_loongarch64.zig"),
        .target = la_target,
        .optimize = optimize,
        .link_libc = false,
    });
    zbm_mod.addOptions("build_options", zbm_opts);
    const zbm_obj = b.addObject(.{
        .name = "zbm_loongarch64",
        .root_module = zbm_mod,
    });
    // 与 kernel 相同放在 zig-out/bin/，供 scripts/link_zbm_loongarch_efi.sh 与文档路径一致
    const install_o = b.addInstallFile(zbm_obj.getEmittedBin(), "bin/zbm_loongarch64.o");
    b.getInstallStep().dependOn(&install_o.step);
    const zbm_la_step = b.step("zbm-loongarch-uefi", "LoongArch ZBM: Zig object (link with GNU-EFI → BOOTLOONGARCH64.EFI)");
    zbm_la_step.dependOn(&install_o.step);
}
