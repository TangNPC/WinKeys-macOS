import SwiftUI

struct ApplicationRulesView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(state.appRules) { rule in
                    ApplicationRuleRow(rule: rule)
                        .environmentObject(state)
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button {
                    state.chooseApplication()
                } label: {
                    Label("添加应用", systemImage: "plus")
                }
                Spacer()
                Text("未列出的应用使用 Windows 模式")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .navigationTitle("应用规则")
    }
}

private struct ApplicationRuleRow: View {
    @EnvironmentObject private var state: AppState
    let rule: AppRule

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: state.icon(for: rule))
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.displayName)
                Text(rule.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Picker(
                "模式",
                selection: Binding(
                    get: { rule.behavior },
                    set: { state.setBehavior($0, for: rule.id) }
                )
            ) {
                ForEach(AppBehavior.allCases) { behavior in
                    Text(behavior.title).tag(behavior)
                }
            }
            .labelsHidden()
            .frame(width: 150)

            if !rule.isPreset {
                Button {
                    state.removeRule(rule.id)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("移除规则")
            } else {
                Color.clear.frame(width: 16, height: 16)
            }
        }
        .padding(.vertical, 5)
    }
}
