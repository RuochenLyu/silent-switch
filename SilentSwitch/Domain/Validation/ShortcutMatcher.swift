import CoreGraphics
import Foundation

enum ShortcutMatcher {
    static func shortcut(forKeyCode keyCode: CGKeyCode, flags: CGEventFlags) -> Shortcut? {
        guard let digit = KeyCodeMap.digit(forKeyCode: keyCode) else {
            return nil
        }

        let normalizedFlags = flags.intersection([
            .maskShift,
            .maskControl,
            .maskAlternate,
            .maskCommand,
            .maskSecondaryFn
        ])

        if normalizedFlags == .maskAlternate {
            return Shortcut(modifier: .option, digit: digit)
        }

        if normalizedFlags == .maskCommand {
            return Shortcut(modifier: .command, digit: digit)
        }

        if normalizedFlags == .maskControl {
            return Shortcut(modifier: .control, digit: digit)
        }

        return nil
    }

    static func target(
        forKeyCode keyCode: CGKeyCode,
        flags: CGEventFlags,
        snapshot: HotkeySnapshot
    ) -> AppTarget? {
        guard let shortcut = shortcut(forKeyCode: keyCode, flags: flags) else {
            return nil
        }

        return snapshot.routes[shortcut]
    }
}
