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

final class HotkeyRuntimeControllerTests: XCTestCase {
    func testKeepsHealthyTapInsteadOfCreatingAnotherOne() {
        let factory = FakeHotkeyEventTapFactory(tokens: [FakeHotkeyEventTap()])
        let states = HotkeyStateRecorder()
        let service = makeService(factory: factory, states: states)

        service.startIfPermitted()
        service.startIfPermitted()

        XCTAssertEqual(factory.makeTapCallCount, 1)
        XCTAssertEqual(states.values.last, .running)
    }

    func testRecreatesDisabledTapDuringHealthRefresh() {
        let firstTap = FakeHotkeyEventTap()
        let replacementTap = FakeHotkeyEventTap()
        let factory = FakeHotkeyEventTapFactory(tokens: [firstTap, replacementTap])
        let service = makeService(factory: factory)

        service.startIfPermitted()
        firstTap.isEnabled = false
        service.startIfPermitted()

        XCTAssertEqual(factory.makeTapCallCount, 2)
        XCTAssertEqual(firstTap.invalidateCallCount, 1)
        XCTAssertTrue(replacementTap.isEnabled)
    }

    func testPublishesFailureWhenTapCannotBeCreated() {
        let states = HotkeyStateRecorder()
        let factory = FakeHotkeyEventTapFactory(tokens: [])
        let service = makeService(factory: factory, states: states)

        service.startIfPermitted()

        XCTAssertEqual(states.values, [.starting, .failed])
    }

    func testPermissionDenialStopsExistingTap() {
        let permission = PermissionRecorder(value: true)
        let tap = FakeHotkeyEventTap()
        let factory = FakeHotkeyEventTapFactory(tokens: [tap])
        let states = HotkeyStateRecorder()
        let service = HotkeyRuntimeController(
            activate: { _ in },
            permissionCheck: { permission.value },
            tapFactory: factory,
            stateDidChange: states.record
        )

        service.startIfPermitted()
        permission.value = false
        service.startIfPermitted()

        XCTAssertEqual(tap.invalidateCallCount, 1)
        XCTAssertEqual(states.values.last, .permissionRequired)
    }

    private func makeService(
        factory: FakeHotkeyEventTapFactory,
        states: HotkeyStateRecorder = HotkeyStateRecorder()
    ) -> HotkeyRuntimeController {
        HotkeyRuntimeController(
            activate: { _ in },
            permissionCheck: { true },
            tapFactory: factory,
            stateDidChange: states.record
        )
    }
}

private final class FakeHotkeyEventTap: HotkeyEventTap {
    var isValid = true
    var isEnabled = false
    private(set) var invalidateCallCount = 0

    func enable() {
        isEnabled = true
    }

    func invalidate() {
        invalidateCallCount += 1
        isValid = false
        isEnabled = false
    }
}

private final class FakeHotkeyEventTapFactory: HotkeyEventTapCreating {
    private var tokens: [FakeHotkeyEventTap]
    private(set) var makeTapCallCount = 0

    init(tokens: [FakeHotkeyEventTap]) {
        self.tokens = tokens
    }

    func makeTap(
        callback: CGEventTapCallBack,
        userInfo: UnsafeMutableRawPointer
    ) -> (any HotkeyEventTap)? {
        makeTapCallCount += 1
        guard !tokens.isEmpty else {
            return nil
        }
        return tokens.removeFirst()
    }
}

private final class HotkeyStateRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedValues: [HotkeyMonitorState] = []

    var values: [HotkeyMonitorState] {
        lock.withLock { recordedValues }
    }

    func record(_ state: HotkeyMonitorState) {
        lock.withLock {
            recordedValues.append(state)
        }
    }
}

private final class PermissionRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Bool

    init(value: Bool) {
        self.storedValue = value
    }

    var value: Bool {
        get { lock.withLock { storedValue } }
        set { lock.withLock { storedValue = newValue } }
    }
}
