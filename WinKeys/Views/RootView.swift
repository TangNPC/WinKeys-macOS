import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case overview
    case shortcuts
    case applications

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "概览"
        case .shortcuts: "快捷键"
        case .applications: "应用规则"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "switch.2"
        case .shortcuts: "keyboard"
        case .applications: "square.stack.3d.up"
        }
    }
}

struct RootView: View {
    @State private var selection: SettingsPane? = .overview

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.symbol)
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 190, max: 220)
        } detail: {
            switch selection ?? .overview {
            case .overview:
                DashboardView()
            case .shortcuts:
                ShortcutRulesView()
            case .applications:
                ApplicationRulesView()
            }
        }
    }
}
