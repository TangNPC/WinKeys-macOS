import CoreGraphics
import XCTest
@testable import WinKeys

final class ShortcutTranslatorTests: XCTestCase {
    func testControlCBecomesCommandC() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.c,
            flags: [.maskControl],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .remap(keyCode: KeyCode.c, flags: [.maskCommand]))
    }

    func testTerminalPreservesControlShortcut() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.c,
            flags: [.maskControl],
            behavior: .preserveControl,
            frontmostBundleIdentifier: "com.apple.Terminal",
            configuration: .default
        )

        XCTAssertEqual(decision, .passthrough)
    }

    func testTerminalControlShiftVPastesText() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.v,
            flags: [.maskControl, .maskShift],
            behavior: .preserveControl,
            frontmostBundleIdentifier: "com.apple.Terminal",
            configuration: .default
        )

        XCTAssertEqual(decision, .remap(keyCode: KeyCode.v, flags: [.maskCommand]))
    }

    func testTerminalControlShiftCCopiesText() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.c,
            flags: [.maskControl, .maskShift],
            behavior: .preserveControl,
            frontmostBundleIdentifier: "com.apple.Terminal",
            configuration: .default
        )

        XCTAssertEqual(decision, .remap(keyCode: KeyCode.c, flags: [.maskCommand]))
    }

    func testTerminalControlVRemainsAvailableForCodexImagePaste() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.v,
            flags: [.maskControl],
            behavior: .preserveControl,
            frontmostBundleIdentifier: "com.apple.Terminal",
            configuration: .default
        )

        XCTAssertEqual(decision, .passthrough)
    }

    func testTerminalStillTranslatesAltTab() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.tab,
            flags: [.maskAlternate],
            behavior: .preserveControl,
            frontmostBundleIdentifier: "com.apple.Terminal",
            configuration: .default
        )

        XCTAssertEqual(decision, .remap(keyCode: KeyCode.tab, flags: [.maskCommand]))
    }

    func testAltF4QuitsTheCurrentApplication() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.f4,
            flags: [.maskAlternate],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.quitApplication))
    }

    func testBypassDoesNotTranslateAnything() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.tab,
            flags: [.maskAlternate],
            behavior: .bypass,
            frontmostBundleIdentifier: "com.microsoft.rdc.macos",
            configuration: .default
        )

        XCTAssertEqual(decision, .passthrough)
    }

    func testHomeMovesToStartOfLine() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.home,
            flags: [],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .remap(keyCode: KeyCode.leftArrow, flags: [.maskCommand]))
    }

    func testControlHomeMovesToStartOfDocument() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.home,
            flags: [.maskControl, .maskShift],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(
            decision,
            .remap(keyCode: KeyCode.upArrow, flags: [.maskCommand, .maskShift])
        )
    }

    func testFinderF2BecomesRename() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.f2,
            flags: [],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.finder",
            configuration: .default
        )

        XCTAssertEqual(decision, .remap(keyCode: 36, flags: []))
    }

    func testControlShiftEscapeOpensActivityMonitor() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.escape,
            flags: [.maskControl, .maskShift],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.openActivityMonitor))
    }

    func testWinDShowsDesktop() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.d,
            flags: [.maskCommand],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.showDesktop))
    }

    func testAltSpaceOpensSpotlight() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.space,
            flags: [.maskAlternate],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .remap(keyCode: KeyCode.space, flags: [.maskCommand]))
    }

    func testControlSpaceRemainsInputSourceShortcut() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.space,
            flags: [.maskControl],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .passthrough)
    }

    func testWinLeftTilesWindow() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.leftArrow,
            flags: [.maskCommand],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.tileWindowLeft))
    }

    func testWinUpMaximizesWindow() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.upArrow,
            flags: [.maskCommand],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.maximizeWindow))
    }

    func testWinLLocksScreen() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.l,
            flags: [.maskCommand],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.lockScreen))
    }

    func testWinShiftSStartsRegionCapture() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.s,
            flags: [.maskCommand, .maskShift],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.captureRegion))
    }

    func testWinTabShowsMissionControl() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.tab,
            flags: [.maskCommand],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.showMissionControl))
    }

    func testWinVShowsClipboardHistory() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.v,
            flags: [.maskCommand],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.showClipboardHistory))
    }

    func testWinVPassesThroughWhenClipboardHistoryIsDisabled() {
        var configuration = ShortcutConfiguration.default
        configuration.clipboardHistory = false
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.v,
            flags: [.maskCommand],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: configuration
        )

        XCTAssertEqual(decision, .passthrough)
    }

    func testControlAltDeleteShowsForceQuit() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.forwardDelete,
            flags: [.maskControl, .maskAlternate],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.showForceQuit))
    }

    func testF5RefreshesStandardApplications() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.f5,
            flags: [],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.Safari",
            configuration: .default
        )

        XCTAssertEqual(decision, .remap(keyCode: KeyCode.r, flags: [.maskCommand]))
    }

    func testAltLeftNavigatesBack() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.leftArrow,
            flags: [.maskAlternate],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.Safari",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.navigateBack))
    }

    func testAltRightNavigatesForward() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.rightArrow,
            flags: [.maskAlternate, .maskNumericPad],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.Safari",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.navigateForward))
    }

    func testFinderAltEnterShowsInfo() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.returnKey,
            flags: [.maskAlternate],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.finder",
            configuration: .default
        )

        XCTAssertEqual(decision, .remap(keyCode: KeyCode.i, flags: [.maskCommand]))
    }

    func testWinIOpensSystemSettings() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.i,
            flags: [.maskCommand],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.openSystemSettings))
    }

    func testWinPeriodShowsEmojiPicker() {
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.period,
            flags: [.maskCommand],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: .default
        )

        XCTAssertEqual(decision, .perform(.showEmojiPicker))
    }

    func testWinVWorksIndependentlyOfSystemLauncherToggle() {
        var configuration = ShortcutConfiguration.default
        configuration.systemLaunchers = false
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.v,
            flags: [.maskCommand],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: configuration
        )

        XCTAssertEqual(decision, .perform(.showClipboardHistory))
    }

    func testWinLeftPassesThroughWhenWindowManagementIsDisabled() {
        var configuration = ShortcutConfiguration.default
        configuration.windowManagement = false
        let decision = ShortcutTranslator.decision(
            keyCode: KeyCode.leftArrow,
            flags: [.maskCommand],
            behavior: .standard,
            frontmostBundleIdentifier: "com.apple.TextEdit",
            configuration: configuration
        )

        XCTAssertEqual(decision, .passthrough)
    }
}
