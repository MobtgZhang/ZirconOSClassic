# 参与贡献 ZirconOS Classic

## 合规与版权

- **禁止**使用或改编微软泄露或未授权的 Windows 源码；**禁止**将 Windows 零售/预览版二进制、字体、图标、帮助文档等受版权素材纳入本仓库或构建产物。
- 实现应基于**公开规范**（UEFI、ACPI、Multiboot2、PCI、GPT、PE/COFF 等）、**独立设计与自写代码**，或**许可证明确允许**的第三方库（MIT/BSD/Apache 等）。
- 参考其他开源操作系统时，遵守其许可证，并在架构与实现上保持独立，避免逐行翻译受版权保护的代码。
- 本仓库是 **ZirconOS Classic / Zircon64** 子系统，**不**声称与微软产品官方兼容或认证；对外文档与二进制中避免使用 `Win32` 作为产品名（使用 **Zircon64**）。

## 构建与测试

- 主工具链为 **Zig**；日常验证：`zig build -Darch=x86_64 kernel`、`zig build -Darch=x86_64 zbm`。
- 运行与镜像约定见 [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) 与 [`docs/KERNEL_IMAGE.md`](docs/KERNEL_IMAGE.md)。

## 依赖与审计

- 新增依赖须在提交说明中注明许可证；若引入 copyleft 组件，须事先与维护者确认是否与项目策略一致。
