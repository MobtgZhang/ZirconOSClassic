//! 与绘制共享的 Shell 可见状态（避免 ntgdi ↔ shell_click 循环依赖）。

const menu = @import("start_menu_data.zig");

pub var welcome_visible: bool = true;
/// 最小化：不绘制欢迎窗，任务栏按钮仍可恢复。
pub var welcome_minimized: bool = false;
/// 最大化：欢迎窗铺满工作区（任务栏上方）。
pub var welcome_maximized: bool = false;
/// 非最大化时是否使用 `welcome_win_x` / `welcome_win_y`（否则按屏幕居中）。
pub var welcome_pos_custom: bool = false;
pub var welcome_win_x: i32 = 0;
pub var welcome_win_y: i32 = 0;
pub var welcome_dragging: bool = false;
pub var welcome_drag_grab_dx: i32 = 0;
pub var welcome_drag_grab_dy: i32 = 0;

pub fn setWelcomeVisible(v: bool) void {
    welcome_visible = v;
    if (!v) {
        welcome_minimized = false;
        welcome_maximized = false;
        welcome_dragging = false;
        adjustTaskFocusAfterWelcomeClosed();
    }
}

pub fn isWelcomeVisible() bool {
    return welcome_visible;
}

pub fn setWelcomeMinimized(v: bool) void {
    welcome_minimized = v;
}

pub fn isWelcomeMinimized() bool {
    return welcome_minimized;
}

pub fn toggleWelcomeMaximized() void {
    welcome_maximized = !welcome_maximized;
}

pub fn isWelcomeMaximized() bool {
    return welcome_maximized;
}

/// 桌面右键菜单（与 shell_layout / ntgdi / shell_click 共用）。
pub var context_menu_visible: bool = false;
pub var context_menu_x: i32 = 0;
pub var context_menu_y: i32 = 0;

// ── 开始菜单（级联 + 悬停 + 键盘共用高亮）──
pub const sm_slot_none: u8 = 255;

/// 当前展开的第一层飞出所对应的根行（Programs=0 等）；`null` 表示仅根列表无飞出。
pub var start_menu_expanded_root: ?u8 = null;
pub var start_menu_path: [menu.max_cascade_depth]u8 = [_]u8{0} ** menu.max_cascade_depth;
pub var start_menu_path_len: u8 = 0;

pub var start_menu_hover_root: ?u8 = null;
/// 各级飞出列上的悬停槽（列 1 → [0]，列 2 → [1]）；`sm_slot_none` 表示未指向该列。
pub var start_menu_hover_slots: [menu.max_cascade_depth]u8 = [_]u8{sm_slot_none} ** menu.max_cascade_depth;

pub const StartMenuDelayKind = enum(u8) { none, expand_root, path_slot };
pub var start_menu_delay_armed: bool = false;
pub var start_menu_delay_deadline: u64 = 0;
pub var start_menu_delay_kind: StartMenuDelayKind = .none;
pub var start_menu_delay_root: u8 = 0;
/// 要写入的路径深度（1=path[0]，2=path[1]）。
pub var start_menu_delay_flyout: u8 = 0;
pub var start_menu_delay_slot: u8 = 0;

/// 上次已绘制到帧缓冲的开始菜单（含级联）包围盒，用于局部重绘时与当前 `union` 求并，避免级联收起后留下残影。
pub var start_menu_last_paint_union: ?struct { x: i32, y: i32, w: i32, h: i32 } = null;

/// 键盘导航：为真时方向键改 `menu_kb_*`，绘制优先于悬停。
pub var start_menu_kb_mode: bool = false;
pub var start_menu_kb_root_row: u8 = 0;
pub var start_menu_kb_path: [menu.max_cascade_depth]u8 = [_]u8{0} ** menu.max_cascade_depth;
pub var start_menu_kb_path_len: u8 = 0;

pub fn resetStartMenuNav() void {
    start_menu_last_paint_union = null;
    start_menu_expanded_root = null;
    start_menu_path_len = 0;
    @memset(start_menu_path[0..], 0);
    start_menu_hover_root = null;
    @memset(start_menu_hover_slots[0..], sm_slot_none);
    start_menu_delay_armed = false;
    start_menu_delay_deadline = 0;
    start_menu_delay_kind = .none;
    start_menu_kb_mode = false;
    start_menu_kb_root_row = 0;
    start_menu_kb_path_len = 0;
    @memset(start_menu_kb_path[0..], 0);
}

/// 级联展开延时（约 200ms @ 100Hz）。返回是否已应用状态并应触发重绘。
pub fn pumpStartMenuDelays(now: u64) bool {
    if (!start_menu_delay_armed) return false;
    if (now < start_menu_delay_deadline) return false;
    start_menu_delay_armed = false;
    switch (start_menu_delay_kind) {
        .none => return false,
        .expand_root => {
            start_menu_expanded_root = start_menu_delay_root;
            start_menu_path_len = 0;
            @memset(start_menu_path[0..], 0);
        },
        .path_slot => {
            const f = start_menu_delay_flyout;
            const s = start_menu_delay_slot;
            if (f == 0 or f > menu.max_cascade_depth) return true;
            start_menu_path_len = f;
            start_menu_path[f - 1] = s;
            var z: usize = f;
            while (z < menu.max_cascade_depth) : (z += 1) {
                start_menu_path[z] = 0;
            }
        },
    }
    start_menu_delay_kind = .none;
    return true;
}

pub fn armStartMenuDelayExpandRoot(root_row: u8, deadline: u64) void {
    start_menu_delay_armed = true;
    start_menu_delay_deadline = deadline;
    start_menu_delay_kind = .expand_root;
    start_menu_delay_root = root_row;
}

pub fn armStartMenuDelayPathSlot(flyout: u8, slot: u8, deadline: u64) void {
    start_menu_delay_armed = true;
    start_menu_delay_deadline = deadline;
    start_menu_delay_kind = .path_slot;
    start_menu_delay_flyout = flyout;
    start_menu_delay_slot = slot;
}

/// 根菜单高亮行（绘制用）。
pub fn startMenuDrawRootRow() ?u8 {
    if (start_menu_kb_mode) return start_menu_kb_root_row;
    if (start_menu_hover_root) |h| return h;
    return start_menu_expanded_root;
}

/// 飞出列 `flyout_1based`（1 起）当前高亮槽。
pub fn startMenuDrawFlyoutSlot(flyout_1based: u32) ?u8 {
    const i = flyout_1based - 1;
    if (i >= menu.max_cascade_depth) return null;
    if (start_menu_kb_mode) {
        if (start_menu_kb_path_len > i) return start_menu_kb_path[i];
        return null;
    }
    if (start_menu_hover_slots[i] != sm_slot_none) return start_menu_hover_slots[i];
    if (start_menu_path_len > i) return start_menu_path[i];
    return null;
}

// ── 任务栏：已启动项（开始菜单启动的占位程序）──
pub const shell_task_title_max: usize = 22;
pub const shell_max_tasks: usize = 6;

pub const ShellTaskFocus = enum(u8) { none, welcome, app };

/// 哪个任务条按钮呈「按下」（活动）状。
pub var shell_task_focus: ShellTaskFocus = .welcome;
pub var shell_focused_task_slot: u8 = 0;

pub var shell_task_count: u8 = 0;
pub var shell_task_titles: [shell_max_tasks][shell_task_title_max + 1]u8 = undefined;

pub fn taskStripButtonCount() u32 {
    var n: u32 = @intCast(shell_task_count);
    if (isWelcomeVisible()) n += 1;
    return n;
}

pub fn appendShellTask(title: []const u8) void {
    if (shell_task_count >= shell_max_tasks) return;
    const n = @min(title.len, shell_task_title_max);
    @memcpy(shell_task_titles[shell_task_count][0..n], title[0..n]);
    shell_task_titles[shell_task_count][n] = 0;
    var z: usize = n + 1;
    while (z <= shell_task_title_max) : (z += 1) {
        shell_task_titles[shell_task_count][z] = 0;
    }
    shell_focused_task_slot = shell_task_count;
    shell_task_count += 1;
    shell_task_focus = .app;
}

pub fn shellTaskTitleSlice(slot: usize) []const u8 {
    if (slot >= shell_task_count) return "";
    var len: usize = 0;
    while (len < shell_task_title_max and shell_task_titles[slot][len] != 0) : (len += 1) {}
    return shell_task_titles[slot][0..len];
}

fn adjustTaskFocusAfterWelcomeClosed() void {
    if (shell_task_focus == .welcome) {
        shell_task_focus = if (shell_task_count > 0) .app else .none;
        if (shell_task_count > 0) shell_focused_task_slot = shell_task_count - 1;
    }
}
