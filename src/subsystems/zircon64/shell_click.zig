//! 鼠标左键命中（与 shell_layout / ntgdi 一致）+ 开始菜单级联悬停与键盘。

const std = @import("std");
const klog = @import("../../rtl/klog.zig");
const ke_timer = @import("../../ke/timer.zig");
const fb = @import("../../hal/fb_console.zig");
const ntuser = @import("ntuser.zig");
const ntgdi = @import("ntgdi.zig");
const layout = @import("shell_layout.zig");
const shell_state = @import("shell_state.zig");
const smenu = @import("start_menu_data.zig");

const cascade_delay_ticks: u64 = 20;

fn deadlineNow() u64 {
    return ke_timer.getTicks() + cascade_delay_ticks;
}

pub fn onStartMenuCommand(cmd: smenu.Cmd, menu_label: []const u8) void {
    if (cmd == .none) return;
    const title: []const u8 = switch (cmd) {
        .help => "Help",
        .run_dialog => "Run",
        .standby => "Suspend",
        .shutdown => "Shut Down",
        .my_documents => "My Documents",
        .control_panel => "Control Panel",
        .internet_explorer => "Internet Explorer",
        .notepad => "Notepad",
        .paint => "Paint",
        .ms_dos => "MS-DOS Prompt",
        .win_explorer => "Windows Explorer",
        .generic_launch => menu_label,
        .none => return,
    };
    klog.info("SHELL: start menu cmd=%u %s", .{ @intFromEnum(cmd), title });
    shell_state.appendShellTask(title);
    ntuser.invalidateWindow(ntuser.HWND_TASKBAR);
}

pub fn pumpStartMenuTimers() void {
    if (shell_state.pumpStartMenuDelays(ke_timer.getTicks())) {
        ntgdi.repaintStartMenuOverlayOnly();
    }
}

pub fn pumpStartMenuPointers(px: i32, py: i32) void {
    if (!ntuser.isStartMenuOpen()) return;
    const sw: i32 = @intCast(fb.screenWidth());
    const sh: i32 = @intCast(fb.screenHeight());
    handlePointerMove(px, py, sw, sh);
}

fn handlePointerMove(px: i32, py: i32, sw: i32, sh: i32) void {
    const open = ntuser.isStartMenuOpen();
    if (!layout.startMenuOrCascadeContains(px, py, sw, sh, open)) {
        var had_hover = shell_state.start_menu_hover_root != null;
        if (!had_hover) {
            for (shell_state.start_menu_hover_slots) |s| {
                if (s != shell_state.sm_slot_none) {
                    had_hover = true;
                    break;
                }
            }
        }
        shell_state.start_menu_hover_root = null;
        @memset(shell_state.start_menu_hover_slots[0..], shell_state.sm_slot_none);
        shell_state.start_menu_delay_armed = false;
        shell_state.start_menu_delay_kind = .none;
        shell_state.start_menu_kb_mode = false;
        if (had_hover) ntgdi.repaintStartMenuOverlayOnly();
        return;
    }

    shell_state.start_menu_kb_mode = false;

    const root = layout.startMenuFrame(sw, sh);
    if (layout.startMenuSidebarRect(root).contains(px, py)) {
        var had_hover = shell_state.start_menu_hover_root != null;
        if (!had_hover) {
            for (shell_state.start_menu_hover_slots) |s| {
                if (s != shell_state.sm_slot_none) {
                    had_hover = true;
                    break;
                }
            }
        }
        shell_state.start_menu_hover_root = null;
        @memset(shell_state.start_menu_hover_slots[0..], shell_state.sm_slot_none);
        if (had_hover) ntgdi.repaintStartMenuOverlayOnly();
        return;
    }

    if (layout.startMenuBodyRect(root).contains(px, py)) {
        var prev_slots: [smenu.max_cascade_depth]u8 = undefined;
        @memcpy(prev_slots[0..], shell_state.start_menu_hover_slots[0..]);
        const prev_root = shell_state.start_menu_hover_root;
        const prev_path_len = shell_state.start_menu_path_len;
        var prev_path: [smenu.max_cascade_depth]u8 = undefined;
        @memcpy(prev_path[0..], shell_state.start_menu_path[0..]);

        @memset(shell_state.start_menu_hover_slots[0..], shell_state.sm_slot_none);
        var r: u32 = 0;
        while (r < smenu.root_count) : (r += 1) {
            const rr = layout.startMenuRootItemRect(root, r) orelse continue;
            if (!rr.contains(px, py)) continue;
            const L = smenu.lineAt(@intCast(r));
            if (L.separator) return;
            shell_state.start_menu_hover_root = @intCast(r);
            var path_changed = false;
            if (L.cascade) {
                if (shell_state.start_menu_expanded_root == null or shell_state.start_menu_expanded_root.? != r) {
                    shell_state.armStartMenuDelayExpandRoot(@intCast(r), deadlineNow());
                }
            } else {
                shell_state.start_menu_delay_armed = false;
                shell_state.start_menu_expanded_root = null;
                shell_state.start_menu_path_len = 0;
                @memset(shell_state.start_menu_path[0..], 0);
                path_changed = true;
            }
            const new_row: u8 = @intCast(r);
            const root_changed = if (prev_root) |p| p != new_row else true;
            const slots_changed = !std.mem.eql(u8, prev_slots[0..], shell_state.start_menu_hover_slots[0..]);
            const path_dirty = path_changed or prev_path_len != shell_state.start_menu_path_len or
                !std.mem.eql(u8, prev_path[0..], shell_state.start_menu_path[0..]);
            if (root_changed or slots_changed or path_dirty) ntgdi.repaintStartMenuOverlayOnly();
            return;
        }
        return;
    }

    var prev_slots_c: [smenu.max_cascade_depth]u8 = undefined;
    @memcpy(prev_slots_c[0..], shell_state.start_menu_hover_slots[0..]);
    const prev_root_c = shell_state.start_menu_hover_root;
    const prev_path_len_c = shell_state.start_menu_path_len;
    var prev_path_c: [smenu.max_cascade_depth]u8 = undefined;
    @memcpy(prev_path_c[0..], shell_state.start_menu_path[0..]);

    shell_state.start_menu_hover_root = null;
    var col: u32 = 1;
    while (layout.startMenuCascadeFrame(sw, sh, col)) |_| {
        if (layout.hitTestCascadeSlot(sw, sh, col, px, py)) |slot| {
            @memset(shell_state.start_menu_hover_slots[0..], shell_state.sm_slot_none);
            var i: usize = 0;
            while (i + 1 < col) : (i += 1) {
                shell_state.start_menu_hover_slots[i] = shell_state.start_menu_path[i];
            }
            shell_state.start_menu_hover_slots[col - 1] = slot;

            const exp = shell_state.start_menu_expanded_root orelse return;
            var parent_line: u16 = exp;
            var path_changed_c = false;
            if (col == 1) {
                const child_line = smenu.childLineIndex(parent_line, slot) orelse return;
                const Lc = smenu.lineAt(child_line);
                if (Lc.cascade and Lc.child_count > 0) {
                    if (shell_state.start_menu_path_len < 1 or shell_state.start_menu_path[0] != slot) {
                        shell_state.armStartMenuDelayPathSlot(1, slot, deadlineNow());
                    }
                } else {
                    shell_state.start_menu_delay_armed = false;
                    shell_state.start_menu_path_len = 1;
                    shell_state.start_menu_path[0] = slot;
                    var zz: usize = 1;
                    while (zz < smenu.max_cascade_depth) : (zz += 1) {
                        shell_state.start_menu_path[zz] = 0;
                    }
                    path_changed_c = true;
                }
            } else {
                var fc: u32 = 1;
                while (fc < col) : (fc += 1) {
                    parent_line = smenu.childLineIndex(parent_line, shell_state.start_menu_path[fc - 1]) orelse return;
                }
                const child_line2 = smenu.childLineIndex(parent_line, slot) orelse return;
                const Lc2 = smenu.lineAt(child_line2);
                if (Lc2.cascade and Lc2.child_count > 0) {
                    if (shell_state.start_menu_path_len < col or shell_state.start_menu_path[col - 1] != slot) {
                        shell_state.armStartMenuDelayPathSlot(@intCast(col), slot, deadlineNow());
                    }
                } else {
                    shell_state.start_menu_delay_armed = false;
                    shell_state.start_menu_path_len = @intCast(col);
                    shell_state.start_menu_path[col - 1] = slot;
                    var zz2: usize = col;
                    while (zz2 < smenu.max_cascade_depth) : (zz2 += 1) {
                        shell_state.start_menu_path[zz2] = 0;
                    }
                    path_changed_c = true;
                }
            }
            const root_cleared = prev_root_c != null;
            const slots_changed_c = !std.mem.eql(u8, prev_slots_c[0..], shell_state.start_menu_hover_slots[0..]);
            const path_dirty_c = path_changed_c or prev_path_len_c != shell_state.start_menu_path_len or
                !std.mem.eql(u8, prev_path_c[0..], shell_state.start_menu_path[0..]);
            if (root_cleared or slots_changed_c or path_dirty_c) ntgdi.repaintStartMenuOverlayOnly();
            return;
        }
        col += 1;
    }
}

fn tryMenuClick(px: i32, py: i32, sw: i32, sh: i32) bool {
    const open = ntuser.isStartMenuOpen();
    if (!open) return false;
    if (!layout.startMenuOrCascadeContains(px, py, sw, sh, open)) return false;

    const root = layout.startMenuFrame(sw, sh);
    if (layout.startMenuSidebarRect(root).contains(px, py)) return true;

    if (layout.startMenuBodyRect(root).contains(px, py)) {
        var r: u32 = 0;
        while (r < smenu.root_count) : (r += 1) {
            const rr = layout.startMenuRootItemRect(root, r) orelse continue;
            if (!rr.contains(px, py)) continue;
            const L = smenu.lineAt(@intCast(r));
            if (L.separator) return true;
            if (L.cascade) {
                shell_state.start_menu_expanded_root = @intCast(r);
                shell_state.start_menu_path_len = 0;
                @memset(shell_state.start_menu_path[0..], 0);
                shell_state.start_menu_delay_armed = false;
            } else {
                onStartMenuCommand(L.cmd, L.text);
                ntuser.closeStartMenu();
            }
            return true;
        }
        return true;
    }

    var col: u32 = 1;
    while (layout.startMenuCascadeFrame(sw, sh, col)) |_| {
        if (layout.hitTestCascadeSlot(sw, sh, col, px, py)) |slot| {
            const exp = shell_state.start_menu_expanded_root orelse return true;
            var parent_line: u16 = exp;
            if (col > 1) {
                var fc: u32 = 1;
                while (fc < col) : (fc += 1) {
                    parent_line = smenu.childLineIndex(parent_line, shell_state.start_menu_path[fc - 1]) orelse return true;
                }
            }
            const child_line = smenu.childLineIndex(parent_line, slot) orelse return true;
            const Lc = smenu.lineAt(child_line);
            if (Lc.cascade and Lc.child_count > 0) {
                shell_state.start_menu_path_len = @intCast(col);
                shell_state.start_menu_path[col - 1] = slot;
                var zz: usize = col;
                while (zz < smenu.max_cascade_depth) : (zz += 1) {
                    shell_state.start_menu_path[zz] = 0;
                }
                shell_state.start_menu_delay_armed = false;
            } else {
                onStartMenuCommand(Lc.cmd, Lc.text);
                ntuser.closeStartMenu();
            }
            return true;
        }
        col += 1;
    }
    return true;
}

/// 方向键 / 回车；已处理返回 `true`（不交给 Win 键等默认处理）。
pub fn startMenuHandleKeyDown(vk: u32) bool {
    if (!ntuser.isStartMenuOpen()) return false;
    shell_state.start_menu_kb_mode = true;

    switch (vk) {
        0x26 => { // up
            if (shell_state.start_menu_kb_path_len == 0) {
                if (shell_state.start_menu_kb_root_row > 0) {
                    shell_state.start_menu_kb_root_row -= 1;
                    if (smenu.lineAt(shell_state.start_menu_kb_root_row).separator and shell_state.start_menu_kb_root_row > 0) {
                        shell_state.start_menu_kb_root_row -= 1;
                    }
                }
            } else {
                const col = shell_state.start_menu_kb_path_len;
                if (shell_state.start_menu_kb_path[col - 1] > 0) {
                    shell_state.start_menu_kb_path[col - 1] -= 1;
                }
            }
            syncKbToPath();
            ntgdi.repaintStartMenuOverlayOnly();
            return true;
        },
        0x28 => { // down
            if (shell_state.start_menu_kb_path_len == 0) {
                if (shell_state.start_menu_kb_root_row + 1 < smenu.root_count) {
                    shell_state.start_menu_kb_root_row += 1;
                    if (smenu.lineAt(shell_state.start_menu_kb_root_row).separator and shell_state.start_menu_kb_root_row + 1 < smenu.root_count) {
                        shell_state.start_menu_kb_root_row += 1;
                    }
                }
            } else {
                const col = shell_state.start_menu_kb_path_len;
                const exp = shell_state.start_menu_expanded_root orelse return true;
                var parent_line: u16 = exp;
                if (col > 1) {
                    var fc: u32 = 1;
                    while (fc < col) : (fc += 1) {
                        parent_line = smenu.childLineIndex(parent_line, shell_state.start_menu_kb_path[fc - 1]) orelse return true;
                    }
                }
                const Lp = smenu.lineAt(parent_line);
                if (shell_state.start_menu_kb_path[col - 1] + 1 < Lp.child_count) {
                    shell_state.start_menu_kb_path[col - 1] += 1;
                }
            }
            syncKbToPath();
            ntgdi.repaintStartMenuOverlayOnly();
            return true;
        },
        0x27 => { // right
            if (shell_state.start_menu_kb_path_len == 0) {
                const L = smenu.lineAt(shell_state.start_menu_kb_root_row);
                if (L.cascade and L.child_count > 0) {
                    shell_state.start_menu_expanded_root = shell_state.start_menu_kb_root_row;
                    shell_state.start_menu_kb_path_len = 1;
                    shell_state.start_menu_kb_path[0] = 0;
                    var z: usize = 1;
                    while (z < smenu.max_cascade_depth) : (z += 1) {
                        shell_state.start_menu_kb_path[z] = 0;
                    }
                }
            } else {
                const col = shell_state.start_menu_kb_path_len;
                const exp = shell_state.start_menu_expanded_root orelse return true;
                var parent_line: u16 = exp;
                if (col > 1) {
                    var fc: u32 = 1;
                    while (fc < col) : (fc += 1) {
                        parent_line = smenu.childLineIndex(parent_line, shell_state.start_menu_kb_path[fc - 1]) orelse return true;
                    }
                }
                const slot = shell_state.start_menu_kb_path[col - 1];
                const child_line = smenu.childLineIndex(parent_line, slot) orelse return true;
                const Lc = smenu.lineAt(child_line);
                if (Lc.cascade and Lc.child_count > 0) {
                    if (shell_state.start_menu_kb_path_len < smenu.max_cascade_depth) {
                        shell_state.start_menu_kb_path_len += 1;
                        shell_state.start_menu_kb_path[shell_state.start_menu_kb_path_len - 1] = 0;
                    }
                }
            }
            syncKbToPath();
            ntgdi.repaintStartMenuOverlayOnly();
            return true;
        },
        0x25 => { // left
            if (shell_state.start_menu_kb_path_len > 0) {
                shell_state.start_menu_kb_path_len -= 1;
                if (shell_state.start_menu_kb_path_len == 0) {
                    shell_state.start_menu_expanded_root = null;
                }
                var z: usize = shell_state.start_menu_kb_path_len;
                while (z < smenu.max_cascade_depth) : (z += 1) {
                    shell_state.start_menu_kb_path[z] = 0;
                }
            }
            syncKbToPath();
            ntgdi.repaintStartMenuOverlayOnly();
            return true;
        },
        0x0D => { // enter
            if (shell_state.start_menu_kb_path_len == 0) {
                const L = smenu.lineAt(shell_state.start_menu_kb_root_row);
                if (L.separator) return true;
                if (L.cascade) {
                    shell_state.start_menu_expanded_root = shell_state.start_menu_kb_root_row;
                    shell_state.start_menu_kb_path_len = 1;
                    shell_state.start_menu_kb_path[0] = 0;
                } else {
                    onStartMenuCommand(L.cmd, L.text);
                    ntuser.closeStartMenu();
                }
            } else {
                const col = shell_state.start_menu_kb_path_len;
                const exp = shell_state.start_menu_expanded_root orelse return true;
                var parent_line: u16 = exp;
                if (col > 1) {
                    var fc: u32 = 1;
                    while (fc < col) : (fc += 1) {
                        parent_line = smenu.childLineIndex(parent_line, shell_state.start_menu_kb_path[fc - 1]) orelse return true;
                    }
                }
                const slot = shell_state.start_menu_kb_path[col - 1];
                const child_line = smenu.childLineIndex(parent_line, slot) orelse return true;
                const Lc = smenu.lineAt(child_line);
                if (Lc.cascade and Lc.child_count > 0) {
                    if (shell_state.start_menu_kb_path_len < smenu.max_cascade_depth) {
                        shell_state.start_menu_kb_path_len += 1;
                        shell_state.start_menu_kb_path[shell_state.start_menu_kb_path_len - 1] = 0;
                    }
                } else {
                    onStartMenuCommand(Lc.cmd, Lc.text);
                    ntuser.closeStartMenu();
                }
            }
            syncKbToPath();
            ntgdi.repaintStartMenuOverlayOnly();
            return true;
        },
        else => return false,
    }
}

fn syncKbToPath() void {
    shell_state.start_menu_path_len = shell_state.start_menu_kb_path_len;
    @memcpy(shell_state.start_menu_path[0..], shell_state.start_menu_kb_path[0..]);
    if (shell_state.start_menu_kb_path_len == 0) {
        shell_state.start_menu_expanded_root = null;
    } else {
        shell_state.start_menu_expanded_root = shell_state.start_menu_kb_root_row;
    }
}

/// 每帧调用：左键按住时在标题栏发起的拖动更新窗口位置。
pub fn pumpWelcomeDrag(px: i32, py: i32, left_down: bool) void {
    if (!shell_state.welcome_dragging) return;
    if (!fb.isReady()) return;
    if (!shell_state.isWelcomeVisible() or shell_state.isWelcomeMinimized() or shell_state.isWelcomeMaximized()) {
        shell_state.welcome_dragging = false;
        return;
    }
    if (!left_down) {
        shell_state.welcome_dragging = false;
        return;
    }
    const sw: i32 = @intCast(fb.screenWidth());
    const sh: i32 = @intCast(fb.screenHeight());
    const nx = px - shell_state.welcome_drag_grab_dx;
    const ny = py - shell_state.welcome_drag_grab_dy;
    const c = layout.clampWelcomeWindowTopLeft(sw, sh, nx, ny);
    const ox = shell_state.welcome_win_x;
    const oy = shell_state.welcome_win_y;
    if (c.x == ox and c.y == oy) return;
    const old_outer = layout.Rect{ .x = ox, .y = oy, .w = layout.WELCOME_W, .h = layout.WELCOME_H };
    shell_state.welcome_win_x = c.x;
    shell_state.welcome_win_y = c.y;
    shell_state.welcome_pos_custom = true;
    const new_outer = layout.Rect{ .x = c.x, .y = c.y, .w = layout.WELCOME_W, .h = layout.WELCOME_H };
    ntgdi.repaintWelcomeDragDamage(old_outer, new_outer);
}

pub fn handleLeftDown(px: i32, py: i32) void {
    if (!fb.isReady()) return;
    const sw: i32 = @intCast(fb.screenWidth());
    const sh: i32 = @intCast(fb.screenHeight());
    const desk = ntuser.getWindow(ntuser.HWND_DESKTOP) orelse return;

    if (shell_state.context_menu_visible) {
        const fr = layout.contextMenuFrame(shell_state.context_menu_x, shell_state.context_menu_y, sw, sh);
        if (!fr.contains(px, py)) {
            shell_state.context_menu_visible = false;
            ntuser.invalidateWindow(ntuser.HWND_DESKTOP);
        } else {
            var i: u32 = 0;
            while (i < 3) : (i += 1) {
                const ir = layout.contextMenuItemRect(fr, i);
                if (ir.contains(px, py)) {
                    shell_state.context_menu_visible = false;
                    switch (i) {
                        0 => ntuser.invalidateDesktopVisual(),
                        1 => klog.info("SHELL: context menu Properties", .{}),
                        else => klog.info("SHELL: context menu About", .{}),
                    }
                    ntuser.invalidateWindow(ntuser.HWND_DESKTOP);
                    return;
                }
            }
            return;
        }
    }

    if (shell_state.isWelcomeVisible()) {
        const wo = layout.welcomeOuterFor(sw, sh, shell_state.isWelcomeMaximized());
        if (!shell_state.isWelcomeMinimized()) {
            const inner_x = wo.x + 3;
            const inner_y = wo.y + 3;
            const inner_w = wo.w - 6;
            const title_h = layout.WELCOME_TITLE_H;
            var cap: u32 = 0;
            while (cap < 3) : (cap += 1) {
                const cr = layout.welcomeCaptionButton(inner_x, inner_y, inner_w, title_h, cap);
                if (cr.contains(px, py)) {
                    switch (cap) {
                        0 => {
                            shell_state.setWelcomeMinimized(true);
                            ntuser.invalidateDesktopVisual();
                        },
                        1 => {
                            shell_state.toggleWelcomeMaximized();
                            ntuser.invalidateDesktopVisual();
                        },
                        else => {
                            shell_state.setWelcomeVisible(false);
                            ntuser.invalidateDesktopVisual();
                        },
                    }
                    return;
                }
            }
            const title_r = layout.Rect{
                .x = inner_x,
                .y = inner_y,
                .w = inner_w,
                .h = title_h,
            };
            if (!shell_state.isWelcomeMaximized() and title_r.contains(px, py)) {
                if (!shell_state.welcome_pos_custom) {
                    const def = layout.welcomeOuter(sw, sh);
                    shell_state.welcome_win_x = def.x;
                    shell_state.welcome_win_y = def.y;
                    shell_state.welcome_pos_custom = true;
                }
                shell_state.welcome_dragging = true;
                shell_state.welcome_drag_grab_dx = px - shell_state.welcome_win_x;
                shell_state.welcome_drag_grab_dy = py - shell_state.welcome_win_y;
                return;
            }
            const ex = layout.welcomeExitButton(wo);
            if (ex.contains(px, py)) {
                shell_state.setWelcomeVisible(false);
                ntuser.invalidateDesktopVisual();
                return;
            }
            if (wo.contains(px, py)) return;
        }
    }

    if (layout.startButtonRect(sh).contains(px, py)) {
        ntuser.toggleStartMenu();
        return;
    }

    if (py >= sh - layout.TASKBAR_H) {
        const nbtn = shell_state.taskStripButtonCount();
        if (nbtn > 0) {
            var ti: u32 = 0;
            while (ti < nbtn) : (ti += 1) {
                const br = layout.taskStripButtonRect(sw, sh, ti, nbtn) orelse continue;
                if (!br.contains(px, py)) continue;
                if (ntuser.isStartMenuOpen()) ntuser.closeStartMenu();
                if (shell_state.isWelcomeVisible() and ti == 0) {
                    shell_state.shell_task_focus = .welcome;
                    if (shell_state.isWelcomeMinimized()) shell_state.setWelcomeMinimized(false);
                } else {
                    const slot: u8 = if (shell_state.isWelcomeVisible()) @intCast(ti - 1) else @intCast(ti);
                    shell_state.shell_task_focus = .app;
                    shell_state.shell_focused_task_slot = slot;
                }
                ntuser.invalidateDesktopVisual();
                return;
            }
        }
    }

    if (ntuser.isStartMenuOpen()) {
        if (tryMenuClick(px, py, sw, sh)) {
            ntuser.invalidateDesktopVisual();
            return;
        }
    }

    if (py >= sh - layout.TASKBAR_H) {
        if (ntuser.isStartMenuOpen() and !layout.startButtonRect(sh).contains(px, py)) {
            ntuser.closeStartMenu();
            ntuser.invalidateDesktopVisual();
            return;
        }
    }

    var i: u32 = 0;
    while (i < 6) : (i += 1) {
        const r = layout.desktopIconSlot(sw, desk.y, i);
        if (r.contains(px, py)) {
            klog.info("SHELL: desktop icon click slot=%u", .{i});
            ntuser.invalidateWindow(ntuser.HWND_DESKTOP);
            return;
        }
    }

    if (ntuser.isStartMenuOpen()) {
        ntuser.closeStartMenu();
        ntuser.invalidateDesktopVisual();
    }
}

pub fn handleRightDown(px: i32, py: i32) void {
    if (!fb.isReady()) return;
    const sw: i32 = @intCast(fb.screenWidth());
    const sh: i32 = @intCast(fb.screenHeight());
    if (py >= sh - layout.TASKBAR_H) return;

    if (shell_state.isWelcomeVisible()) {
        const wo = layout.welcomeOuterFor(sw, sh, shell_state.isWelcomeMaximized());
        if (!shell_state.isWelcomeMinimized() and wo.contains(px, py)) return;
    }

    const desk = ntuser.getWindow(ntuser.HWND_DESKTOP) orelse return;
    if (px < desk.x or py < desk.y or px >= desk.x + desk.w or py >= desk.y + desk.h) return;

    if (ntuser.isStartMenuOpen()) ntuser.closeStartMenu();

    shell_state.context_menu_visible = true;
    shell_state.context_menu_x = px;
    shell_state.context_menu_y = py;
    ntuser.invalidateWindow(ntuser.HWND_DESKTOP);
}
