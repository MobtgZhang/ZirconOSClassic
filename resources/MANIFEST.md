# ZirconOS Classic 资源清单

本资源包为 ZirconOS Classic (Windows 2000) 主题的原创设计。
所有图形资源由代码生成或使用原创素材。**不包含任何第三方版权资源**。

## 图形资源

| 资源类型 | 数量 | 说明 |
|---------|------|------|
| 图标 | 8 SVG | 32x32 系统图标，16色系统调色板风格 |
| 光标 | 7 SVG | 标准箭头光标集，黑白经典风格 |
| 壁纸 | 无 | 经典主题使用纯色桌面背景 (默认 #008080 蓝绿色) |

## 图标

| ID | 文件 | 名称 | 说明 |
|----|------|------|------|
| 1 | `icons/computer.svg` | Computer | 经典台式电脑图标，16色显示器 |
| 2 | `icons/documents.svg` | Documents | 经典文件夹图标，淡黄文件夹 |
| 3 | `icons/network.svg` | Network | 双台电脑连接图标 |
| 4 | `icons/recycle_bin.svg` | Recycle Bin | 经典回收站图标 |
| 5 | `icons/browser.svg` | Browser | 地球仪浏览器图标 |
| 6 | `icons/settings.svg` | Settings | 齿轮/控制面板图标 |
| 7 | `icons/terminal.svg` | Terminal | 命令提示符窗口图标 |
| 8 | `icons/folder.svg` | Folder | 标准文件夹图标 |

## 光标

| ID | 文件 | 类型 | 说明 |
|----|------|------|------|
| 1 | `cursors/classic_arrow.svg` | 默认指针 | 标准白底黑边箭头 |
| 2 | `cursors/classic_hand.svg` | 链接手型 | 手指指向光标 |
| 3 | `cursors/classic_ibeam.svg` | 文本 | I-beam 文本选择光标 |
| 4 | `cursors/classic_wait.svg` | 等待 | 沙漏等待光标 |
| 5 | `cursors/classic_size_ns.svg` | 垂直调整 | 双向上下箭头 |
| 6 | `cursors/classic_size_ew.svg` | 水平调整 | 双向左右箭头 |
| 7 | `cursors/classic_move.svg` | 移动 | 四向箭头十字 |

## 主题配色方案

| 方案 | 桌面背景 | 标题栏 | 说明 |
|------|---------|--------|------|
| Windows Standard | #008080 (蓝绿) | #000080 (藏蓝) | 默认经典配色 |
| Storm | #000000 (黑色) | #000064 (深蓝) | 深色高彩配色 |
| Spruce | #006040 (深绿) | #004020 (墨绿) | 绿色森林风格 |
| Lilac | #604080 (紫罗兰) | #503070 (深紫) | 紫丁香风格 |
| Desert | #C09850 (沙黄) | #806020 (棕色) | 沙漠暖色风格 |
| High Contrast Black | #000000 | #000080 | 高对比度黑色 |
| High Contrast White | #FFFFFF | #0000FF | 高对比度白色 |

## 使用方式

资源通过 `@embedFile` 嵌入或由渲染代码在运行时按 16 色系统调色板生成。
主题通过 `theme_loader.zig` 模块加载并映射到内部配色方案。
Classic 主题不使用 DWM 合成器——所有渲染均为直接 GDI 绘图调用。

## 注意

发行版仅使用代码生成的原创资源。
