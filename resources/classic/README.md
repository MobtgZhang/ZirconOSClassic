# ZirconOS Classic 视觉资源

本目录为**说明与资产占位**；机器可读的图标/光标数据位于 [`src/classic/resources/`](../src/classic/resources/)（Zig 源码内嵌 ARGB 数组）。

- **版权**：图标与光标为仓库原创简化像素风，用于贴近 Windows 2000 **布局与配色语义**，非复制微软图标文件。
- **格式**：8×8 逻辑像素，`0xFFRRGGBB` 不透明，`0x00000000` 透明；GRE 中按 4× 或 2× 最近邻放大。
- **子目录约定**：`icons_32x32/`、`icons_16x16/` 等可用于日后 PNG 源图；当前构建以 Zig 数组为准。
