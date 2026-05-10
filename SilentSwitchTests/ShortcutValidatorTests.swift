import Foundation
import XCTest

final class ShortcutValidatorTests: XCTestCase {
    func testDuplicateShortcutValidationMarksBothSlots() {
        let shortcut = Shortcut(modifier: .option, digit: 1)
        let slots = [
            Slot(id: UUID(), enabled: true, shortcut: shortcut, target: sampleTarget),
            Slot(id: UUID(), enabled: true, shortcut: shortcut, target: sampleTarget)
        ]

        XCTAssertEqual(ShortcutValidator.duplicateSlotIDs(in: slots), Set(slots.map(\.id)))
    }

    func testDisabledDuplicateDoesNotInvalidateEnabledSlot() {
        let shortcut = Shortcut(modifier: .option, digit: 1)
        let enabled = Slot(id: UUID(), enabled: true, shortcut: shortcut, target: sampleTarget)
        let disabled = Slot(id: UUID(), enabled: false, shortcut: shortcut, target: sampleTarget)

        XCTAssertTrue(ShortcutValidator.duplicateSlotIDs(in: [enabled, disabled]).isEmpty)
    }

    func testEmptyTargetSlotIsNotAddedToRoutes() {
        let slot = Slot(
            id: UUID(),
            enabled: true,
            shortcut: Shortcut(modifier: .option, digit: 1),
            target: nil
        )

        XCTAssertTrue(ShortcutValidator.routes(from: [slot]).isEmpty)
    }

    func testEmptyTargetDuplicateDoesNotInvalidateConfiguredSlot() {
        let shortcut = Shortcut(modifier: .option, digit: 1)
        let configured = Slot(id: UUID(), enabled: true, shortcut: shortcut, target: sampleTarget)
        let empty = Slot(id: UUID(), enabled: true, shortcut: shortcut, target: nil)

        XCTAssertTrue(ShortcutValidator.duplicateSlotIDs(in: [configured, empty]).isEmpty)
        XCTAssertEqual(ShortcutValidator.routes(from: [configured, empty]), [shortcut: sampleTarget])
    }

    func testInvalidDuplicateSlotsAreNotAddedToRoutes() {
        let shortcut = Shortcut(modifier: .option, digit: 1)
        let slots = [
            Slot(id: UUID(), enabled: true, shortcut: shortcut, target: sampleTarget),
            Slot(id: UUID(), enabled: true, shortcut: shortcut, target: sampleTarget)
        ]

        XCTAssertTrue(ShortcutValidator.routes(from: slots).isEmpty)
    }

    private var sampleTarget: AppTarget {
        AppTarget(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            path: "/System/Applications/TextEdit.app"
        )
    }
}
