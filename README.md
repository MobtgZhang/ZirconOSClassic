# ZirconOSClassic - Windows 2000 经典桌面主题

## 概述

ZirconOSClassic 是 ZirconOS 操作系统的 **Windows Classic（经典）** 风格桌面环境实现。
Classic 主题继承自 Windows 95/98/2000 的经典界面设计，以灰色为主色调，
使用 3D 凸起/凹陷边框模拟物理按钮效果，是 Windows 图形界面历史最悠久的视觉风格。

本模块参考 [ReactOS](https://github.com/reactos/reactos) 的桌面架构设计，
目标是实现一套极简、高效、低资源占用的经典风格桌面 Shell。

## 设计风格

### Classic 核心视觉特征

| 特征 | 说明 |
|------|------|
| **3D 边框** | 按钮和窗口使用高光/阴影模拟凸起和凹陷效果 |
| **灰色基调** | 系统背景 `#C0C0C0`（银灰色），窗口背景 `#FFFFFF` |
| **直角窗口** | 所有窗口、按钮、菜单均为直角矩形 |
| **像素级精准** | 1px 边框线，清晰的控件边界 |
| **渐变标题栏** | 活动窗口：深蓝 `#000080` → 浅蓝 `#1084D0` |
| **MS Sans Serif** | 系统默认字体 MS Sans Serif 8pt |

### 经典配色方案

| 元素 | 颜色值 | 说明 |
|------|--------|------|
| 桌面背景 | `#008080`（Windows 95）/ `#3A6EA5`（Win2000） | 经典绿松石 / 蓝色 |
| 窗口背景 | `#FFFFFF` | 白色 |
| 按钮/对话框 | `#C0C0C0` | 银灰色 |
| 3D 高光 | `#FFFFFF` | 白色（凸起左上角） |
| 3D 阴影 | `#808080` / `#404040` | 灰色（凹陷右下角） |
| 活动标题栏 | `#000080` → `#1084D0` | 深蓝色渐变 |
| 非活动标题栏 | `#808080` → `#C0C0C0` | 灰色渐变 |
| 选中/高亮 | `#000080`（背景）+ `#FFFFFF`（文字） | 蓝底白字 |
| 菜单栏 | `#C0C0C0` | 灰色，黑色文字 |

### 与其他主题的关键差异

- **无透明度**：完全不透明，0 模糊/混合开销
- **无圆角**：所有元素均为直角矩形
- **无动画**：窗口操作即时响应，无过渡动画
- **最低资源占用**：无 GPU 需求，纯 CPU 2D 渲染
- **单栏开始菜单**：垂直菜单列表（非 XP 双栏）

## 模块架构

```
ZirconOSClassic/
├── src/
│   ├── root.zig              # 库入口，导出所有公共模块
│   ├── main.zig              # 可执行入口 / 集成测试
│   ├── theme.zig             # Classic 主题定义（3D 边框颜色、尺寸）
│   ├── winlogon.zig          # 用户登录管理（Ctrl+Alt+Del 登录对话框）
│   ├── desktop.zig           # 桌面管理器（壁纸、图标、右键菜单）
│   ├── taskbar.zig           # 任务栏（开始按钮、任务按钮、托盘、时钟）
│   ├── startmenu.zig         # 开始菜单（单栏级联菜单）
│   ├── window_decorator.zig  # 窗口装饰器（经典标题栏、3D 边框）
│   ├── shell.zig             # 桌面 Shell 主程序（explorer.exe 风格）
│   └── controls.zig          # Classic 风格控件（3D 按钮、文本框）
├── resources/
│   ├── wallpapers/           # 桌面壁纸（纯色 / 简单图案）
│   ├── icons/                # 系统图标（16 色经典风格）
│   ├── ui/                   # UI 组件素材
│   ├── cursors/              # 鼠标光标（经典箭头）
│   └── MANIFEST.md           # 资源清单
├── build.zig
├── build.zig.zon
└── README.md
```

## 计划实现的组件

### WinLogon（用户登录）
- **Ctrl+Alt+Del 登录**：经典安全登录对话框
- **用户名/密码框**：标准 3D 文本输入控件
- **域选择**：下拉选择框（本机/域）
- **关机按钮**：对话框底部

### Desktop（桌面管理器）
- 纯色壁纸（默认绿松石 `#008080` 或蓝色 `#3A6EA5`）
- 16 色经典图标（我的电脑、网上邻居、回收站）
- 右键菜单（排列图标、刷新、属性）

### Taskbar（任务栏）
- 灰色实心任务栏（带 3D 凸起边框）
- **开始按钮**：凸起灰色按钮 + Windows 标志 + "Start" 文字
- 任务按钮（带 3D 按下效果）
- 系统托盘（时钟、音量）
- Quick Launch 区域

### Start Menu（开始菜单）
- **单栏级联菜单**：程序 → 子菜单展开
- 标准菜单项：程序、文档、设置、查找、帮助、运行
- 关机选项（关机/重启/注销）
- 左侧蓝色/灰色垂直条纹 + "Windows 2000" 文字

### Window Decorator（窗口装饰器）
- 渐变标题栏（深蓝 → 浅蓝）
- 标题栏按钮（最小化/最大化/关闭，凹凸效果）
- 3D 窗口边框（可拖拽调整大小）
- 系统菜单（窗口图标点击）

### Controls（UI 控件）
- 3D 凸起按钮（正常/悬停/按下/禁用四态）
- 3D 凹陷文本框
- 经典复选框和单选按钮
- 经典滚动条（带三角箭头）
- 标准进度条（蓝色方块填充）

## 与主系统集成

ZirconOSClassic 通过以下内核子系统接口工作：

1. **user32.zig** — 窗口管理 API
2. **gdi32.zig** — 绘图 API（2D 基础图元即可）
3. **subsystem.zig** (csrss) — 窗口站和桌面管理
4. **framebuffer.zig** — 帧缓冲区显示驱动

### 配置

在 `config/desktop.conf` 中选择 Classic 主题：

```ini
[desktop]
theme = classic
color_scheme = windows2000   # windows95 | windows2000 | highcontrast
shell = explorer
```

## 构建

```bash
cd 3rdparty/ZirconOSClassic
zig build
zig build test
```

## 开发状态

当前为项目框架阶段，计划按以下顺序实现：

1. `theme.zig` — Classic 3D 边框配色和尺寸常量
2. `controls.zig` — 3D 凸起/凹陷控件（核心基础）
3. `window_decorator.zig` — 经典标题栏和窗口边框
4. `taskbar.zig` — 灰色实心任务栏
5. `startmenu.zig` — 单栏级联开始菜单
6. `desktop.zig` — 桌面管理器
7. `winlogon.zig` — Ctrl+Alt+Del 登录界面
8. `shell.zig` — Shell 集成

## 参考

- [ReactOS](https://github.com/reactos/reactos) — 开源 Windows 兼容操作系统
- Windows 2000 / Windows Classic 视觉规范
- [Win32 API 控件绘制](https://learn.microsoft.com/en-us/windows/win32/controls/buttons) — 经典控件文档
- Microsoft UX Guidelines for Windows 2000
