import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var state: AppState

    private var status: (String, String, Color) {
        if !state.isEnabled {
            return ("已暂停", "pause.circle.fill", .secondary)
        }
        if !state.allPermissionsGranted {
            return ("等待授权", "exclamationmark.shield.fill", .orange)
        }
        if state.engineIsRunning {
            return ("Windows 模式运行中", "checkmark.circle.fill", .green)
        }
        return ("未运行", "xmark.circle.fill", .red)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: status.1)
                        .font(.system(size: 30))
                        .foregroundStyle(status.2)
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(status.0)
                            .font(.headline)
                        Text("普通应用：Windows 模式")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("启用", isOn: $state.isEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .padding(.vertical, 5)
            }

            Section("系统权限") {
                PermissionRow(
                    title: "辅助功能",
                    symbol: "accessibility",
                    isGranted: state.accessibilityGranted,
                    requestAction: state.requestAccessibilityPermission,
                    settingsAction: state.openAccessibilitySettings
                )
                PermissionRow(
                    title: "输入监控",
                    symbol: "keyboard.badge.eye",
                    isGranted: state.inputMonitoringGranted,
                    requestAction: state.requestInputMonitoringPermission,
                    settingsAction: state.openInputMonitoringSettings
                )

                if !state.allPermissionsGranted {
                    HStack {
                        Button {
                            state.refreshPermissionStatus()
                        } label: {
                            Label("重新检测", systemImage: "arrow.clockwise")
                        }
                        Button {
                            state.relaunch()
                        } label: {
                            Label("重启 WinKeys", systemImage: "power")
                        }
                        Spacer()
                    }
                }
            }

            Section("键盘设置") {
                HStack {
                    Label("修饰键使用系统默认映射", systemImage: "command")
                    Spacer()
                    Button("打开键盘设置", action: state.openKeyboardSettings)
                }
            }

            Section("启动") {
                Toggle(
                    "登录时自动启动",
                    isOn: Binding(
                        get: { state.launchAtLogin },
                        set: { state.setLaunchAtLogin($0) }
                    )
                )
            }

            if let error = state.engineError {
                Section("状态") {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("WinKeys")
    }
}

private struct PermissionRow: View {
    let title: String
    let symbol: String
    let isGranted: Bool
    let requestAction: () -> Void
    let settingsAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 20)
            Text(title)
            Spacer()
            Label(isGranted ? "已允许" : "未允许", systemImage: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isGranted ? .green : .secondary)
            if !isGranted {
                Button("授权", action: requestAction)
                    .buttonStyle(.borderedProminent)
                Button(action: settingsAction) {
                    Image(systemName: "gearshape")
                }
                .help("在系统设置中打开")
            }
        }
    }
}
