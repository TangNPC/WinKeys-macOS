import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import ServiceManagement
import UniformTypeIdentifiers

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
            syncEngine()
        }
    }

    @Published var editingShortcuts: Bool {
        didSet { save(editingShortcuts, key: Keys.editingShortcuts) }
    }
    @Published var textNavigation: Bool {
        didSet { save(textNavigation, key: Keys.textNavigation) }
    }
    @Published var appSwitching: Bool {
        didSet { save(appSwitching, key: Keys.appSwitching) }
    }
    @Published var finderShortcuts: Bool {
        didSet { save(finderShortcuts, key: Keys.finderShortcuts) }
    }
    @Published var systemLaunchers: Bool {
        didSet { save(systemLaunchers, key: Keys.systemLaunchers) }
    }
    @Published var windowManagement: Bool {
        didSet { save(windowManagement, key: Keys.windowManagement) }
    }
    @Published var clipboardHistoryEnabled: Bool {
        didSet {
            save(clipboardHistoryEnabled, key: Keys.clipboardHistoryEnabled)
            syncClipboardMonitoring()
        }
    }

    @Published private(set) var accessibilityGranted = false
    @Published private(set) var inputMonitoringGranted = false
    @Published private(set) var engineIsRunning = false
    @Published private(set) var launchAtLogin = false
    @Published private(set) var engineError: String?
    @Published private(set) var appRules: [AppRule]

    var shortcutConfiguration: ShortcutConfiguration {
        ShortcutConfiguration(
            editingShortcuts: editingShortcuts,
            textNavigation: textNavigation,
            appSwitching: appSwitching,
            finderShortcuts: finderShortcuts,
            systemLaunchers: systemLaunchers,
            windowManagement: windowManagement,
            clipboardHistory: clipboardHistoryEnabled
        )
    }

    var allPermissionsGranted: Bool {
        accessibilityGranted && inputMonitoringGranted
    }

    private let defaults = UserDefaults.standard
    private let windowManager = WindowManager()
    private let clipboardStore = ClipboardHistoryStore()
    private lazy var shortcutEngine = ShortcutEngine(delegate: self)
    private lazy var clipboardPanel = ClipboardPanelController(store: clipboardStore)
    private lazy var settingsWindowController = SettingsWindowController(state: self)
    private var permissionTimer: Timer?
    private var notificationObservers: [NSObjectProtocol] = []
    private var hasStarted = false
    private var desktopOperationInProgress = false
    private var appBehaviorsByBundleIdentifier: [String: AppBehavior] = [:]
    private var iconCache: [String: NSImage] = [:]

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let editingShortcuts = "editingShortcuts"
        static let textNavigation = "textNavigation"
        static let appSwitching = "appSwitching"
        static let finderShortcuts = "finderShortcuts"
        static let systemLaunchers = "systemLaunchers"
        static let windowManagement = "windowManagement"
        static let clipboardHistoryEnabled = "clipboardHistoryEnabled"
        static let appRules = "appRules"
    }

    private init() {
        defaults.register(defaults: [
            Keys.isEnabled: true,
            Keys.editingShortcuts: true,
            Keys.textNavigation: true,
            Keys.appSwitching: true,
            Keys.finderShortcuts: true,
            Keys.systemLaunchers: true,
            Keys.windowManagement: true,
            Keys.clipboardHistoryEnabled: true
        ])

        isEnabled = defaults.bool(forKey: Keys.isEnabled)
        editingShortcuts = defaults.bool(forKey: Keys.editingShortcuts)
        textNavigation = defaults.bool(forKey: Keys.textNavigation)
        appSwitching = defaults.bool(forKey: Keys.appSwitching)
        finderShortcuts = defaults.bool(forKey: Keys.finderShortcuts)
        systemLaunchers = defaults.bool(forKey: Keys.systemLaunchers)
        windowManagement = defaults.bool(forKey: Keys.windowManagement)
        clipboardHistoryEnabled = defaults.bool(forKey: Keys.clipboardHistoryEnabled)
        appRules = Self.loadRules(from: defaults) ?? Self.defaultRules()
        appBehaviorsByBundleIdentifier = Dictionary(
            appRules.map { ($0.bundleIdentifier, $0.behavior) },
            uniquingKeysWith: { _, latest in latest }
        )
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    deinit {
        permissionTimer?.invalidate()
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        refreshPermissions()
        syncClipboardMonitoring()

        let didBecomeActive = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPermissions()
        }
        notificationObservers.append(didBecomeActive)
    }

    func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermissions()
    }

    func requestInputMonitoringPermission() {
        _ = CGRequestListenEventAccess()
        refreshPermissions()
    }

    func refreshPermissionStatus() {
        refreshPermissions()
    }

    func relaunch() {
        shortcutEngine.stop()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error {
                    self?.engineError = "无法重新启动：\(error.localizedDescription)"
                } else {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    func openAccessibilitySettings() {
        openSystemSettings(anchor: "Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openSystemSettings(anchor: "Privacy_ListenEvent")
    }

    func openKeyboardSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            engineError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            engineError = "无法修改登录项：\(error.localizedDescription)"
        }
    }

    func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "选择应用"
        panel.prompt = "添加"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else { return }

        if let existing = appRules.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
            appRules[existing].applicationPath = url.path
            appRules[existing].displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
        } else {
            appRules.append(
                AppRule(
                    id: UUID(),
                    bundleIdentifier: bundleIdentifier,
                    displayName: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? url.deletingPathExtension().lastPathComponent,
                    applicationPath: url.path,
                    behavior: .bypass,
                    isPreset: false
                )
            )
        }
        appRules.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        saveRules()
    }

    func showClipboardHistory() {
        clipboardPanel.show()
    }

    func showSettings() {
        settingsWindowController.show()
    }

    func setBehavior(_ behavior: AppBehavior, for ruleID: UUID) {
        guard let index = appRules.firstIndex(where: { $0.id == ruleID }) else { return }
        appRules[index].behavior = behavior
        saveRules()
    }

    func removeRule(_ ruleID: UUID) {
        appRules.removeAll { $0.id == ruleID && !$0.isPreset }
        saveRules()
    }

    func icon(for rule: AppRule) -> NSImage {
        let cacheKey = rule.applicationPath ?? rule.bundleIdentifier
        if let cached = iconCache[cacheKey] { return cached }

        let icon: NSImage
        if let path = rule.applicationPath, FileManager.default.fileExists(atPath: path) {
            icon = NSWorkspace.shared.icon(forFile: path)
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleIdentifier) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSImage(systemSymbolName: "app", accessibilityDescription: rule.displayName) ?? NSImage()
        }
        iconCache[cacheKey] = icon
        return icon
    }

    private func save(_ value: Bool, key: String) {
        defaults.set(value, forKey: key)
    }

    private func refreshPermissions() {
        let newAccessibility = AXIsProcessTrusted()
        let newInputMonitoring = CGPreflightListenEventAccess()
        let changed = newAccessibility != accessibilityGranted || newInputMonitoring != inputMonitoringGranted

        accessibilityGranted = newAccessibility
        inputMonitoringGranted = newInputMonitoring

        if changed || (isEnabled && !engineIsRunning) {
            syncEngine()
        }
        updatePermissionTimer()
    }

    private func syncEngine() {
        guard hasStarted else { return }
        guard isEnabled, allPermissionsGranted else {
            shortcutEngine.stop()
            engineIsRunning = false
            return
        }
        shortcutEngine.start()
    }

    private func syncClipboardMonitoring() {
        guard hasStarted else { return }
        if clipboardHistoryEnabled {
            clipboardStore.start()
        } else {
            clipboardStore.stop()
        }
    }

    private func saveRules() {
        appBehaviorsByBundleIdentifier = Dictionary(
            appRules.map { ($0.bundleIdentifier, $0.behavior) },
            uniquingKeysWith: { _, latest in latest }
        )
        guard let data = try? JSONEncoder().encode(appRules) else { return }
        defaults.set(data, forKey: Keys.appRules)
    }

    private func updatePermissionTimer() {
        guard hasStarted else { return }
        if allPermissionsGranted {
            permissionTimer?.invalidate()
            permissionTimer = nil
            return
        }
        guard permissionTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshPermissions()
        }
        permissionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func openSystemSettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func loadRules(from defaults: UserDefaults) -> [AppRule]? {
        guard let data = defaults.data(forKey: Keys.appRules) else { return nil }
        return try? JSONDecoder().decode([AppRule].self, from: data)
    }

    private static func defaultRules() -> [AppRule] {
        var rules = [
            AppRule(
                id: UUID(),
                bundleIdentifier: "com.apple.Terminal",
                displayName: "Terminal",
                applicationPath: "/System/Applications/Utilities/Terminal.app",
                behavior: .preserveControl,
                isPreset: true
            )
        ]

        let candidates: [(String, String, AppBehavior)] = [
            ("com.googlecode.iterm2", "iTerm", .preserveControl),
            ("dev.warp.Warp-Stable", "Warp", .preserveControl),
            ("net.kovidgoyal.kitty", "kitty", .preserveControl),
            ("io.alacritty", "Alacritty", .preserveControl),
            ("com.microsoft.rdc.macos", "Windows App", .bypass),
            ("com.parallels.desktop.console", "Parallels Desktop", .bypass),
            ("com.vmware.fusion", "VMware Fusion", .bypass)
        ]

        for (bundleIdentifier, fallbackName, behavior) in candidates {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { continue }
            let bundle = Bundle(url: url)
            let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? fallbackName
            rules.append(
                AppRule(
                    id: UUID(),
                    bundleIdentifier: bundleIdentifier,
                    displayName: displayName,
                    applicationPath: url.path,
                    behavior: behavior,
                    isPreset: true
                )
            )
        }
        return rules
    }
}

extension AppState: ShortcutEngineDelegate {
    func shortcutEngineBehavior(for bundleIdentifier: String?) -> AppBehavior {
        guard let bundleIdentifier else { return .standard }
        return appBehaviorsByBundleIdentifier[bundleIdentifier] ?? .standard
    }

    func shortcutEngineDidChange(running: Bool, error: String?) {
        engineIsRunning = running
        if let error {
            engineError = error
        } else if running {
            engineError = nil
        }
    }

    func shortcutEnginePerform(_ action: ShortcutAction) {
        switch action {
        case .openFinder:
            NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true))

        case .openLaunchpad:
            let url = URL(fileURLWithPath: "/System/Applications/Launchpad.app")
            NSWorkspace.shared.openApplication(at: url, configuration: .init())

        case .openActivityMonitor:
            let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
            NSWorkspace.shared.openApplication(at: url, configuration: .init())

        case .showDesktop:
            guard !desktopOperationInProgress else { return }
            desktopOperationInProgress = true
            windowManager.minimizeAllWindows { [weak self] error in
                self?.desktopOperationInProgress = false
                self?.engineError = error
            }

        case .lockScreen:
            SyntheticKeyboard.press(KeyCode.q, flags: [.maskControl, .maskCommand])

        case .captureRegion:
            SyntheticKeyboard.press(KeyCode.four, flags: [.maskCommand, .maskShift])

        case .showMissionControl:
            let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
            NSWorkspace.shared.openApplication(at: url, configuration: .init())

        case .navigateBack:
            SyntheticKeyboard.press(KeyCode.leftBracket, flags: [.maskCommand])

        case .navigateForward:
            SyntheticKeyboard.press(KeyCode.rightBracket, flags: [.maskCommand])

        case .quitApplication:
            guard let application = NSWorkspace.shared.frontmostApplication else { return }
            if application.processIdentifier == ProcessInfo.processInfo.processIdentifier {
                NSApplication.shared.terminate(nil)
            } else {
                application.terminate()
            }

        case .openSystemSettings:
            let url = URL(fileURLWithPath: "/System/Applications/System Settings.app")
            NSWorkspace.shared.openApplication(at: url, configuration: .init())

        case .showEmojiPicker:
            SyntheticKeyboard.press(KeyCode.space, flags: [.maskControl, .maskCommand])

        case .showForceQuit:
            SyntheticKeyboard.press(KeyCode.escape, flags: [.maskAlternate, .maskCommand])

        case .showClipboardHistory:
            showClipboardHistory()

        case .tileWindowLeft:
            performWindowOperation(.tileLeft)

        case .tileWindowRight:
            performWindowOperation(.tileRight)

        case .maximizeWindow:
            performWindowOperation(.maximize)

        case .restoreOrMinimizeWindow:
            performWindowOperation(.restoreOrMinimize)
        }
    }

    func shortcutEngineActivateSelectedApplication() {
        guard let application = NSWorkspace.shared.frontmostApplication else { return }
        application.activate(options: [.activateAllWindows])
        let hasWindows = windowManager.restoreMinimizedWindows(for: application)

        guard !hasWindows,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let applicationURL = application.bundleURL else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        configuration.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { [weak self] _, error in
            guard let error else { return }
            DispatchQueue.main.async {
                self?.engineError = "无法重新打开所选应用：\(error.localizedDescription)"
            }
        }
    }

    private func performWindowOperation(_ operation: WindowManager.Operation) {
        if let error = windowManager.perform(operation) {
            engineError = error
        } else {
            engineError = nil
        }
    }
}
