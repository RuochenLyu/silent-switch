import ApplicationServices
import Foundation

final class EventTapHotkeyService: @unchecked Sendable {
    private let snapshotLock = NSLock()
    private var snapshot = HotkeySnapshot.empty
    private let activate: @Sendable (AppTarget) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(activate: @escaping @Sendable (AppTarget) -> Void) {
        self.activate = activate
    }

    func updateSnapshot(_ snapshot: HotkeySnapshot) {
        snapshotLock.lock()
        self.snapshot = snapshot
        snapshotLock.unlock()
    }

    func startIfPermitted() {
        guard AXIsProcessTrusted() else {
            stop()
            Log.hotkeys.info("Accessibility permission is not granted; event tap not started.")
            return
        }

        guard eventTap == nil else {
            return
        }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: EventTapHotkeyService.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.hotkeys.error("Failed to create event tap.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        Log.hotkeys.info("Event tap started.")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard AXIsProcessTrusted() else {
            DispatchQueue.main.async { [weak self] in
                self?.stop()
            }
            Log.hotkeys.info("Accessibility permission is no longer granted; event tap stopped.")
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .tapDisabledByTimeout:
            reenableOrRestartTap(reason: "timeout")
            return Unmanaged.passUnretained(event)
        case .tapDisabledByUserInput:
            reenableOrRestartTap(reason: "user input")
            return Unmanaged.passUnretained(event)
        case .keyDown:
            break
        default:
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        guard let target = currentTarget(forKeyCode: keyCode, flags: flags) else {
            return Unmanaged.passUnretained(event)
        }

        let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if !isAutorepeat {
            activate(target)
        }

        return nil
    }

    private func currentTarget(forKeyCode keyCode: CGKeyCode, flags: CGEventFlags) -> AppTarget? {
        snapshotLock.lock()
        let currentSnapshot = snapshot
        snapshotLock.unlock()

        return ShortcutMatcher.target(forKeyCode: keyCode, flags: flags, snapshot: currentSnapshot)
    }

    private func reenableOrRestartTap(reason: String) {
        if let eventTap, CFMachPortIsValid(eventTap) {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            Log.hotkeys.info("Event tap re-enabled after \(reason, privacy: .public).")
            return
        }

        stop()
        startIfPermitted()
        Log.hotkeys.info("Event tap restarted after \(reason, privacy: .public).")
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let service = Unmanaged<EventTapHotkeyService>.fromOpaque(userInfo).takeUnretainedValue()
        return service.handle(type: type, event: event)
    }
}
