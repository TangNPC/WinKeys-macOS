import AppKit
import Combine
import SwiftUI

struct ClipboardHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let copiedAt: Date
}

final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardHistoryItem]

    private let pasteboard = NSPasteboard.general
    private let defaults = UserDefaults.standard
    private let storageKey = "clipboardHistoryItems"
    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
        lastChangeCount = pasteboard.changeCount
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ClipboardHistoryItem].self, from: data) {
            items = decoded
        } else {
            items = []
        }
    }

    func start() {
        guard timer == nil else { return }
        captureCurrentClipboard()
        let newTimer = Timer(timeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.captureIfChanged()
        }
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func copy(_ item: ClipboardHistoryItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        insert(text: item.text)
    }

    func remove(_ item: ClipboardHistoryItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }

    private func captureIfChanged() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        captureCurrentClipboard()
    }

    private func captureCurrentClipboard() {
        let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        guard pasteboard.availableType(from: [concealedType, transientType]) == nil else { return }
        guard let text = pasteboard.string(forType: .string) else { return }
        insert(text: text)
    }

    private func insert(text: String) {
        guard !text.isEmpty, text.utf8.count <= 200_000 else { return }
        items.removeAll { $0.text == text }
        items.insert(ClipboardHistoryItem(id: UUID(), text: text, copiedAt: Date()), at: 0)
        if items.count > 50 {
            items.removeLast(items.count - 50)
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

final class ClipboardPanelController {
    private let store: ClipboardHistoryStore
    private var panel: NSPanel?
    private var targetApplication: NSRunningApplication?

    init(store: ClipboardHistoryStore) {
        self.store = store
    }

    func show() {
        targetApplication = NSWorkspace.shared.frontmostApplication

        let rootView = ClipboardHistoryView(
            store: store,
            onPaste: { [weak self] item in self?.paste(item) },
            onClose: { [weak self] in self?.panel?.orderOut(nil) }
        )

        if panel == nil {
            let newPanel = NSPanel(
                contentRect: CGRect(x: 0, y: 0, width: 520, height: 430),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            newPanel.title = "剪贴板历史"
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.isReleasedWhenClosed = false
            newPanel.center()
            panel = newPanel
        }

        panel?.contentViewController = NSHostingController(rootView: rootView)
        panel?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func paste(_ item: ClipboardHistoryItem) {
        store.copy(item)
        panel?.orderOut(nil)
        targetApplication?.activate(options: [.activateIgnoringOtherApps])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            SyntheticKeyboard.press(KeyCode.v, flags: [.maskCommand])
        }
    }
}
