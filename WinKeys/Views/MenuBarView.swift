import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Toggle("Windows 模式", isOn: $state.isEnabled)

        if state.isEnabled && !state.allPermissionsGranted {
            Button("完成权限设置") {
                showSettings()
            }
        }

        Divider()

        Button("剪贴板历史") {
            state.showClipboardHistory()
        }
        .disabled(!state.clipboardHistoryEnabled)

        Button("设置…") {
            showSettings()
        }
        .keyboardShortcut(",")

        Divider()

        Button("退出 WinKeys") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func showSettings() {
        state.showSettings()
    }
}
