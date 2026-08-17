# WinKeys

WinKeys 是一个原生 macOS 菜单栏应用，将常用 Windows 快捷键按组合翻译为对应的 macOS 操作。它不会粗暴地全局交换 Control 和 Command，因此可以为 Terminal、远程桌面和虚拟机设置独立行为。

完整产品范围与完成标准见 [PROJECT.md](PROJECT.md)。

## 当前功能

- `Ctrl+C/V/X/Z/Y/A/S/F` 等常用编辑快捷键
- Home、End、Ctrl+方向键和 Ctrl+退格
- `Alt+Tab`、`Alt+F4`
- `Win+E`、`Win+D`、`Ctrl+Shift+Esc`
- `Alt+Space` 打开 Spotlight，`Ctrl+Space` 切换输入法
- Finder 中 F2 重命名、Delete 移到废纸篓
- Terminal 默认保留 Control（`Ctrl+Shift+C/V` 复制粘贴文字，`Ctrl+V` 粘贴图片），远程桌面可完全透传
- 自定义应用规则、菜单栏暂停和登录时启动
- 默认轻量驻留菜单栏，不自动弹出设置窗口
- `Win+方向键` 窗口贴靠、最大化、还原和最小化
- `Win+L` 锁屏、`Win+Shift+S` 区域截图、`Win+Tab` 调度中心
- `Win+I` 系统设置、`Win+.` 表情面板、`Ctrl+Alt+Delete` 强制退出
- `F5` 刷新、`Alt+方向键` 前进后退、Finder `Alt+Enter` 显示简介
- `Win+V` 本地文本剪贴板历史，支持搜索和点击粘贴

## 运行

1. 直接打开 `build/WinKeys.app`，或使用 Xcode 打开 `WinKeys.xcodeproj` 后运行。
2. 在“系统设置 > 键盘 > 键盘快捷键 > 修饰键”中恢复默认映射。
3. 按界面提示允许“辅助功能”和“输入监控”。
4. 授权后若状态没有立即更新，暂停再重新启用 Windows 模式。

本地迭代时使用 `scripts/build-local.sh` 生成稳定签名要求的 `build/WinKeys.app`。首次切换到稳定签名版本需要重新授权一次，之后脚本重建不会改变权限身份。

## 验证命令

```sh
xcodebuild -project WinKeys.xcodeproj \
  -scheme WinKeys \
  -configuration Debug \
  -destination 'platform=macOS' \
  test
```

生成本地成品：

```sh
./scripts/build-local.sh
```

生成 Release 构建并正式安装到 `/Applications`：

```sh
./scripts/install-release.sh
```

安装后的 WinKeys 可被启动台索引。

## 已知限制

- Secure Input 生效时，macOS 可能禁止监听按键。
- `Win+D` 使用辅助功能 API 最小化全部可见窗口，不依赖系统 F11“显示桌面”快捷键。
- Xcode 每次生成不同路径的调试应用时，macOS 可能要求重新授权。
- 正式独立分发需要 Developer ID 签名、公证和应用图标。
- 剪贴板历史目前只记录纯文本，最多 50 条；隐藏、临时和超过 200 KB 的内容会忽略。
