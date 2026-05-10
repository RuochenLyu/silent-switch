import CoreGraphics
import XCTest

final class ShortcutMatcherTests: XCTestCase {
    func testMatchesOptionCommandAndControlDigits() throws {
        for modifier in ShortcutModifier.allCases {
            let flags = flags(for: modifier)
            let keyCode = try XCTUnwrap(KeyCodeMap.keyCode(forDigit: 1))

            XCTAssertEqual(
                ShortcutMatcher.shortcut(forKeyCode: keyCode, flags: flags),
                Shortcut(modifier: modifier, digit: 1)
            )
        }
    }

    func testDoesNotMatchShiftOptionDigit() throws {
        let keyCode = try XCTUnwrap(KeyCodeMap.keyCode(forDigit: 1))
        let shortcut = ShortcutMatcher.shortcut(
            forKeyCode: keyCode,
            flags: [.maskAlternate, .maskShift]
        )

        XCTAssertNil(shortcut)
    }

    func testDoesNotMatchOptionWithFnDigit() throws {
        let keyCode = try XCTUnwrap(KeyCodeMap.keyCode(forDigit: 1))
        let shortcut = ShortcutMatcher.shortcut(
            forKeyCode: keyCode,
            flags: [.maskAlternate, .maskSecondaryFn]
        )

        XCTAssertNil(shortcut)
    }

    func testDoesNotMatchMultipleTargetModifiers() throws {
        let keyCode = try XCTUnwrap(KeyCodeMap.keyCode(forDigit: 1))
        let shortcut = ShortcutMatcher.shortcut(
            forKeyCode: keyCode,
            flags: [.maskAlternate, .maskCommand]
        )

        XCTAssertNil(shortcut)
    }

    func testIgnoresCapsLock() throws {
        let keyCode = try XCTUnwrap(KeyCodeMap.keyCode(forDigit: 2))
        let shortcut = ShortcutMatcher.shortcut(
            forKeyCode: keyCode,
            flags: [.maskAlternate, .maskAlphaShift]
        )

        XCTAssertEqual(shortcut, Shortcut(modifier: .option, digit: 2))
    }

    func testIgnoresNonCoalescedFlag() throws {
        let keyCode = try XCTUnwrap(KeyCodeMap.keyCode(forDigit: 1))
        let shortcut = ShortcutMatcher.shortcut(
            forKeyCode: keyCode,
            flags: [.maskAlternate, .maskNonCoalesced]
        )

        XCTAssertEqual(shortcut, Shortcut(modifier: .option, digit: 1))
    }

    func testNumpadDigitsDoNotMatch() {
        let shortcut = ShortcutMatcher.shortcut(
            forKeyCode: CGKeyCode(83),
            flags: [.maskAlternate]
        )

        XCTAssertNil(shortcut)
    }

    func testSnapshotReturnsConfiguredTarget() throws {
        let target = AppTarget(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            path: nil
        )
        let shortcut = Shortcut(modifier: .command, digit: 3)
        let keyCode = try XCTUnwrap(KeyCodeMap.keyCode(forDigit: 3))
        let snapshot = HotkeySnapshot(routes: [shortcut: target])

        XCTAssertEqual(
            ShortcutMatcher.target(forKeyCode: keyCode, flags: [.maskCommand], snapshot: snapshot),
            target
        )
    }

    private func flags(for modifier: ShortcutModifier) -> CGEventFlags {
        switch modifier {
        case .option:
            .maskAlternate
        case .command:
            .maskCommand
        case .control:
            .maskControl
        }
    }
}
