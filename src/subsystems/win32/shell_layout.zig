//! 与 `ntgdi` 绘制一致的几何，供鼠标命中测试。

pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn contains(r: Rect, px: i32, py: i32) bool {
        return px >= r.x and py >= r.y and px < r.x + r.w and py < r.y + r.h;
    }
};

pub fn rectsIntersect(a: Rect, b: Rect) bool {
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y;
}

pub fn unionRects(a: Rect, b: Rect) Rect {
    const x0 = @min(a.x, b.x);
    const y0 = @min(a.y, b.y);
    const x1 = @max(a.x + a.w, b.x + b.w);
    const y1 = @max(a.y + a.h, b.y + b.h);
    return .{ .x = x0, .y = y0, .w = x1 - x0, .h = y1 - y0 };
}

/// 将 `a` 裁到与 `clip` 重叠的矩形；无重叠返回 `null`。
pub fn intersectRects(a: Rect, clip: Rect) ?Rect {
    const x0 = @max(a.x, clip.x);
    const y0 = @max(a.y, clip.y);
    const x1 = @min(a.x + a.w, clip.x + clip.w);
    const y1 = @min(a.y + a.h, clip.y + clip.h);
    if (x1 <= x0 or y1 <= y0) return null;
    return .{ .x = x0, .y = y0, .w = x1 - x0, .h = y1 - y0 };
}

/// 桌面区无 Explorer 顶栏；仅作欢迎窗垂直定位留白。
pub const DESKTOP_TOP_PAD: i32 = 8;
pub const TASKBAR_H: i32 = 28;
/// `false` 时显示经典快速启动栏（仿 Win2000）；任务按钮区宽度恒为 0，由 `taskListOuter` 承担。
pub const TASKBAR_MINIMAL: bool = false;
/// 嵌入式图标源图边长（与 `classic/resources/icons.zig` 一致）。
pub const ICON_SRC: u32 = 16;
pub const ICON_STRIDE_Y: i32 = 84;
pub const ICON_X: i32 = 16;
pub const ICON_SLOT_W: i32 = 160;
pub const ICON_SLOT_H: i32 = 72;
/// 屏幕上图标位图边长 = ICON_SRC * ICON_SCALE。
pub const ICON_PIX: i32 = 48;
pub const ICON_SCALE: u32 = 3;

pub fn desktopFirstIconTop(wy: i32) i32 {
    return wy + DESKTOP_TOP_PAD;
}

pub fn desktopIconSlot(sw: i32, wy: i32, index: u32) Rect {
    _ = sw;
    const top = desktopFirstIconTop(wy);
    return .{
        .x = ICON_X,
        .y = top + @as(i32, @intCast(index)) * ICON_STRIDE_Y,
        .w = ICON_SLOT_W,
        .h = ICON_SLOT_H,
    };
}

/// 经典开始菜单：左侧品牌条 + 正文列；子菜单无侧条。
pub const START_MENU_SIDEBAR_W: i32 = 22;
pub const START_MENU_BODY_W: i32 = 178;
pub const START_MENU_ITEM_H: i32 = 22;
pub const START_MENU_SEP_H: i32 = 8;
pub const START_MENU_BODY_TOP_PAD: i32 = 4;
pub const START_MENU_BODY_BOTTOM_PAD: i32 = 4;
pub const CASCADE_MENU_W: i32 = 220;

/// 根菜单总宽（侧条 + 正文），与历史 `START_MENU_W` 接近。
pub fn startMenuRootWidth() i32 {
    return START_MENU_SIDEBAR_W + START_MENU_BODY_W;
}

/// 兼容旧常量：总宽度。
pub const START_MENU_W: i32 = START_MENU_SIDEBAR_W + START_MENU_BODY_W;

pub fn startMenuRootContentHeight() i32 {
    const menu = @import("start_menu_data.zig");
    return menu.blockPixelHeight(@This(), 0, menu.root_count);
}

/// 开始菜单紧贴任务栏上沿；高度随根项行数变化，屏高不足时裁切。
pub fn startMenuFrame(sw: i32, sh: i32) Rect {
    _ = sw;
    const mw = startMenuRootWidth();
    var want_h = startMenuRootContentHeight();
    const top_limit = DESKTOP_TOP_PAD;
    const desktop_bottom = sh - TASKBAR_H;
    const max_h = desktop_bottom - top_limit;
    if (max_h <= 0) {
        return .{ .x = 4, .y = top_limit, .w = mw, .h = 1 };
    }
    if (want_h > max_h) want_h = max_h;
    const my = desktop_bottom - want_h;
    return .{ .x = 4, .y = my, .w = mw, .h = want_h };
}

pub fn startMenuSidebarRect(root: Rect) Rect {
    return .{
        .x = root.x,
        .y = root.y,
        .w = START_MENU_SIDEBAR_W,
        .h = root.h,
    };
}

pub fn startMenuBodyRect(root: Rect) Rect {
    return .{
        .x = root.x + START_MENU_SIDEBAR_W,
        .y = root.y,
        .w = START_MENU_BODY_W,
        .h = root.h,
    };
}

/// 根菜单正文区内第 `row` 行（0..root_count-1）。
pub fn startMenuRootItemRect(root: Rect, row: u32) ?Rect {
    const menu = @import("start_menu_data.zig");
    if (row >= menu.root_count) return null;
    const body = startMenuBodyRect(root);
    var y = body.y + START_MENU_BODY_TOP_PAD;
    var r: u32 = 0;
    while (r < row) : (r += 1) {
        y += menu.rowPixelHeight(@This(), @intCast(r));
    }
    const rh = menu.rowPixelHeight(@This(), @intCast(row));
    return .{ .x = body.x + 2, .y = y, .w = body.w - 4, .h = rh };
}

pub fn submenuItemRect(menu_frame: Rect, first_child: u16, child_count: u8, slot: u8) ?Rect {
    const menu = @import("start_menu_data.zig");
    if (slot >= child_count) return null;
    var y = menu_frame.y + START_MENU_BODY_TOP_PAD;
    var s: u16 = 0;
    while (s < slot) : (s += 1) {
        y += menu.rowPixelHeight(@This(), first_child + s);
    }
    const rh = menu.rowPixelHeight(@This(), first_child + slot);
    return .{ .x = menu_frame.x + 2, .y = y, .w = menu_frame.w - 4, .h = rh };
}

/// 子菜单贴在父项右侧（或左侧翻出）；`parent_item` 为父菜单内该行矩形（屏幕坐标）。
pub fn cascadeMenuFrame(parent_item: Rect, first_child: u16, child_count: u8, sw: i32, sh: i32) Rect {
    const menu = @import("start_menu_data.zig");
    const w = CASCADE_MENU_W;
    const h = menu.blockPixelHeight(@This(), first_child, child_count);
    const overlap: i32 = 1;
    var x = parent_item.x + parent_item.w - overlap;
    var y = parent_item.y;
    const desk_bottom = sh - TASKBAR_H;
    if (y + h > desk_bottom - 2) y = desk_bottom - 2 - h;
    if (y < DESKTOP_TOP_PAD) y = DESKTOP_TOP_PAD;
    if (x + w > sw - 2) {
        x = parent_item.x - w + overlap;
    }
    if (x < 2) x = 2;
    return .{ .x = x, .y = y, .w = w, .h = h };
}

const shell_st = @import("shell_state.zig");

/// 第 `col` 级联菜单（1=Programs 等第一列飞出）；需已展开根项。
pub fn startMenuCascadeFrame(sw: i32, sh: i32, col: u32) ?Rect {
    const menu = @import("start_menu_data.zig");
    const exp = shell_st.start_menu_expanded_root orelse return null;
    const root = startMenuFrame(sw, sh);
    if (col == 0) return null;
    if (col == 1) {
        const p = startMenuRootItemRect(root, exp) orelse return null;
        const L = menu.lineAt(exp);
        if (!L.cascade or L.child_count == 0) return null;
        return cascadeMenuFrame(p, L.first_child, L.child_count, sw, sh);
    }
    const need_path = col - 1;
    if (shell_st.start_menu_path_len < need_path) return null;
    var c: u32 = 1;
    var prev = startMenuCascadeFrame(sw, sh, 1) orelse return null;
    var parent_line: u16 = exp;
    while (c < col) : (c += 1) {
        const slot = shell_st.start_menu_path[c - 1];
        const Lp = menu.lineAt(parent_line);
        const item = submenuItemRect(prev, Lp.first_child, Lp.child_count, slot) orelse return null;
        const child_line = menu.childLineIndex(parent_line, slot) orelse return null;
        const Lc = menu.lineAt(child_line);
        if (!Lc.cascade or Lc.child_count == 0) return null;
        prev = cascadeMenuFrame(item, Lc.first_child, Lc.child_count, sw, sh);
        parent_line = child_line;
    }
    return prev;
}

/// 命中级联菜单 `col`（1 起）内的子项槽位。
pub fn hitTestCascadeSlot(sw: i32, sh: i32, col: u32, px: i32, py: i32) ?u8 {
    const menu = @import("start_menu_data.zig");
    const cf = startMenuCascadeFrame(sw, sh, col) orelse return null;
    if (!cf.contains(px, py)) return null;
    const exp = shell_st.start_menu_expanded_root orelse return null;
    if (col == 1) {
        const L = menu.lineAt(exp);
        var s: u8 = 0;
        while (s < L.child_count) : (s += 1) {
            const ir = submenuItemRect(cf, L.first_child, L.child_count, s) orelse continue;
            if (ir.contains(px, py)) return s;
        }
        return null;
    }
    var parent_line: u16 = exp;
    var fc: u32 = 1;
    while (fc < col) : (fc += 1) {
        const sl = shell_st.start_menu_path[fc - 1];
        parent_line = menu.childLineIndex(parent_line, sl) orelse return null;
    }
    const Lp = menu.lineAt(parent_line);
    var s2: u8 = 0;
    while (s2 < Lp.child_count) : (s2 += 1) {
        const ir2 = submenuItemRect(cf, Lp.first_child, Lp.child_count, s2) orelse continue;
        if (ir2.contains(px, py)) return s2;
    }
    return null;
}

/// 开始菜单及可见级联的包围盒（用于局部重绘）。
pub fn startMenuUnionRect(sw: i32, sh: i32, menu_open: bool) ?Rect {
    if (!menu_open) return null;
    var u = startMenuFrame(sw, sh);
    var col: u32 = 1;
    while (true) : (col += 1) {
        if (startMenuCascadeFrame(sw, sh, col)) |cf| {
            u = unionRects(u, cf);
        } else break;
    }
    return u;
}

/// 点是否落在开始菜单或任一可见级联内（不含开始按钮）。
pub fn startMenuOrCascadeContains(px: i32, py: i32, sw: i32, sh: i32, menu_open: bool) bool {
    const ur = startMenuUnionRect(sw, sh, menu_open) orelse return false;
    return ur.contains(px, py);
}

/// 开始按钮（任务栏上凸起区域）；宽度需容纳「图示 + 间距 + 标签」并留内边距。
pub fn startButtonRect(sh: i32) Rect {
    const btn_w: i32 = 82;
    const btn_h: i32 = 22;
    const by = sh - TASKBAR_H + @divTrunc(TASKBAR_H - btn_h, 2);
    return .{ .x = 4, .y = by, .w = btn_w, .h = btn_h };
}

/// 开始按钮内四色窗格徽标占位边长（与任务栏绘制一致）。
pub const START_BTN_GLYPH: i32 = 8;
pub const START_BTN_GAP: i32 = 4;
/// 8×16 像素字体宽度。
pub fn textWidthChars(len: usize) i32 {
    return @as(i32, @intCast(len)) * 8;
}

pub fn quickLaunchOuter(sw: i32, sh: i32) Rect {
    const start = startButtonRect(sh);
    if (TASKBAR_MINIMAL) {
        return .{ .x = start.x + start.w + 6, .y = start.y, .w = 0, .h = start.h };
    }
    const ql_x = start.x + start.w + 6;
    const ql_w: i32 = 104;
    const by = start.y;
    const bh = start.h;
    _ = sw;
    return .{ .x = ql_x, .y = by, .w = ql_w, .h = bh };
}

pub fn taskButtonRect(sw: i32, sh: i32) Rect {
    const ql = quickLaunchOuter(sw, sh);
    return .{ .x = ql.x + ql.w, .y = ql.y, .w = 0, .h = ql.h };
}

pub fn trayOuter(sw: i32, sh: i32) Rect {
    const tray_w: i32 = 148;
    const btn_h: i32 = 22;
    const by = sh - TASKBAR_H + @divTrunc(TASKBAR_H - btn_h, 2);
    return .{ .x = sw - tray_w - 6, .y = by, .w = tray_w, .h = btn_h };
}

/// 开始按钮与托盘之间的任务条区域（欢迎窗 + 已启动项）；紧接快速启动栏右侧。
pub fn taskListOuter(sw: i32, sh: i32) Rect {
    const s = startButtonRect(sh);
    const ql = quickLaunchOuter(sw, sh);
    const tr = trayOuter(sw, sh);
    const gap: i32 = 6;
    const x = if (ql.w > 0) ql.x + ql.w + gap else s.x + s.w + gap;
    const w = tr.x - x - gap;
    return .{ .x = x, .y = s.y, .w = @max(0, w), .h = s.h };
}

/// `total` = `shell_state.taskStripButtonCount()`；`index` 从 0 起，0 常为欢迎窗按钮。
pub fn taskStripButtonRect(sw: i32, sh: i32, index: u32, total: u32) ?Rect {
    const tl = taskListOuter(sw, sh);
    if (total == 0 or tl.w <= 0 or index >= total) return null;
    const nt: i32 = @intCast(total);
    var btn_w = @divTrunc(tl.w + nt - 1, nt);
    const min_w: i32 = 72;
    if (btn_w < min_w) btn_w = min_w;
    const max_w: i32 = 200;
    if (btn_w > max_w) btn_w = max_w;
    const x0 = tl.x + @as(i32, @intCast(index)) * btn_w;
    if (x0 >= tl.x + tl.w) return null;
    const rw = @min(btn_w, tl.x + tl.w - x0);
    return .{ .x = x0, .y = tl.y, .w = rw, .h = tl.h };
}

pub const WELCOME_W: i32 = 520;
pub const WELCOME_H: i32 = 380;

pub fn welcomeOuter(sw: i32, sh: i32) Rect {
    const ww = WELCOME_W;
    const wh = WELCOME_H;
    const wx = @divTrunc(sw - ww, 2);
    const wy = @max(DESKTOP_TOP_PAD, @divTrunc((sh - TASKBAR_H) - wh, 2));
    return .{ .x = wx, .y = wy, .w = ww, .h = wh };
}

/// 将欢迎窗左上角限制在桌面工作区内（任务栏上方、左右留边）。
pub fn clampWelcomeWindowTopLeft(sw: i32, sh: i32, x: i32, y: i32) struct { x: i32, y: i32 } {
    const ww = WELCOME_W;
    const wh = WELCOME_H;
    const work_bottom = sh - TASKBAR_H;
    var cx = x;
    var cy = y;
    if (cx < 2) cx = 2;
    if (cy < DESKTOP_TOP_PAD) cy = DESKTOP_TOP_PAD;
    if (cx + ww > sw - 2) cx = sw - ww - 2;
    if (cy + wh > work_bottom - 2) cy = work_bottom - wh - 2;
    return .{ .x = cx, .y = cy };
}

pub fn welcomeOuterMaximized(sw: i32, sh: i32) Rect {
    const pad_x: i32 = 2;
    const pad_bottom: i32 = 2;
    const work_bottom = sh - TASKBAR_H;
    return .{
        .x = pad_x,
        .y = DESKTOP_TOP_PAD,
        .w = sw - 2 * pad_x,
        .h = work_bottom - DESKTOP_TOP_PAD - pad_bottom,
    };
}

pub fn welcomeOuterFor(sw: i32, sh: i32, maximized: bool) Rect {
    if (maximized) return welcomeOuterMaximized(sw, sh);
    const shell_state = @import("shell_state.zig");
    if (shell_state.welcome_pos_custom) {
        const c = clampWelcomeWindowTopLeft(sw, sh, shell_state.welcome_win_x, shell_state.welcome_win_y);
        if (c.x != shell_state.welcome_win_x or c.y != shell_state.welcome_win_y) {
            shell_state.welcome_win_x = c.x;
            shell_state.welcome_win_y = c.y;
        }
        return .{ .x = c.x, .y = c.y, .w = WELCOME_W, .h = WELCOME_H };
    }
    return welcomeOuter(sw, sh);
}

pub const WELCOME_TITLE_H: i32 = 26;
pub const CAPTION_BTN_W: i32 = 18;
pub const CAPTION_BTN_H: i32 = 18;
pub const CAPTION_BTN_GAP: i32 = 2;

/// `index`: 0=最小化, 1=最大化, 2=关闭（从左到右，常见桌面标题栏顺序）。
pub fn welcomeCaptionButton(inner_x: i32, inner_y: i32, inner_w: i32, title_h: i32, index: u32) Rect {
    const btn_w = CAPTION_BTN_W;
    const btn_h = CAPTION_BTN_H;
    const gap = CAPTION_BTN_GAP;
    const by = inner_y + @divTrunc(title_h - btn_h, 2);
    const group_right = inner_x + inner_w - 4;
    const close_x = group_right - btn_w;
    const max_x = close_x - gap - btn_w;
    const min_x = max_x - gap - btn_w;
    return switch (index) {
        0 => .{ .x = min_x, .y = by, .w = btn_w, .h = btn_h },
        1 => .{ .x = max_x, .y = by, .w = btn_w, .h = btn_h },
        else => .{ .x = close_x, .y = by, .w = btn_w, .h = btn_h },
    };
}

pub fn welcomeExitButton(outer: Rect) Rect {
    const bw: i32 = 72;
    const bh: i32 = 22;
    return .{
        .x = outer.x + outer.w - bw - 16,
        .y = outer.y + outer.h - bh - 16,
        .w = bw,
        .h = bh,
    };
}

pub const CONTEXT_MENU_W: i32 = 184;
pub const CONTEXT_MENU_ITEM_H: i32 = 22;
pub const CONTEXT_MENU_TOP_PAD: i32 = 4;

pub fn contextMenuFrame(cx: i32, cy: i32, sw: i32, sh: i32) Rect {
    const lines: i32 = 3;
    const mh = CONTEXT_MENU_TOP_PAD + lines * CONTEXT_MENU_ITEM_H + 8;
    const mw = CONTEXT_MENU_W;
    var x = cx;
    var y = cy;
    if (x + mw > sw - 2) x = sw - mw - 2;
    if (y + mh > sh - TASKBAR_H - 2) y = sh - TASKBAR_H - mh - 2;
    if (x < 2) x = 2;
    if (y < DESKTOP_TOP_PAD) y = DESKTOP_TOP_PAD;
    return .{ .x = x, .y = y, .w = mw, .h = mh };
}

pub fn contextMenuItemRect(frame: Rect, index: u32) Rect {
    return .{
        .x = frame.x + 2,
        .y = frame.y + CONTEXT_MENU_TOP_PAD + @as(i32, @intCast(index)) * CONTEXT_MENU_ITEM_H,
        .w = frame.w - 4,
        .h = CONTEXT_MENU_ITEM_H,
    };
}
