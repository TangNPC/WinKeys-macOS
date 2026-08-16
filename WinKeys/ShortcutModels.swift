import CoreGraphics
import Foundation

enum AppBehavior: String, Codable, CaseIterable, Identifiable {
    case standard
    case preserveControl
    case bypass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Windows 模式"
        case .preserveControl: "保留 Control"
        case .bypass: "完全透传"
        }
    }
}

struct AppRule: Codable, Identifiable, Equatable {
    let id: UUID
    var bundleIdentifier: String
    var displayName: String
    var applicationPath: String?
    var behavior: AppBehavior
    var isPreset: Bool
}

struct ShortcutConfiguration: Equatable {
    var editingShortcuts: Bool
    var textNavigation: Bool
    var appSwitching: Bool
    var finderShortcuts: Bool
    var systemLaunchers: Bool
    var windowManagement: Bool
    var clipboardHistory: Bool

    static let `default` = ShortcutConfiguration(
        editingShortcuts: true,
        textNavigation: true,
        appSwitching: true,
        finderShortcuts: true,
        systemLaunchers: true,
        windowManagement: true,
        clipboardHistory: true
    )
}

enum ShortcutAction: Equatable {
    case openFinder
    case openLaunchpad
    case openActivityMonitor
    case showDesktop
    case lockScreen
    case captureRegion
    case showMissionControl
    case navigateBack
    case navigateForward
    case openSystemSettings
    case showEmojiPicker
    case showForceQuit
    case showClipboardHistory
    case tileWindowLeft
    case tileWindowRight
    case maximizeWindow
    case restoreOrMinimizeWindow
}

enum TranslationDecision: Equatable {
    case passthrough
    case remap(keyCode: CGKeyCode, flags: CGEventFlags)
    case perform(ShortcutAction)
}

enum KeyCode {
    static let a: CGKeyCode = 0
    static let s: CGKeyCode = 1
    static let d: CGKeyCode = 2
    static let f: CGKeyCode = 3
    static let h: CGKeyCode = 4
    static let g: CGKeyCode = 5
    static let z: CGKeyCode = 6
    static let x: CGKeyCode = 7
    static let c: CGKeyCode = 8
    static let v: CGKeyCode = 9
    static let b: CGKeyCode = 11
    static let q: CGKeyCode = 12
    static let w: CGKeyCode = 13
    static let r: CGKeyCode = 15
    static let y: CGKeyCode = 16
    static let t: CGKeyCode = 17
    static let four: CGKeyCode = 21
    static let rightBracket: CGKeyCode = 30
    static let o: CGKeyCode = 31
    static let u: CGKeyCode = 32
    static let leftBracket: CGKeyCode = 33
    static let i: CGKeyCode = 34
    static let p: CGKeyCode = 35
    static let l: CGKeyCode = 37
    static let n: CGKeyCode = 45
    static let m: CGKeyCode = 46
    static let period: CGKeyCode = 47
    static let tab: CGKeyCode = 48
    static let space: CGKeyCode = 49
    static let delete: CGKeyCode = 51
    static let rightCommand: CGKeyCode = 54
    static let leftCommand: CGKeyCode = 55
    static let escape: CGKeyCode = 53
    static let returnKey: CGKeyCode = 36
    static let f5: CGKeyCode = 96
    static let f4: CGKeyCode = 118
    static let f11: CGKeyCode = 103
    static let f2: CGKeyCode = 120
    static let home: CGKeyCode = 115
    static let end: CGKeyCode = 119
    static let forwardDelete: CGKeyCode = 117
    static let leftArrow: CGKeyCode = 123
    static let rightArrow: CGKeyCode = 124
    static let downArrow: CGKeyCode = 125
    static let upArrow: CGKeyCode = 126
}

let winKeysSyntheticEventMarker: Int64 = 0x574B_4559
