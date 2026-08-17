import AppKit
import ApplicationServices

final class WindowManager {
    enum Operation {
        case tileLeft
        case tileRight
        case maximize
        case restoreOrMinimize
    }

    private var restoreFrames: [String: CGRect] = [:]
    private var recentlyMinimizedWindow: MinimizedWindow?
    private var activationObserver: NSObjectProtocol?
    private let desktopQueue = DispatchQueue(label: "com.oxygen.WinKeys.desktop", qos: .userInitiated)

    init() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }
            if self?.recentlyMinimizedWindow?.processIdentifier != application.processIdentifier {
                self?.recentlyMinimizedWindow = nil
            }
        }
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    func perform(_ operation: Operation) -> String? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return "当前应用没有可调整的窗口。"
        }

        if case .maximize = operation,
           let minimizedWindow = recentlyMinimizedWindow,
           minimizedWindow.processIdentifier == application.processIdentifier {
            let focusedKey = focusedWindow(for: application).map {
                windowKey($0, application: application)
            }
            if focusedKey == nil || focusedKey == minimizedWindow.key {
                recentlyMinimizedWindow = nil
                return restoreMinimizedWindow(minimizedWindow.window)
            }
        }

        guard let window = focusedWindow(for: application) else {
            return "当前应用没有可调整的窗口。"
        }

        guard let currentFrame = frame(of: window),
              let visibleFrame = visibleFrame(containing: currentFrame) else {
            return "无法读取当前窗口的位置。"
        }

        let key = windowKey(window, application: application)
        if recentlyMinimizedWindow?.key != key {
            recentlyMinimizedWindow = nil
        }
        switch operation {
        case .tileLeft:
            remember(currentFrame, for: key)
            let target = CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
            return setFrame(target, of: window) ? nil : "当前窗口不允许调整大小。"

        case .tileRight:
            remember(currentFrame, for: key)
            let target = CGRect(
                x: visibleFrame.midX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
            return setFrame(target, of: window) ? nil : "当前窗口不允许调整大小。"

        case .maximize:
            remember(currentFrame, for: key)
            return setFrame(visibleFrame, of: window) ? nil : "当前窗口不允许最大化。"

        case .restoreOrMinimize:
            if let restoreFrame = restoreFrames.removeValue(forKey: key) {
                return setFrame(restoreFrame, of: window) ? nil : "无法恢复当前窗口。"
            }
            let result = AXUIElementSetAttributeValue(
                window,
                kAXMinimizedAttribute as CFString,
                kCFBooleanTrue
            )
            if result == .success {
                recentlyMinimizedWindow = MinimizedWindow(
                    processIdentifier: application.processIdentifier,
                    key: key,
                    window: window
                )
            }
            return result == .success ? nil : "当前窗口不允许最小化。"
        }
    }

    /// Minimizes every visible window without relying on the user's F11 setting.
    func minimizeAllWindows(completion: @escaping (String?) -> Void) {
        desktopQueue.async {
            let visibleProcessIDs = Set(
                (CGWindowListCopyWindowInfo(
                    [.optionOnScreenOnly, .excludeDesktopElements],
                    kCGNullWindowID
                ) as? [[String: Any]] ?? []).compactMap {
                    ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
                }
            )
            let candidateWindows = NSWorkspace.shared.runningApplications
                .filter {
                    visibleProcessIDs.contains($0.processIdentifier)
                        && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                }
                .flatMap { self.windows(for: $0) }

            var minimizedCount = 0
            let minimizedLock = NSLock()
            DispatchQueue.concurrentPerform(iterations: candidateWindows.count) { index in
                if AXUIElementSetAttributeValue(
                    candidateWindows[index],
                    kAXMinimizedAttribute as CFString,
                    kCFBooleanTrue
                ) == .success {
                    minimizedLock.lock()
                    minimizedCount += 1
                    minimizedLock.unlock()
                }
            }
            let error = minimizedCount > 0 ? nil : "当前没有可隐藏的窗口。"
            DispatchQueue.main.async { completion(error) }
        }
    }

    private func windows(for application: NSRunningApplication) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let values = value as? [AXUIElement] else { return [] }
        return values
    }

    func restoreMinimizedWindows(for application: NSRunningApplication) {
        guard application.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        var candidates: [AXUIElement] = []
        if let focused = focusedWindow(for: application) {
            candidates.append(focused)
        }
        candidates.append(contentsOf: windows(for: application))

        for window in candidates {
            let result = AXUIElementSetAttributeValue(
                window,
                kAXMinimizedAttribute as CFString,
                kCFBooleanFalse
            )
            if result == .success {
                _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            }
        }
    }

    private func restoreMinimizedWindow(_ window: AXUIElement) -> String? {
        let result = AXUIElementSetAttributeValue(
            window,
            kAXMinimizedAttribute as CFString,
            kCFBooleanFalse
        )
        guard result == .success else { return "无法恢复刚才最小化的窗口。" }
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        return nil
    }

    private func focusedWindow(for application: NSRunningApplication) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        ) == .success, let value else { return nil }
        return (value as! AXUIElement)
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func setFrame(_ frame: CGRect, of window: AXUIElement) -> Bool {
        var position = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return false }

        // Accessibility exposes position and size separately. Resize first so
        // the window does not briefly flash at its destination before expanding.
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )
        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        )
        return positionResult == .success && sizeResult == .success
    }

    private func remember(_ frame: CGRect, for key: String) {
        if restoreFrames[key] == nil {
            restoreFrames[key] = frame
        }
    }

    private func windowKey(_ window: AXUIElement, application: NSRunningApplication) -> String {
        "\(application.processIdentifier):\(CFHash(window))"
    }

    private func visibleFrame(containing windowFrame: CGRect) -> CGRect? {
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        let geometries = NSScreen.screens.compactMap(screenGeometry)
        return geometries.first(where: { $0.displayFrame.contains(center) })?.visibleFrame
            ?? geometries.first?.visibleFrame
    }

    private func screenGeometry(for screen: NSScreen) -> ScreenGeometry? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        let displayFrame = CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
        let cocoaFrame = screen.frame
        let cocoaVisible = screen.visibleFrame

        let leftInset = cocoaVisible.minX - cocoaFrame.minX
        let rightInset = cocoaFrame.maxX - cocoaVisible.maxX
        let topInset = cocoaFrame.maxY - cocoaVisible.maxY
        let bottomInset = cocoaVisible.minY - cocoaFrame.minY
        let visibleFrame = CGRect(
            x: displayFrame.minX + leftInset,
            y: displayFrame.minY + topInset,
            width: displayFrame.width - leftInset - rightInset,
            height: displayFrame.height - topInset - bottomInset
        )
        return ScreenGeometry(displayFrame: displayFrame, visibleFrame: visibleFrame)
    }

    private struct ScreenGeometry {
        let displayFrame: CGRect
        let visibleFrame: CGRect
    }

    private struct MinimizedWindow {
        let processIdentifier: pid_t
        let key: String
        let window: AXUIElement
    }
}
