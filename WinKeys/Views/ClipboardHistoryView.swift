import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var store: ClipboardHistoryStore
    let onPaste: (ClipboardHistoryItem) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @FocusState private var searchIsFocused: Bool

    private var filteredItems: [ClipboardHistoryItem] {
        guard !query.isEmpty else { return store.items }
        return store.items.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索剪贴板", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchIsFocused)
                    .onSubmit {
                        if let first = filteredItems.first {
                            onPaste(first)
                        }
                    }
            }
            .padding(14)

            Divider()

            if filteredItems.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "暂无剪贴板记录" : "没有匹配项",
                    systemImage: query.isEmpty ? "clipboard" : "magnifyingglass"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            Button {
                                onPaste(item)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "doc.on.clipboard")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20, height: 20)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.text)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(item.copiedAt, style: .time)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("删除", role: .destructive) {
                                    store.remove(item)
                                }
                            }
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Text("\(store.items.count) / 50")
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    store.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("清空历史")
                .disabled(store.items.isEmpty)
            }
            .padding(12)
        }
        .frame(minWidth: 480, minHeight: 360)
        .onAppear { searchIsFocused = true }
        .onExitCommand(perform: onClose)
    }
}
