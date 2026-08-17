import AppKit
import CoreGraphics

protocol ShortcutEngineDelegate: AnyObject {
    var shortcutConfiguration: ShortcutConfiguration { get }
    func shortcutEngineBehavior(for bundleIdentifier: String?) -> AppBehavior
    func shortcutEngineDidChange(running: Bool, error: String?)
    func shortcutEnginePerform(_ action: ShortcutAction)
    func shortcutEngineActivateSelectedApplication()
}

final class ShortcutEngine {
    weak var delegate: ShortcutEngineDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var commandOnlyCandidate: CGKeyCode?
    private var pendingAppSwitchRestore = false
    private var frontmostBundleIdentifier: String?
    private var activationObserver: NSObjectProtocol?

    init(delegate: ShortcutEngineDelegate) {
        self.delegate = delegate
        frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            self?.frontmostBundleIdentifier = application?.bundleIdentifier
        }
    }

    deinit {
        stop()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    func start() {
        guard eventTap == nil else { return }

        let eventMask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.rightMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.otherMouseDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let engine = Unmanaged<ShortcutEngine>.fromOpaque(userInfo).takeUnretainedValue()
            return engine.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            delegate?.shortcutEngineDidChange(
                running: false,
                error: "无法启动键盘监听，请确认权限后重新启用。"
            )
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        delegate?.shortcutEngineDidChange(running: true, error: nil)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        commandOnlyCandidate = nil
        pendingAppSwitchRestore = false
        delegate?.shortcutEngineDidChange(running: false, error: nil)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            commandOnlyCandidate = nil
            pendingAppSwitchRestore = false
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown {
            commandOnlyCandidate = nil
            return Unmanaged.passUnretained(event)
        }

        guard let delegate else { return Unmanaged.passUnretained(event) }

        if event.getIntegerValueField(.eventSourceUserData) == winKeysSyntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .flagsChanged {
            return handleModifierChange(keyCode: keyCode, event: event, delegate: delegate)
        }

        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            commandOnlyCandidate = nil
        }

        let bundleIdentifier = frontmostBundleIdentifier
        let decision = ShortcutTranslator.decision(
            keyCode: keyCode,
            flags: event.flags,
            behavior: delegate.shortcutEngineBehavior(for: bundleIdentifier),
            frontmostBundleIdentifier: bundleIdentifier,
            configuration: delegate.shortcutConfiguration
        )

        switch decision {
        case .passthrough:
            return Unmanaged.passUnretained(event)

        case let .remap(newKeyCode, newFlags):
            let wasAltTab = keyCode == KeyCode.tab && event.flags.contains(.maskAlternate)
            event.setIntegerValueField(.keyboardEventKeycode, value: Int64(newKeyCode))
            event.flags = newFlags
            if wasAltTab {
                pendingAppSwitchRestore = true
            }
            return Unmanaged.passUnretained(event)

        case let .perform(action):
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if type == .keyDown, !isRepeat {
                DispatchQueue.main.async {
                    delegate.shortcutEnginePerform(action)
                }
            }
            return nil
        }
    }

    private func handleModifierChange(
        keyCode: CGKeyCode,
        event: CGEvent,
        delegate: ShortcutEngineDelegate
    ) -> Unmanaged<CGEvent>? {
        if pendingAppSwitchRestore, !event.flags.contains(.maskAlternate) {
            pendingAppSwitchRestore = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                delegate.shortcutEngineActivateSelectedApplication()
            }
        }

        let isCommandKey = keyCode == KeyCode.leftCommand || keyCode == KeyCode.rightCommand
        guard isCommandKey else {
            commandOnlyCandidate = nil
            return Unmanaged.passUnretained(event)
        }

        if event.flags.contains(.maskCommand) {
            let modifiers = event.flags.intersection([
                .maskCommand, .maskControl, .maskAlternate, .maskShift
            ])
            let bundleIdentifier = frontmostBundleIdentifier
            let isEligible = modifiers == .maskCommand
                && delegate.shortcutConfiguration.systemLaunchers
                && delegate.shortcutEngineBehavior(for: bundleIdentifier) != .bypass
            commandOnlyCandidate = isEligible ? keyCode : nil
            return Unmanaged.passUnretained(event)
        }

        let shouldOpenLaunchpad = commandOnlyCandidate == keyCode
        commandOnlyCandidate = nil
        if shouldOpenLaunchpad {
            DispatchQueue.main.async {
                delegate.shortcutEnginePerform(.openLaunchpad)
            }
        }
        return Unmanaged.passUnretained(event)
    }
}
