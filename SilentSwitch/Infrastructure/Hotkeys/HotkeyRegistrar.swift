import Carbon.HIToolbox
import Foundation

enum HotkeyEvent: Equatable {
    case pressed
    case released
}

@MainActor
protocol HotkeyRegistering: AnyObject {
    var isRunning: Bool { get }

    func start(handler: @escaping (Shortcut, HotkeyEvent) -> Void) -> Bool
    func replaceRegistrations(with shortcuts: Set<Shortcut>) -> Set<Shortcut>
    func stop()
}

@MainActor
final class SystemHotkeyRegistrar: HotkeyRegistering {
    private static let signature: OSType = 0x536C5377 // "SlSw"

    private var eventHandler: EventHandlerRef?
    private var hotKeyReferences: [EventHotKeyRef] = []
    private var shortcutsByID: [UInt32: Shortcut] = [:]
    private var handler: ((Shortcut, HotkeyEvent) -> Void)?

    var isRunning: Bool {
        eventHandler != nil
    }

    func start(handler: @escaping (Shortcut, HotkeyEvent) -> Void) -> Bool {
        self.handler = handler

        guard eventHandler == nil else {
            return true
        }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        var installedHandler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandlerCallback,
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &installedHandler
        )

        guard status == noErr, let installedHandler else {
            Log.hotkeys.error("Failed to install global hotkey handler: \(status, privacy: .public).")
            self.handler = nil
            return false
        }

        eventHandler = installedHandler
        return true
    }

    func replaceRegistrations(with shortcuts: Set<Shortcut>) -> Set<Shortcut> {
        unregisterAll()

        guard eventHandler != nil else {
            return shortcuts
        }

        var failures: Set<Shortcut> = []
        let orderedShortcuts = shortcuts.sorted {
            if $0.digit != $1.digit {
                return $0.digit < $1.digit
            }
            return $0.modifier.rawValue < $1.modifier.rawValue
        }

        for (offset, shortcut) in orderedShortcuts.enumerated() {
            guard let keyCode = KeyCodeMap.keyCode(forDigit: shortcut.digit) else {
                failures.insert(shortcut)
                continue
            }

            let id = UInt32(offset + 1)
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(keyCode),
                shortcut.modifier.carbonFlags,
                EventHotKeyID(signature: Self.signature, id: id),
                GetApplicationEventTarget(),
                0,
                &reference
            )

            guard status == noErr, let reference else {
                failures.insert(shortcut)
                Log.hotkeys.error(
                    "Failed to register global hotkey digit \(shortcut.digit, privacy: .public): \(status, privacy: .public)."
                )
                continue
            }

            hotKeyReferences.append(reference)
            shortcutsByID[id] = shortcut
        }

        return failures
    }

    func stop() {
        unregisterAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        handler = nil
    }

    private func unregisterAll() {
        for reference in hotKeyReferences {
            let status = UnregisterEventHotKey(reference)
            if status != noErr {
                Log.hotkeys.error("Failed to unregister global hotkey: \(status, privacy: .public).")
            }
        }

        hotKeyReferences.removeAll()
        shortcutsByID.removeAll()
    }

    private func handle(signature: OSType, id: UInt32, eventKind: UInt32) -> OSStatus {
        guard signature == Self.signature,
              let shortcut = shortcutsByID[id] else {
            return OSStatus(eventNotHandledErr)
        }

        switch eventKind {
        case UInt32(kEventHotKeyPressed):
            handler?(shortcut, .pressed)
        case UInt32(kEventHotKeyReleased):
            handler?(shortcut, .released)
        default:
            return OSStatus(eventNotHandledErr)
        }

        return noErr
    }

    private static let eventHandlerCallback: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else {
            return OSStatus(eventNotHandledErr)
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else {
            return status
        }
        let signature = hotKeyID.signature
        let id = hotKeyID.id
        let eventKind = GetEventKind(event)

        let registrar = Unmanaged<SystemHotkeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
        return MainActor.assumeIsolated {
            registrar.handle(signature: signature, id: id, eventKind: eventKind)
        }
    }
}

private extension ShortcutModifier {
    var carbonFlags: UInt32 {
        switch self {
        case .option:
            UInt32(optionKey)
        case .command:
            UInt32(cmdKey)
        case .control:
            UInt32(controlKey)
        }
    }
}
