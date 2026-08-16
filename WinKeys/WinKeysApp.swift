import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.start()
    }
}

final class SettingsWindowController {
    private weak var state: AppState?
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        guard let state else { return }

        if window == nil {
            let newWindow = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 760, height: 540),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "WinKeys"
            newWindow.contentMinSize = NSSize(width: 760, height: 540)
            newWindow.contentViewController = NSHostingController(
                rootView: RootView().environmentObject(state)
            )
            newWindow.isReleasedWhenClosed = false
            newWindow.setFrameAutosaveName("WinKeysSettingsWindow")
            newWindow.center()
            window = newWindow
        }

        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@main
struct WinKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(state)
        } label: {
            Image(systemName: state.engineIsRunning ? "keyboard.fill" : "keyboard")
        }
    }
}
