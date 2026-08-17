# WinKeys 项目目标

## 产品目标

创建一款原生 macOS 菜单栏应用，让从 Windows 转到 Mac 的用户可以继续使用熟悉的快捷键，同时避免简单交换 Control 与 Command 导致的终端、远程桌面和虚拟机冲突。

项目目录：`/Users/oxygen/WinKeys`

## 第一版范围

- 将常用 Windows 编辑快捷键翻译为 macOS 快捷键，例如 `Ctrl+C/V/X/Z/A/S/F`。
- 提供 Windows 风格文本导航，包括 Home、End、Ctrl+方向键和 Ctrl+退格。
- 支持 `Alt+Tab`、`Alt+F4`、`Win+E`、`Win+D` 和 `Ctrl+Shift+Esc`。
- `Alt+F4` 直接请求退出当前前台应用，而不是仅关闭当前窗口。
- `Alt+Tab` 选中应用并松开 Alt 后，应像点击切换器中的应用图标一样激活其全部窗口；最小化或已关闭的主窗口也应能重新显示。
- 判断应用是否已有可显示窗口时，应忽略微信等应用在关闭主窗口后残留的无标题后台辅助窗口。
- 支持 `Alt+Space` 打开 Spotlight，`Ctrl+Space` 保持 macOS 输入法切换。
- 支持 `Win+方向键` 贴靠、最大化、还原和最小化当前窗口。
- `Win+↓` 最小化窗口后，如果没有切换到其他窗口，`Win+↑` 应恢复刚才的窗口，与 Windows 行为一致。
- 支持 `Win+L`、`Win+Shift+S`、`Win+Tab`、`Win+I` 和 `Win+.`。
- 单独按下并松开 `Win` 打开启动台；期间按下其他键或点击鼠标则取消，不能影响任何 `Win+组合键` 或 `Win+点击`。
- `Win+Tab` 直接启动系统 Mission Control，不依赖用户是否启用 macOS 默认的 `Control+↑` 快捷键。
- 支持 `F5` 刷新、`Alt+方向键` 前进后退、`Alt+Enter` 文件属性和 `Ctrl+Alt+Delete` 强制退出。
- `Alt+←/→` 使用独立的 `Command+[/]` 合成事件，避免方向键附带的数字键盘标记导致应用拒绝响应。
- 支持 `Win+V` 文本剪贴板历史、搜索、删除、清空和点击自动粘贴。
- 提供 Finder 快捷键，包括 F2 重命名和 Delete 移到废纸篓。
- 普通应用默认使用 Windows 模式。
- Terminal 等命令行应用保留 Control 组合键；`Ctrl+C` 中断命令、`Ctrl+Shift+C` 复制文字，`Ctrl+V` 保留给 Codex CLI 粘贴图片、`Ctrl+Shift+V` 粘贴文字。
- 远程桌面和虚拟机应用完全透传。
- 用户可以添加应用并选择“Windows 模式”“保留 Control”或“完全透传”。
- 菜单栏可以快速启用、暂停、打开设置和退出。
- 应用默认轻量启动，只显示菜单栏图标，不自动创建或展示设置窗口；用户点击菜单栏“设置…”时才打开 GUI。
- 提供辅助功能、输入监控权限状态及授权入口。
- 支持登录时自动启动。

## 技术约束

- 使用 Swift、SwiftUI 和原生 macOS API。
- 快捷键转换基于 `CGEventTap`，不全局交换修饰键。
- 未取得必要权限时不得拦截按键。
- WinKeys 运行时，macOS 系统“修饰键”应保持默认映射，组合键转换由 WinKeys 独立完成。
- 不启用 App Sandbox；第一版面向 Xcode 本地运行和独立分发。
- 快捷键判断逻辑与系统事件监听分离，并覆盖单元测试。
- 剪贴板历史只保存在本机，最多 50 条；忽略密码管理器标记为隐藏或临时的内容。

## 已知限制

- macOS Secure Input 生效时，系统可能禁止第三方应用监听按键。
- `Win+D` 使用辅助功能 API 最小化全部可见窗口，不依赖系统的 F11 快捷键设置。
- `Ctrl+Alt+Delete` 没有完全对应的 macOS 行为。
- 独立分发前仍需 Developer ID 签名、公证和正式应用图标。

## 完成标准

- `WinKeys.xcodeproj` 可以被 Xcode 正常打开。
- Debug 配置可以成功编译。
- 快捷键翻译单元测试通过。
- 应用启动后只显示菜单栏图标，快捷键引擎正常工作；设置窗口仅在用户主动打开时显示。
- 用户授权后可以启用快捷键翻译引擎。

## 当前状态（2026-08-17）

- [x] Xcode 工程、WinKeys 主目标和 WinKeysTests 测试目标
- [x] SwiftUI 设置窗口与菜单栏控制
- [x] 快捷键事件翻译引擎
- [x] 权限状态、授权入口和登录项
- [x] Terminal 默认规则与自定义应用规则
- [x] 本地签名 Debug 应用：`build/WinKeys.app`
- [x] 本机 Release 正式安装流程：`scripts/install-release.sh` 构建并安装到 `/Applications/WinKeys.app`
- [x] Debug 构建通过
- [x] 30 项快捷键规则单元测试通过
- [x] 返回应用时、定时和手动三种权限重新检测方式
- [x] 本地成品使用稳定 designated requirement，避免重建后权限身份变化
- [x] Windows 风格窗口布局与恢复
- [x] Win+V 本地文本剪贴板历史
- [x] Alt+Tab 选中应用后按切换器图标点击语义激活、恢复或重新打开窗口
- [x] `v0.1.2` 通过 GitHub Actions 发布 Apple Silicon 与 Intel DMG
- [x] `v0.1.3` 通过 GitHub Actions 发布 Apple Silicon 与 Intel DMG

下一阶段优先验证不同实体键盘上的 Alt/Win 修饰键事件，并根据实际使用反馈调整映射；独立发布前补充应用图标、Developer ID 签名和公证。
