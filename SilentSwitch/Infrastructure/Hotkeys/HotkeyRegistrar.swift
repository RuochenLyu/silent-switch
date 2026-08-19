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

    private struct Registration {
        let id: UInt32
        let reference: EventHotKeyRef
    }

    private var eventHandler: EventHandlerRef?
    private var registrations: [Shortcut: Registration] = [:]
    private var shortcutsByID: [UInt32: Shortcut] = [:]
    private var handler: ((Shortcut, HotkeyEvent) -> Void)?

    var isRunning: Bool {
        handler != nil
    }

    func start(handler: @escaping (Shortcut, HotkeyEvent) -> Void) -> Bool {
        self.handler = handler
        return true
    }

    func replaceRegistrations(with shortcuts: Set<Shortcut>) -> Set<Shortcut> {
        guard handler != nil else {
            return shortcuts
        }

        for shortcut in Set(registrations.keys).subtracting(shortcuts) {
            unregister(shortcut)
        }

        var failures: Set<Shortcut> = []
        let additions = shortcuts.subtracting(registrations.keys)
        let orderedAdditions = additions.sorted {
            if $0.digit != $1.digit {
                return $0.digit < $1.digit
            }
            return $0.modifier.rawValue < $1.modifier.rawValue
        }

        for shortcut in orderedAdditions {
            guard let keyCode = KeyCodeMap.keyCode(forDigit: shortcut.digit) else {
                failures.insert(shortcut)
                continue
            }

            let id = registrationID(for: shortcut)
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(keyCode),
                shortcut.modifier.carbonFlags,
                EventHotKeyID(signature: Self.signature, id: id),
                GetEventDispatcherTarget(),
                0,
                &reference
            )

            guard status == noErr, let reference else {
                failures.insert(shortcut)
                Log.hotkeys.error(
                    "Failed to register global hotkey \(shortcut.modifier.rawValue, privacy: .public)+\(shortcut.digit, privacy: .public): \(status, privacy: .public)."
                )
                continue
            }

            registrations[shortcut] = Registration(id: id, reference: reference)
            shortcutsByID[id] = shortcut
            Log.hotkeys.debug(
                "Registered Carbon hotkey \(shortcut.modifier.rawValue, privacy: .public)+\(shortcut.digit, privacy: .public), keyCode \(keyCode, privacy: .public), id \(id, privacy: .public)."
            )
        }

        if registrations.isEmpty {
            removeEventHandler()
        } else if !installEventHandlerIfNeeded() {
            failures.formUnion(shortcuts)
        }

        return failures
    }

    func stop() {
        unregisterAll()

        removeEventHandler()
        handler = nil
    }

    private func installEventHandlerIfNeeded() -> Bool {
        guard eventHandler == nil else {
            return true
        }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        var installedHandler: EventHandlerRef?
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            Self.eventHandlerCallback,
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &installedHandler
        )

        guard status == noErr, let installedHandler else {
            Log.hotkeys.error("Failed to install Carbon dispatcher handler: \(status, privacy: .public).")
            return false
        }

        eventHandler = installedHandler
        Log.hotkeys.debug("Installed Carbon dispatcher handler after hotkey registration.")
        return true
    }

    private func removeEventHandler() {
        guard let eventHandler else {
            return
        }

        let status = RemoveEventHandler(eventHandler)
        if status != noErr {
            Log.hotkeys.error("Failed to remove Carbon dispatcher handler: \(status, privacy: .public).")
        }
        self.eventHandler = nil
    }

    private func unregisterAll() {
        for shortcut in Array(registrations.keys) {
            unregister(shortcut)
        }
    }

    private func unregister(_ shortcut: Shortcut) {
        guard let registration = registrations[shortcut] else {
            return
        }

        let status = UnregisterEventHotKey(registration.reference)
        guard status == noErr else {
            Log.hotkeys.error(
                "Failed to unregister global hotkey \(shortcut.modifier.rawValue, privacy: .public)+\(shortcut.digit, privacy: .public): \(status, privacy: .public); will retry on refresh."
            )
            return
        }

        registrations.removeValue(forKey: shortcut)
        shortcutsByID.removeValue(forKey: registration.id)
    }

    private func registrationID(for shortcut: Shortcut) -> UInt32 {
        let modifierOffset: UInt32 = switch shortcut.modifier {
        case .option: 0
        case .command: 10
        case .control: 20
        }

        return modifierOffset + UInt32(shortcut.digit)
    }

    private func handle(signature: OSType, id: UInt32, eventKind: UInt32) -> OSStatus {
        guard signature == Self.signature else {
            Log.hotkeys.error("Carbon callback received unexpected signature \(signature, privacy: .public), id \(id, privacy: .public).")
            return OSStatus(eventNotHandledErr)
        }
        guard let shortcut = shortcutsByID[id] else {
            Log.hotkeys.error("Carbon callback received unknown hotkey id \(id, privacy: .public).")
            return OSStatus(eventNotHandledErr)
        }

        Log.hotkeys.debug(
            "Carbon callback received \(shortcut.modifier.rawValue, privacy: .public)+\(shortcut.digit, privacy: .public), event kind \(eventKind, privacy: .public)."
        )

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
            Log.hotkeys.error("Carbon dispatcher callback was missing event or context.")
            return OSStatus(eventNotHandledErr)
        }

        guard GetEventClass(event) == OSType(kEventClassKeyboard) else {
            Log.hotkeys.error("Carbon dispatcher callback received non-keyboard event.")
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
            Log.hotkeys.error("Carbon callback could not decode hotkey ID: \(status, privacy: .public).")
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
