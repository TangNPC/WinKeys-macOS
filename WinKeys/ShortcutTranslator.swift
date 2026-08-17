import CoreGraphics

enum ShortcutTranslator {
    private static let editingKeyCodes: Set<CGKeyCode> = [
        KeyCode.a, KeyCode.s, KeyCode.f, KeyCode.z, KeyCode.x, KeyCode.c,
        KeyCode.v, KeyCode.b, KeyCode.w, KeyCode.r, KeyCode.t, KeyCode.o,
        KeyCode.u, KeyCode.i, KeyCode.p, KeyCode.l, KeyCode.n
    ]

    static func decision(
        keyCode: CGKeyCode,
        flags: CGEventFlags,
        behavior: AppBehavior,
        frontmostBundleIdentifier: String?,
        configuration: ShortcutConfiguration
    ) -> TranslationDecision {
        guard behavior != .bypass else { return .passthrough }

        if configuration.editingShortcuts,
           behavior == .preserveControl,
           (keyCode == KeyCode.c || keyCode == KeyCode.v),
           hasExactly(flags, required: [.maskControl, .maskShift]) {
            return .remap(
                keyCode: keyCode,
                flags: replacing(flags, remove: [.maskControl, .maskShift], add: [.maskCommand])
            )
        }

        if configuration.finderShortcuts,
           behavior == .standard,
           frontmostBundleIdentifier == "com.apple.finder" {
            if keyCode == KeyCode.f2, shortcutModifiers(in: flags).isEmpty {
                return .remap(keyCode: KeyCode.returnKey, flags: flags)
            }

            if keyCode == KeyCode.forwardDelete, shortcutModifiers(in: flags).isEmpty {
                return .remap(keyCode: KeyCode.delete, flags: replacing(flags, remove: [], add: [.maskCommand]))
            }

            if keyCode == KeyCode.returnKey, hasExactly(flags, required: [.maskAlternate]) {
                return .remap(
                    keyCode: KeyCode.i,
                    flags: replacing(flags, remove: [.maskAlternate], add: [.maskCommand])
                )
            }
        }

        if configuration.systemLaunchers,
           (keyCode == KeyCode.delete || keyCode == KeyCode.forwardDelete),
           hasExactly(flags, required: [.maskControl, .maskAlternate]) {
            return .perform(.showForceQuit)
        }

        if behavior == .standard {
            if configuration.systemLaunchers,
               keyCode == KeyCode.escape,
               hasExactly(flags, required: [.maskControl, .maskShift]) {
                return .perform(.openActivityMonitor)
            }

            if configuration.textNavigation,
               flags.contains(.maskControl),
               !flags.contains(.maskCommand),
               !flags.contains(.maskAlternate) {
                switch keyCode {
                case KeyCode.leftArrow, KeyCode.rightArrow:
                    return .remap(
                        keyCode: keyCode,
                        flags: replacing(flags, remove: [.maskControl], add: [.maskAlternate])
                    )
                case KeyCode.delete, KeyCode.forwardDelete:
                    return .remap(
                        keyCode: keyCode,
                        flags: replacing(flags, remove: [.maskControl], add: [.maskAlternate])
                    )
                case KeyCode.home:
                    return .remap(
                        keyCode: KeyCode.upArrow,
                        flags: replacing(flags, remove: [.maskControl], add: [.maskCommand])
                    )
                case KeyCode.end:
                    return .remap(
                        keyCode: KeyCode.downArrow,
                        flags: replacing(flags, remove: [.maskControl], add: [.maskCommand])
                    )
                default:
                    break
                }
            }

            if configuration.textNavigation,
               !flags.contains(.maskControl),
               !flags.contains(.maskAlternate),
               !flags.contains(.maskCommand) {
                if keyCode == KeyCode.home {
                    return .remap(keyCode: KeyCode.leftArrow, flags: replacing(flags, remove: [], add: [.maskCommand]))
                }
                if keyCode == KeyCode.end {
                    return .remap(keyCode: KeyCode.rightArrow, flags: replacing(flags, remove: [], add: [.maskCommand]))
                }
            }

            if configuration.editingShortcuts,
               flags.contains(.maskControl),
               !flags.contains(.maskCommand),
               !flags.contains(.maskAlternate) {
                if keyCode == KeyCode.y {
                    return .remap(
                        keyCode: KeyCode.z,
                        flags: replacing(flags, remove: [.maskControl], add: [.maskCommand, .maskShift])
                    )
                }

                if editingKeyCodes.contains(keyCode) {
                    return .remap(
                        keyCode: keyCode,
                        flags: replacing(flags, remove: [.maskControl], add: [.maskCommand])
                    )
                }
            }

            if configuration.appSwitching,
               hasExactly(flags, required: [.maskAlternate]) {
                if keyCode == KeyCode.leftArrow {
                    return .perform(.navigateBack)
                }
                if keyCode == KeyCode.rightArrow {
                    return .perform(.navigateForward)
                }
            }

            if configuration.systemLaunchers,
               keyCode == KeyCode.f5,
               shortcutModifiers(in: flags).isEmpty {
                return .remap(keyCode: KeyCode.r, flags: replacing(flags, remove: [], add: [.maskCommand]))
            }
        }

        if configuration.appSwitching,
           flags.contains(.maskAlternate),
           !flags.contains(.maskCommand),
           !flags.contains(.maskControl) {
            if keyCode == KeyCode.tab {
                return .remap(
                    keyCode: KeyCode.tab,
                    flags: replacing(flags, remove: [.maskAlternate], add: [.maskCommand])
                )
            }

            if keyCode == KeyCode.f4 {
                return .perform(.quitApplication)
            }
        }

        if configuration.systemLaunchers,
           hasExactly(flags, required: [.maskCommand]) {
            if keyCode == 14 {
                return .perform(.openFinder)
            }
            if keyCode == KeyCode.d {
                return .perform(.showDesktop)
            }
            if keyCode == KeyCode.l {
                return .perform(.lockScreen)
            }
            if keyCode == KeyCode.i {
                return .perform(.openSystemSettings)
            }
            if keyCode == KeyCode.tab {
                return .perform(.showMissionControl)
            }
            if keyCode == KeyCode.period {
                return .perform(.showEmojiPicker)
            }
        }

        if configuration.clipboardHistory,
           keyCode == KeyCode.v,
           hasExactly(flags, required: [.maskCommand]) {
            return .perform(.showClipboardHistory)
        }

        if configuration.systemLaunchers,
           keyCode == KeyCode.s,
           hasExactly(flags, required: [.maskCommand, .maskShift]) {
            return .perform(.captureRegion)
        }

        if configuration.windowManagement,
           hasExactly(flags, required: [.maskCommand]) {
            switch keyCode {
            case KeyCode.leftArrow:
                return .perform(.tileWindowLeft)
            case KeyCode.rightArrow:
                return .perform(.tileWindowRight)
            case KeyCode.upArrow:
                return .perform(.maximizeWindow)
            case KeyCode.downArrow:
                return .perform(.restoreOrMinimizeWindow)
            default:
                break
            }
        }

        if configuration.systemLaunchers,
           keyCode == KeyCode.space,
           hasExactly(flags, required: [.maskAlternate]) {
            return .remap(
                keyCode: KeyCode.space,
                flags: replacing(flags, remove: [.maskAlternate], add: [.maskCommand])
            )
        }

        return .passthrough
    }

    private static func shortcutModifiers(in flags: CGEventFlags) -> CGEventFlags {
        flags.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift])
    }

    private static func hasExactly(_ flags: CGEventFlags, required: CGEventFlags) -> Bool {
        shortcutModifiers(in: flags) == required
    }

    private static func replacing(
        _ flags: CGEventFlags,
        remove removedFlags: CGEventFlags,
        add addedFlags: CGEventFlags
    ) -> CGEventFlags {
        var result = flags
        result.remove(removedFlags)
        result.formUnion(addedFlags)
        return result
    }
}
