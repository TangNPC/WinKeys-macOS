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

        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        )
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
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
