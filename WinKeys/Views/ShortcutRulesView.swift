import SwiftUI

struct ShortcutRulesView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Section {
                Toggle("常用编辑快捷键", isOn: $state.editingShortcuts)
                KeyMappingRow(windows: "Ctrl + C / V / X", mac: "⌘ C / V / X")
                KeyMappingRow(windows: "Ctrl + Z / Y", mac: "⌘ Z / ⇧⌘ Z")
                KeyMappingRow(windows: "Ctrl + A / S / F", mac: "⌘ A / S / F")
            }

            Section {
                Toggle("Windows 文本导航", isOn: $state.textNavigation)
                KeyMappingRow(windows: "Home / End", mac: "行首 / 行尾")
                KeyMappingRow(windows: "Ctrl + ← / →", mac: "按单词移动")
                KeyMappingRow(windows: "Ctrl + Backspace", mac: "删除上一个单词")
            }

            Section {
                Toggle("应用切换与导航", isOn: $state.appSwitching)
                KeyMappingRow(windows: "Alt + Tab", mac: "⌘ Tab")
                KeyMappingRow(windows: "Alt + F4", mac: "⌘ Q")
                KeyMappingRow(windows: "Alt + ← / →", mac: "后退 / 前进")
            }

            Section {
                Toggle("Finder 快捷键", isOn: $state.finderShortcuts)
                KeyMappingRow(windows: "F2", mac: "重命名")
                KeyMappingRow(windows: "Delete", mac: "移到废纸篓")
                KeyMappingRow(windows: "Alt + Enter", mac: "显示简介")
            }

            Section {
                Toggle("Windows 窗口布局", isOn: $state.windowManagement)
                KeyMappingRow(windows: "Win + ← / →", mac: "贴靠半屏")
                KeyMappingRow(windows: "Win + ↑", mac: "最大化 / 恢复刚最小化窗口")
                KeyMappingRow(windows: "Win + ↓", mac: "还原 / 最小化")
            }

            Section {
                Toggle("系统启动快捷键", isOn: $state.systemLaunchers)
                KeyMappingRow(windows: "Win", mac: "打开启动台")
                KeyMappingRow(windows: "Win + E", mac: "打开 Finder")
                KeyMappingRow(windows: "Win + D", mac: "显示桌面")
                KeyMappingRow(windows: "Win + L", mac: "锁定 Mac")
                KeyMappingRow(windows: "Win + Tab", mac: "调度中心")
                KeyMappingRow(windows: "Win + Shift + S", mac: "区域截图")
                KeyMappingRow(windows: "Win + I", mac: "系统设置")
                KeyMappingRow(windows: "Win + .", mac: "表情与符号")
                KeyMappingRow(windows: "Alt + Space", mac: "Spotlight")
                KeyMappingRow(windows: "Ctrl + Space", mac: "切换输入法")
                KeyMappingRow(windows: "Ctrl + Shift + Esc", mac: "活动监视器")
                KeyMappingRow(windows: "Ctrl + Alt + Delete", mac: "强制退出")
                KeyMappingRow(windows: "F5", mac: "刷新")
            }

            Section {
                Toggle("剪贴板历史", isOn: $state.clipboardHistoryEnabled)
                KeyMappingRow(windows: "Win + V", mac: "剪贴板历史")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("快捷键")
    }
}

private struct KeyMappingRow: View {
    let windows: String
    let mac: String

    var body: some View {
        HStack {
            Text(windows)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Image(systemName: "arrow.right")
                .foregroundStyle(.tertiary)
            Text(mac)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 150, alignment: .leading)
        }
        .foregroundStyle(.secondary)
    }
}
