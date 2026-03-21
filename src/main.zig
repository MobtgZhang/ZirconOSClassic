//! ZirconOS Classic Desktop — GDI Shell Entry Point
//!
//! Implements the Windows 2000 NT5 GDI desktop architecture:
//!   1. No DWM — all windows are rendered directly via GDI calls
//!   2. Flat 3D beveled borders, grey taskbar, navy titlebar
//!   3. 16-color system palette icons
//!   4. System font: DejaVu Sans (MS Sans Serif replacement)
//!
//! Resources loaded from: 3rdparty/ZirconOSClassic/resources/
//! Fonts loaded from:     3rdparty/ZirconOSFonts/fonts/

const std = @import("std");
const root = @import("root.zig");
const theme = root.theme;
const shell = root.shell;
const desktop = root.desktop;
const taskbar = root.taskbar;
const startmenu = root.startmenu;
const compositor = @import("compositor.zig");
const resource_loader = @import("resource_loader.zig");
const font_loader = @import("font_loader.zig");

const SCREEN_W: u32 = 1024;
const SCREEN_H: u32 = 768;

const OsWindow = struct {
    title: []const u8,
    icon_id: u16,
    minimized: bool,
};

const os_windows = [_]OsWindow{
    .{ .title = "ZirconOS Core", .icon_id = 1, .minimized = true },
    .{ .title = "Command Prompt", .icon_id = 4, .minimized = true },
    .{ .title = "PowerShell", .icon_id = 4, .minimized = true },
};

fn p(out: *std.io.AnyWriter, comptime fmt: []const u8, args: anytype) void {
    out.print(fmt, args) catch {};
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var out = stdout.any();

    p(&out, "╔══════════════════════════════════════════╗\n", .{});
    p(&out, "║  ZirconOS {s} v{s}                   ║\n", .{ root.theme_name, root.theme_version });
    p(&out, "║  GDI Classic Desktop Shell               ║\n", .{});
    p(&out, "╚══════════════════════════════════════════╝\n\n", .{});

    // ── Phase 1: Load Resources ──
    p(&out, "--- Phase 1: Loading Resources ---\n", .{});

    resource_loader.init();
    p(&out, "  Icons      : {d} loaded\n", .{resource_loader.getIconCount()});
    p(&out, "  Cursors    : {d} loaded\n", .{resource_loader.getCursorCount()});

    // ── Phase 2: Load Fonts ──
    p(&out, "\n--- Phase 2: Loading Fonts ---\n", .{});

    font_loader.init();
    p(&out, "  Western fonts : {d} families\n", .{font_loader.getWesternFontCount()});
    p(&out, "  CJK fonts     : {d} families\n", .{font_loader.getCjkFontCount()});
    p(&out, "  System font   : {s}\n", .{font_loader.getSystemFontName()});
    p(&out, "  Mono font     : {s}\n", .{font_loader.getMonoFontName()});
    p(&out, "  CJK font      : {s}\n", .{font_loader.getCjkFontName()});

    // ── Phase 3: Initialize GDI Compositor (no DWM) ──
    p(&out, "\n--- Phase 3: GDI Compositor Init ---\n", .{});

    shell.initShell();
    compositor.init(SCREEN_W, SCREEN_H);

    p(&out, "  DWM enabled    : {}\n", .{root.isDwmEnabled()});
    p(&out, "  Glass effects  : none (GDI-only)\n", .{});
    p(&out, "  Screen size    : {d}x{d}\n", .{ SCREEN_W, SCREEN_H });

    // ── Phase 4: Create Surfaces ──
    p(&out, "\n--- Phase 4: Creating Surfaces ---\n", .{});

    const desktop_surface = compositor.createSurface(SCREEN_W, SCREEN_H, .{
        .has_alpha = false,
        .is_visible = true,
        .is_desktop = true,
    });
    compositor.setSurfaceZOrder(desktop_surface, compositor.DESKTOP_SURFACE_Z);
    p(&out, "  Desktop surface   : id={d}\n", .{desktop_surface});

    const window_surface = compositor.createSurface(520, 380, .{
        .has_alpha = false,
        .is_visible = true,
    });
    compositor.moveSurface(window_surface, 200, 80);
    compositor.setSurfaceZOrder(window_surface, 100);
    p(&out, "  Window surface    : id={d} (flat 3D border)\n", .{window_surface});

    const taskbar_surface = compositor.createSurface(SCREEN_W, 30, .{
        .has_alpha = false,
        .is_visible = true,
    });
    compositor.moveSurface(taskbar_surface, 0, @intCast(SCREEN_H - 30));
    compositor.setSurfaceZOrder(taskbar_surface, 200);
    p(&out, "  Taskbar surface   : id={d} (grey raised)\n", .{taskbar_surface});

    for (os_windows, 0..) |win, i| {
        taskbar.addTask(win.title, win.icon_id);
        p(&out, "  OS Window [{d}]     : \"{s}\" (minimized to taskbar)\n", .{ i, win.title });
    }

    p(&out, "  Total surfaces    : {d}\n", .{compositor.getSurfaceCount()});

    // ── Phase 5: Render Desktop Frame ──
    p(&out, "\n--- Phase 5: GDI Composition ---\n", .{});

    compositor.compose();
    const stats = compositor.getStats();

    p(&out, "  Total frames      : {d}\n", .{stats.total_frames});
    p(&out, "  Dirty frames      : {d}\n", .{stats.dirty_frames});
    p(&out, "  Surfaces composited: {d}\n", .{stats.surfaces_composited});

    // ── Phase 6: Desktop Layout Report ──
    p(&out, "\n--- Phase 6: Desktop Layout ---\n", .{});

    const colors = theme.getActiveColors();
    p(&out, "  Desktop background : 0x{X:0>6}\n", .{colors.desktop_bg});
    p(&out, "  Desktop icons      : {d}\n", .{desktop.getIconCount()});
    for (desktop.getIcons()) |icon| {
        if (icon.visible) {
            p(&out, "    [{d},{d}] {s}\n", .{
                icon.grid_x, icon.grid_y, icon.name[0..icon.name_len],
            });
        }
    }

    p(&out, "  Taskbar height     : {d}px\n", .{root.getTaskbarHeight()});
    p(&out, "  Titlebar height    : {d}px\n", .{root.getTitlebarHeight()});
    p(&out, "  Start button       : \"{s}\" (raised 3D)\n", .{theme.start_label});
    p(&out, "  Start menu         : visible={}\n", .{startmenu.isVisible()});

    // ── Phase 7: Theme Variants ──
    p(&out, "\n--- Phase 7: Available Themes ({d}) ---\n", .{root.getAvailableThemeCount()});
    for (root.available_themes, 0..) |name, i| {
        const marker: []const u8 = if (i == 0) " [active]" else "";
        p(&out, "  [{d}] {s}{s}\n", .{ i, name, marker });
    }

    // ── Phase 8: GDI Rendering Pipeline Summary ──
    p(&out, "\n--- GDI Rendering Pipeline (Classic) ---\n", .{});
    p(&out, "  ┌─────────────────────────────────────────┐\n", .{});
    p(&out, "  │ Application → GDI Device Context         │\n", .{});
    p(&out, "  │         (shared screen DC)               │\n", .{});
    p(&out, "  ├─────────────────────────────────────────┤\n", .{});
    p(&out, "  │ GDI renders directly to framebuffer      │\n", .{});
    p(&out, "  │   ├─ Paint by Z-order (back to front)    │\n", .{});
    p(&out, "  │   ├─ 3D beveled borders (highlight+shadow)│\n", .{});
    p(&out, "  │   ├─ Flat solid color fills              │\n", .{});
    p(&out, "  │   └─ No blur, no glass, no alpha blend   │\n", .{});
    p(&out, "  ├─────────────────────────────────────────┤\n", .{});
    p(&out, "  │ Direct present → Front Buffer            │\n", .{});
    p(&out, "  └─────────────────────────────────────────┘\n", .{});

    // ── Phase 9: Font Integration Summary ──
    p(&out, "\n--- Font Integration (ZirconOSFonts) ---\n", .{});
    p(&out, "  System UI    : {s} ({d}pt)\n", .{ font_loader.getSystemFontName(), theme.FONT_SYSTEM_SIZE });
    p(&out, "  Terminal     : {s} ({d}pt)\n", .{ font_loader.getMonoFontName(), theme.FONT_MONO_SIZE });
    p(&out, "  CJK Fallback : {s}\n", .{font_loader.getCjkFontName()});
    p(&out, "  Title font   : {s} Bold\n", .{font_loader.getSystemFontName()});

    // ── Phase 10: Resource Integration Summary ──
    p(&out, "\n--- Resource Integration (ZirconOSClassic/resources) ---\n", .{});
    p(&out, "  Cursor       : resources/cursors/classic_arrow.svg\n", .{});

    for (resource_loader.getLoadedIcons()) |icon| {
        if (icon.loaded) {
            p(&out, "  Icon         : {s}\n", .{icon.path[0..icon.path_len]});
        }
    }

    p(&out, "\n═══ Classic Desktop Ready ═══\n", .{});
    p(&out, "GDI compositor running with {d} surfaces, dwm=false, flat_3d=true\n", .{
        compositor.getSurfaceCount(),
    });
    p(&out, "OS windows minimized to taskbar: ", .{});
    for (os_windows, 0..) |win, i| {
        if (i > 0) p(&out, ", ", .{});
        p(&out, "{s}", .{win.title});
    }
    p(&out, "\n", .{});
}
