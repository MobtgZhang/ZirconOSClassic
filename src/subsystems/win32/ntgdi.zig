//! ntgdi — GRE 绘制（WM_PAINT、经典浅色桌面布局 + 嵌入式图标）。

const fb = @import("../../hal/fb_console.zig");
const ntuser = @import("ntuser.zig");
const gdi = @import("gdi.zig");
const classic = @import("../../classic/colors.zig");
const ke_timer = @import("../../ke/timer.zig");
const layout = @import("shell_layout.zig");
const shell_state = @import("shell_state.zig");
const cursor_overlay = @import("cursor_overlay.zig");
const res = @import("../../classic/resources/mod.zig");
const smenu = @import("start_menu_data.zig");

pub fn earlyPaintDesktop() void {
    if (!fb.isReady()) return;
    ntuser.dispatchShellStartup();
    paintAllZOrder();
}

fn paintAllZOrder() void {
    paintHwnd(ntuser.HWND_DESKTOP);
    paintHwnd(ntuser.HWND_TASKBAR);
}

pub fn paintHwnd(hwnd: u32) void {
    cursor_overlay.markFramebufferDirty();
    const w = ntuser.getWindow(hwnd) orelse return;
    if (!w.visible) return;

    switch (w.class) {
        .desktop_root => paintDesktopWorkspace(w),
        .shell_tray => paintShellTray(w),
    }
    ntuser.clearPaintQueued(hwnd);
}

fn drawDesktopIconAtIndex(sw: i32, wy: i32, i: u32) void {
    const labels = [_][]const u8{
        "My Documents",
        "My Computer",
        "My Network Places",
        "Recycle Bin",
        "Internet Explorer",
        "Connect to Internet",
    };
    const datas = [_]*const [256]u32{
        &res.my_documents,
        &res.my_computer,
        &res.network_places,
        &res.recycle_bin,
        &res.internet_explorer,
        &res.connect_internet,
    };
    if (i >= labels.len) return;
    const fg = classic.scheme_standard.menu_text;
    const bg = gdi.desktopBackgroundColor();
    const r = layout.desktopIconSlot(sw, wy, i);
    const icon_left = r.x + @divTrunc(r.w - layout.ICON_PIX, 2);
    gdi.blitArgb32Scaled(icon_left, r.y, layout.ICON_SRC, layout.ICON_SRC, layout.ICON_SCALE, datas[i][0..]);
    const ty = r.y + layout.ICON_PIX + 4;
    const max_label_w = r.w - 4;
    const tw = gdi.textWidthPx(labels[i]);
    if (tw <= max_label_w) {
        const text_x = r.x + @divTrunc(r.w - tw, 2);
        gdi.drawTextScreen(text_x, ty, fg, bg, labels[i]);
    } else {
        gdi.drawTextClipped(r.x + 2, ty, fg, bg, labels[i], max_label_w);
    }
}

fn drawDesktopIconColumn(sw: i32, wy: i32) void {
    var i: u32 = 0;
    while (i < 6) : (i += 1) {
        drawDesktopIconAtIndex(sw, wy, i);
    }
}

fn paintStartMenuFull(sw: i32, sh: i32) void {
    if (!ntuser.isStartMenuOpen()) return;
    const root = layout.startMenuFrame(sw, sh);
    const side = layout.startMenuSidebarRect(root);
    const side_bg = classic.rgb(0x80, 0x80, 0x80);
    gdi.fillRectScreen(side.x, side.y, side.w, side.h, side_bg);
    const brand = "ZirconOS";
    var cy: i32 = root.y + 6;
    var bi: usize = 0;
    while (bi < brand.len) : (bi += 1) {
        var ch: [1]u8 = undefined;
        ch[0] = brand[bi];
        gdi.drawTextScreen(side.x + 5, cy, classic.scheme_standard.titlebar_text, side_bg, ch[0..1]);
        cy += 11;
    }

    const body = layout.startMenuBodyRect(root);
    gdi.fillRectScreen(body.x, body.y, body.w, body.h, classic.scheme_standard.button_face);
    gdi.frameRectScreen(root.x, root.y, root.w, root.h, classic.scheme_standard.menu_text);

    var r: u32 = 0;
    while (r < smenu.root_count) : (r += 1) {
        const rr = layout.startMenuRootItemRect(root, r) orelse continue;
        const L = smenu.lineAt(@intCast(r));
        if (L.separator) {
            gdi.fillRectScreen(rr.x, rr.y + 3, rr.w, 2, classic.scheme_standard.shadow_3d);
            continue;
        }
        const hi = if (shell_state.startMenuDrawRootRow()) |h| h == @as(u8, @intCast(r)) else false;
        const bg = if (hi) classic.scheme_standard.menu_highlight_bg else classic.scheme_standard.button_face;
        const fg = if (hi) classic.scheme_standard.menu_highlight_fg else classic.scheme_standard.menu_text;
        gdi.fillRectScreen(rr.x, rr.y, rr.w, rr.h, bg);
        const text_max_root: i32 = if (L.cascade and L.child_count > 0)
            rr.w - 6 - 10 - 8
        else
            rr.w - 12;
        gdi.drawTextClipped(rr.x + 6, rr.y + 4, fg, bg, L.text, text_max_root);
        if (L.cascade and L.child_count > 0) {
            const gt = ">";
            const tw = gdi.textWidthPx(gt);
            gdi.drawTextScreen(rr.x + rr.w - 10 - tw, rr.y + 4, fg, bg, gt);
        }
    }

    var col: u32 = 1;
    while (layout.startMenuCascadeFrame(sw, sh, col)) |cf| {
        gdi.fillRectScreen(cf.x, cf.y, cf.w, cf.h, classic.scheme_standard.button_face);
        gdi.frameRectScreen(cf.x, cf.y, cf.w, cf.h, classic.scheme_standard.menu_text);
        const exp = shell_state.start_menu_expanded_root orelse break;
        var parent_line: u16 = exp;
        var parent_ok: bool = true;
        if (col > 1) {
            var fc: u32 = 1;
            while (fc < col) : (fc += 1) {
                parent_line = smenu.childLineIndex(parent_line, shell_state.start_menu_path[fc - 1]) orelse {
                    parent_ok = false;
                    break;
                };
            }
        }
        if (!parent_ok) {
            col += 1;
            continue;
        }
        const Lp = smenu.lineAt(parent_line);
        const hslot = shell_state.startMenuDrawFlyoutSlot(col);
        var s: u8 = 0;
        while (s < Lp.child_count) : (s += 1) {
            const ir = layout.submenuItemRect(cf, Lp.first_child, Lp.child_count, s) orelse continue;
            const Lc = smenu.lineAt(Lp.first_child + s);
            if (Lc.separator) {
                gdi.fillRectScreen(ir.x, ir.y + 3, ir.w, 2, classic.scheme_standard.shadow_3d);
                continue;
            }
            const hi_c = hslot == s;
            const bg_c = if (hi_c) classic.scheme_standard.menu_highlight_bg else classic.scheme_standard.button_face;
            const fg_c = if (hi_c) classic.scheme_standard.menu_highlight_fg else classic.scheme_standard.menu_text;
            gdi.fillRectScreen(ir.x, ir.y, ir.w, ir.h, bg_c);
            const text_max_sub: i32 = if (Lc.cascade and Lc.child_count > 0)
                ir.w - 6 - 10 - 8
            else
                ir.w - 12;
            gdi.drawTextClipped(ir.x + 6, ir.y + 4, fg_c, bg_c, Lc.text, text_max_sub);
            if (Lc.cascade and Lc.child_count > 0) {
                const gt = ">";
                const tw = gdi.textWidthPx(gt);
                gdi.drawTextScreen(ir.x + ir.w - 10 - tw, ir.y + 4, fg_c, bg_c, gt);
            }
        }
        col += 1;
    }
}

/// 仅重绘与 `damage` 相交的桌面内容（壁纸局部、相关图标、欢迎窗、开始菜单与右键菜单），用于拖动窗口时避免整屏 WM_PAINT 闪屏。
fn paintDesktopWorkspaceDamage(w: ntuser.Window, damage: layout.Rect) void {
    const sw: i32 = @intCast(fb.screenWidth());
    const sh: i32 = @intCast(fb.screenHeight());
    const desk_bounds = layout.Rect{ .x = w.x, .y = w.y, .w = w.w, .h = w.h };
    const d = layout.intersectRects(damage, desk_bounds) orelse return;
    const bg = gdi.desktopBackgroundColor();
    gdi.fillRectScreen(d.x, d.y, d.w, d.h, bg);

    var ii: u32 = 0;
    while (ii < 6) : (ii += 1) {
        const ir = layout.desktopIconSlot(sw, w.y, ii);
        if (layout.rectsIntersect(ir, d)) drawDesktopIconAtIndex(sw, w.y, ii);
    }

    if (shell_state.isWelcomeVisible() and !shell_state.isWelcomeMinimized()) {
        const wo = layout.welcomeOuterFor(sw, sh, shell_state.isWelcomeMaximized());
        if (layout.rectsIntersect(wo, d)) paintWelcomeWindow(sw, sh);
    }

    if (ntuser.isStartMenuOpen()) {
        if (layout.startMenuUnionRect(sw, sh, true)) |uni| {
            if (layout.rectsIntersect(uni, d)) paintStartMenuFull(sw, sh);
        }
    }

    if (shell_state.context_menu_visible) {
        const fr = layout.contextMenuFrame(shell_state.context_menu_x, shell_state.context_menu_y, sw, sh);
        if (layout.rectsIntersect(fr, d)) {
            gdi.fillRectScreen(fr.x, fr.y, fr.w, fr.h, classic.scheme_standard.button_face);
            gdi.frameRectScreen(fr.x, fr.y, fr.w, fr.h, classic.scheme_standard.menu_text);
            const labels = [_][]const u8{ "Refresh", "Properties", "About ZirconOS" };
            var mi: u32 = 0;
            while (mi < 3) : (mi += 1) {
                const item_r = layout.contextMenuItemRect(fr, mi);
                gdi.drawTextScreen(item_r.x + 6, item_r.y + 4, classic.scheme_standard.menu_text, classic.scheme_standard.button_face, labels[mi]);
            }
        }
    }
}

/// 欢迎窗拖动时增量重绘（旧框 ∪ 新框），不投递 WM_PAINT，避免与 `cursor_overlay` 整屏恢复冲突导致闪屏。
pub fn repaintWelcomeDragDamage(old_outer: layout.Rect, new_outer: layout.Rect) void {
    if (!fb.isReady()) return;
    const w = ntuser.getWindow(ntuser.HWND_DESKTOP) orelse return;
    cursor_overlay.markFramebufferDirty();
    const u = layout.unionRects(old_outer, new_outer);
    paintDesktopWorkspaceDamage(w, u);
}

/// 开始菜单高亮/键盘选择变化时仅重绘菜单包围盒（并与上次并集），避免整桌 `WM_PAINT` 铺底色导致闪屏。
pub fn repaintStartMenuOverlayOnly() void {
    if (!fb.isReady() or !ntuser.isStartMenuOpen()) return;
    const sw: i32 = @intCast(fb.screenWidth());
    const sh: i32 = @intCast(fb.screenHeight());
    const cur = layout.startMenuUnionRect(sw, sh, true) orelse return;
    const damage = if (shell_state.start_menu_last_paint_union) |p| blk: {
        const prev = layout.Rect{ .x = p.x, .y = p.y, .w = p.w, .h = p.h };
        break :blk layout.unionRects(prev, cur);
    } else cur;
    const w = ntuser.getWindow(ntuser.HWND_DESKTOP) orelse return;
    cursor_overlay.markFramebufferDirty();
    paintDesktopWorkspaceDamage(w, damage);
    shell_state.start_menu_last_paint_union = .{ .x = cur.x, .y = cur.y, .w = cur.w, .h = cur.h };
}

fn drawWelcomeCaptionGlyph(r: layout.Rect, kind: enum { min, max, close }) void {
    const face = classic.scheme_standard.button_face;
    const hi = classic.scheme_standard.highlight_3d;
    const lo = classic.scheme_standard.shadow_3d;
    const ink = classic.scheme_standard.menu_text;
    gdi.fill3dRaised(r.x, r.y, r.w, r.h, face, hi, lo);
    const cx = r.x + @divTrunc(r.w, 2);
    const cy = r.y + @divTrunc(r.h, 2);
    switch (kind) {
        .min => gdi.fillRectScreen(cx - 4, cy, 8, 1, ink),
        .max => gdi.frameRectScreen(cx - 4, cy - 3, 8, 6, ink),
        .close => {
            var t: i32 = 0;
            while (t < 8) : (t += 1) {
                gdi.fillRectScreen(r.x + 5 + t, r.y + 5 + t, 1, 1, ink);
                gdi.fillRectScreen(r.x + 5 + (7 - t), r.y + 5 + t, 1, 1, ink);
            }
        },
    }
}

fn paintWelcomeWindow(sw: i32, sh: i32) void {
    if (!shell_state.isWelcomeVisible()) return;
    if (shell_state.isWelcomeMinimized()) return;
    const o = layout.welcomeOuterFor(sw, sh, shell_state.isWelcomeMaximized());
    gdi.fill3dRaised(o.x, o.y, o.w, o.h, classic.scheme_standard.button_face, classic.scheme_standard.highlight_3d, classic.scheme_standard.shadow_3d);

    const inner_x = o.x + 3;
    const inner_y = o.y + 3;
    const inner_w = o.w - 6;
    const title_h = layout.WELCOME_TITLE_H;
    gdi.fillRectGradientH(inner_x, inner_y, inner_w, title_h, classic.scheme_standard.titlebar_active, classic.scheme_standard.titlebar_active_right);
    gdi.drawTextClipped(inner_x + 8, inner_y + 6, classic.scheme_standard.titlebar_text, classic.scheme_standard.titlebar_active, "Introduction - ZirconOS Classic", inner_w - 56);

    drawWelcomeCaptionGlyph(layout.welcomeCaptionButton(inner_x, inner_y, inner_w, title_h, 0), .min);
    drawWelcomeCaptionGlyph(layout.welcomeCaptionButton(inner_x, inner_y, inner_w, title_h, 1), .max);
    drawWelcomeCaptionGlyph(layout.welcomeCaptionButton(inner_x, inner_y, inner_w, title_h, 2), .close);

    const body_y = inner_y + title_h;
    const body_h = o.y + o.h - body_y - 3;
    gdi.fillRectScreen(inner_x, body_y, inner_w, body_h, classic.scheme_standard.window_client);

    const body_text_w = inner_w - 24;
    gdi.drawTextClipped(inner_x + 12, body_y + 16, classic.scheme_standard.menu_text, classic.scheme_standard.window_client, "Register Now", body_text_w);
    gdi.fillRectScreen(inner_x + 8, body_y + 32, inner_w - 16, 1, classic.scheme_standard.shadow_3d);
    gdi.drawTextClipped(inner_x + 12, body_y + 40, classic.scheme_standard.menu_text, classic.scheme_standard.window_client, "Discover ZirconOS", body_text_w);
    gdi.fillRectScreen(inner_x + 8, body_y + 56, inner_w - 16, 1, classic.scheme_standard.shadow_3d);
    gdi.drawTextClipped(inner_x + 12, body_y + 64, classic.scheme_standard.menu_text, classic.scheme_standard.window_client, "Connect to Internet", body_text_w);

    gdi.drawTextWrapped(inner_x + 12, body_y + 100, classic.scheme_standard.menu_text, classic.scheme_standard.window_client, "Lightweight classic shell; icons and theme are project-original.", body_text_w, 16, 4);

    const ex = layout.welcomeExitButton(o);
    gdi.fill3dRaised(ex.x, ex.y, ex.w, ex.h, classic.scheme_standard.button_face, classic.scheme_standard.highlight_3d, classic.scheme_standard.shadow_3d);
    gdi.drawTextScreen(ex.x + 12, ex.y + 4, classic.scheme_standard.menu_text, classic.scheme_standard.button_face, "Exit");

    gdi.drawTextClipped(inner_x + 12, o.y + o.h - 36, classic.scheme_standard.menu_text, classic.scheme_standard.window_client, "[ ] Show at startup", body_text_w);
}

fn paintDesktopWorkspace(w: ntuser.Window) void {
    const sw: i32 = @intCast(fb.screenWidth());
    const sh: i32 = @intCast(fb.screenHeight());

    gdi.fillRectScreen(w.x, w.y, w.w, w.h, gdi.desktopBackgroundColor());

    drawDesktopIconColumn(sw, w.y);

    paintWelcomeWindow(sw, sh);

    if (ntuser.isStartMenuOpen()) {
        paintStartMenuFull(sw, sh);
        if (layout.startMenuUnionRect(sw, sh, true)) |uni| {
            shell_state.start_menu_last_paint_union = .{ .x = uni.x, .y = uni.y, .w = uni.w, .h = uni.h };
        }
    } else {
        shell_state.start_menu_last_paint_union = null;
    }

    if (shell_state.context_menu_visible) {
        const fr = layout.contextMenuFrame(shell_state.context_menu_x, shell_state.context_menu_y, sw, sh);
        gdi.fillRectScreen(fr.x, fr.y, fr.w, fr.h, classic.scheme_standard.button_face);
        gdi.frameRectScreen(fr.x, fr.y, fr.w, fr.h, classic.scheme_standard.menu_text);
        const labels = [_][]const u8{ "Refresh", "Properties", "About ZirconOS" };
        var mi: u32 = 0;
        while (mi < 3) : (mi += 1) {
            const ir = layout.contextMenuItemRect(fr, mi);
            gdi.drawTextScreen(ir.x + 6, ir.y + 4, classic.scheme_standard.menu_text, classic.scheme_standard.button_face, labels[mi]);
        }
    }
}

/// 经典四色窗格徽标，边长约 `layout.START_BTN_GLYPH`。
fn drawWindowsStartFlag(bx: i32, by: i32) void {
    const u: i32 = 3;
    const gap: i32 = 1;
    gdi.fillRectScreen(bx, by, u, u, classic.rgb(0x00, 0x48, 0xB8));
    gdi.fillRectScreen(bx + u + gap, by, u, u, classic.rgb(0xD8, 0x20, 0x28));
    gdi.fillRectScreen(bx, by + u + gap, u, u, classic.rgb(0x20, 0xA8, 0x28));
    gdi.fillRectScreen(bx + u + gap, by + u + gap, u, u, classic.rgb(0xE8, 0x98, 0x00));
}

fn paintShellTray(w: ntuser.Window) void {
    const sw: i32 = @intCast(fb.screenWidth());
    const sh: i32 = @intCast(fb.screenHeight());

    gdi.fillRectScreen(w.x, w.y, w.w, w.h, classic.scheme_standard.button_face);
    gdi.frameRectScreen(w.x, w.y, w.w, w.h, classic.scheme_standard.menu_text);

    const sr = layout.startButtonRect(sh);
    gdi.fill3dRaised(sr.x, sr.y, sr.w, sr.h, classic.scheme_standard.button_face, classic.scheme_standard.highlight_3d, classic.scheme_standard.shadow_3d);
    const start_label = "Start";
    const glyph = layout.START_BTN_GLYPH;
    const gap = layout.START_BTN_GAP;
    const text_w = layout.textWidthChars(start_label.len);
    const content_w = glyph + gap + text_w;
    const text_h: i32 = 16;
    const inner_left = sr.x + @divTrunc(sr.w - content_w, 2);
    const inner_top = sr.y + @divTrunc(sr.h - text_h, 2);
    const glyph_y = inner_top + @divTrunc(text_h - glyph, 2);
    drawWindowsStartFlag(inner_left, glyph_y);
    gdi.drawTextScreen(inner_left + glyph + gap, inner_top, classic.scheme_standard.menu_text, classic.scheme_standard.button_face, start_label);

    const ql = layout.quickLaunchOuter(sw, sh);
    if (ql.w > 0) {
        gdi.fill3dSunken(ql.x, ql.y, ql.w, ql.h, classic.scheme_standard.button_face, classic.scheme_standard.highlight_3d, classic.scheme_standard.shadow_3d);
        const qy = ql.y + 3;
        const fac = classic.scheme_standard.button_face;
        gdi.fillRectScreen(ql.x + 4, qy, 16, 11, fac);
        gdi.fillRectScreen(ql.x + 6, qy + 12, 12, 3, classic.rgb(0x18, 0x48, 0xA8));
        gdi.blitArgb32Scaled(ql.x + 28, qy, layout.ICON_SRC, layout.ICON_SRC, 1, res.internet_explorer[0..]);
        gdi.blitArgb32Scaled(ql.x + 52, qy, layout.ICON_SRC, layout.ICON_SRC, 1, res.connect_internet[0..]);
        gdi.blitArgb32Scaled(ql.x + 76, qy, layout.ICON_SRC, layout.ICON_SRC, 1, res.my_documents[0..]);
    }

    const welcome_task_label = "Introduction...";
    const n_strip = shell_state.taskStripButtonCount();
    if (n_strip > 0 and layout.taskListOuter(sw, sh).w > 0) {
        var bi: u32 = 0;
        while (bi < n_strip) : (bi += 1) {
            const br = layout.taskStripButtonRect(sw, sh, bi, n_strip) orelse continue;
            var sunken = false;
            if (shell_state.isWelcomeVisible() and bi == 0) {
                sunken = !shell_state.isWelcomeMinimized() and
                    (shell_state.shell_task_focus == .welcome or
                    (shell_state.shell_task_focus == .none and shell_state.shell_task_count == 0));
            } else {
                const app_slot: u32 = if (shell_state.isWelcomeVisible()) bi - 1 else bi;
                sunken = shell_state.shell_task_focus == .app and shell_state.shell_focused_task_slot == app_slot;
            }
            if (sunken) {
                gdi.fill3dSunken(br.x, br.y, br.w, br.h, classic.scheme_standard.button_face, classic.scheme_standard.highlight_3d, classic.scheme_standard.shadow_3d);
            } else {
                gdi.fill3dRaised(br.x, br.y, br.w, br.h, classic.scheme_standard.button_face, classic.scheme_standard.highlight_3d, classic.scheme_standard.shadow_3d);
            }
            const label: []const u8 = if (shell_state.isWelcomeVisible() and bi == 0)
                welcome_task_label
            else
                shell_state.shellTaskTitleSlice(if (shell_state.isWelcomeVisible()) @intCast(bi - 1) else @intCast(bi));
            const max_tw = br.w - 8;
            const tx = br.x + 4;
            const ty = br.y + @divTrunc(br.h - text_h, 2);
            gdi.fillRectScreen(tx, ty, @max(0, max_tw), text_h, classic.scheme_standard.button_face);
            gdi.drawTextClipped(tx, ty, classic.scheme_standard.menu_text, classic.scheme_standard.button_face, label, max_tw);
        }
    } else {
        const tb = layout.taskButtonRect(sw, sh);
        if (tb.w > 0 and shell_state.isWelcomeVisible()) {
            if (shell_state.isWelcomeMinimized()) {
                gdi.fill3dRaised(tb.x, tb.y, tb.w, tb.h, classic.scheme_standard.button_face, classic.scheme_standard.highlight_3d, classic.scheme_standard.shadow_3d);
            } else {
                gdi.fill3dSunken(tb.x, tb.y, tb.w, tb.h, classic.scheme_standard.button_face, classic.scheme_standard.highlight_3d, classic.scheme_standard.shadow_3d);
            }
            const max_tw = tb.w - 8;
            const tx = tb.x + 4;
            const ty = tb.y + @divTrunc(tb.h - text_h, 2);
            gdi.fillRectScreen(tx, ty, @max(0, max_tw), text_h, classic.scheme_standard.button_face);
            gdi.drawTextClipped(tx, ty, classic.scheme_standard.menu_text, classic.scheme_standard.button_face, welcome_task_label, max_tw);
        }
    }

    const tr = layout.trayOuter(sw, sh);
    gdi.fill3dSunken(tr.x, tr.y, tr.w, tr.h, classic.scheme_standard.button_face, classic.scheme_standard.highlight_3d, classic.scheme_standard.shadow_3d);
    gdi.frameRectScreen(tr.x + 2, tr.y + 2, tr.w - 4, tr.h - 4, classic.scheme_standard.shadow_3d);
    gdi.frameRectScreen(tr.x + 3, tr.y + 3, tr.w - 6, tr.h - 6, classic.scheme_standard.highlight_3d);
    // 打印机、音量、语言、时钟（仿经典托盘）
    gdi.fillRectScreen(tr.x + 8, tr.y + 6, 12, 10, classic.scheme_standard.menu_text);
    gdi.fillRectScreen(tr.x + 10, tr.y + 4, 8, 3, classic.scheme_standard.button_face);
    gdi.fillRectScreen(tr.x + 26, tr.y + 5, 10, 12, classic.scheme_standard.menu_text);
    gdi.fillRectScreen(tr.x + 28, tr.y + 7, 2, 8, classic.scheme_standard.button_face);

    gdi.fillRectScreen(tr.x + 42, tr.y + 4, 22, 14, classic.rgb(0x00, 0x40, 0xC0));
    gdi.drawTextScreen(tr.x + 45, tr.y + 5, classic.scheme_standard.titlebar_text, classic.rgb(0x00, 0x40, 0xC0), "EN");

    var buf: [8]u8 = undefined;
    const clock_str = formatClock(&buf);
    gdi.drawTextScreen(tr.x + 72, tr.y + 4, classic.scheme_standard.menu_text, classic.scheme_standard.button_face, clock_str);
}

fn formatClock(buf: *[8]u8) []const u8 {
    const hz: u64 = ke_timer.getHz();
    const ticks = ke_timer.getTicks();
    const sec = ticks / hz;
    const mins_total = sec / 60;
    const h = (mins_total / 60) % 24;
    const m = mins_total % 60;
    buf[0] = digit(@intCast(h / 10));
    buf[1] = digit(@intCast(h % 10));
    buf[2] = ':';
    buf[3] = digit(@intCast(m / 10));
    buf[4] = digit(@intCast(m % 10));
    return buf[0..5];
}

fn digit(d: u8) u8 {
    const dd: u8 = if (d > 9) 9 else d;
    return '0' + dd;
}

pub fn defWindowProc(hwnd: u32, msg: ntuser.MsgId, wparam: usize, lparam: usize) void {
    _ = wparam;
    _ = lparam;
    if (msg == .wm_paint) {
        paintHwnd(hwnd);
    }
}

pub fn isWelcomeVisible() bool {
    return shell_state.isWelcomeVisible();
}

pub fn setWelcomeVisible(v: bool) void {
    shell_state.setWelcomeVisible(v);
}
