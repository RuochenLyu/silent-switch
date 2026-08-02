import ApplicationServices
import Foundation

enum HotkeyMonitorState: Equatable, Sendable {
    case stopped
    case permissionRequired
    case starting
    case running
    case failed
}

final class HotkeyRuntimeController: @unchecked Sendable {
    private let snapshotLock = NSLock()
    private var snapshot = HotkeySnapshot.empty
    private let activate: @Sendable (AppTarget) -> Void
    private let permissionCheck: @Sendable () -> Bool
    private let tapFactory: any HotkeyEventTapCreating
    private let stateDidChange: @Sendable (HotkeyMonitorState) -> Void

    private var eventTap: (any HotkeyEventTap)?

    init(
        activate: @escaping @Sendable (AppTarget) -> Void,
        permissionCheck: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() },
        tapFactory: any HotkeyEventTapCreating = SystemHotkeyEventTapFactory(),
        stateDidChange: @escaping @Sendable (HotkeyMonitorState) -> Void = { _ in }
    ) {
        self.activate = activate
        self.permissionCheck = permissionCheck
        self.tapFactory = tapFactory
        self.stateDidChange = stateDidChange
    }

    func updateSnapshot(_ snapshot: HotkeySnapshot) {
        snapshotLock.lock()
        self.snapshot = snapshot
        snapshotLock.unlock()
    }

    func startIfPermitted() {
        guard permissionCheck() else {
            stop(publishing: .permissionRequired)
            Log.hotkeys.info("Accessibility permission is not granted; event tap not started.")
            return
        }

        if let eventTap, eventTap.isValid, eventTap.isEnabled {
            publish(.running)
            return
        }

        if eventTap != nil {
            Log.hotkeys.info("Event tap was unhealthy and will be recreated.")
            stop(publishing: nil)
        }

        publish(.starting)
        guard let tap = tapFactory.makeTap(
            callback: HotkeyRuntimeController.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.hotkeys.error("Failed to create event tap.")
            publish(.failed)
            return
        }

        eventTap = tap
        tap.enable()

        guard tap.isValid, tap.isEnabled else {
            Log.hotkeys.error("Event tap could not be enabled.")
            stop(publishing: .failed)
            return
        }

        publish(.running)
        Log.hotkeys.info("Event tap started.")
    }

    func stop() {
        stop(publishing: .stopped)
    }

    private func stop(publishing state: HotkeyMonitorState?) {
        eventTap?.invalidate()
        eventTap = nil

        if let state {
            publish(state)
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard permissionCheck() else {
            DispatchQueue.main.async { [weak self] in
                self?.stop(publishing: .permissionRequired)
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
            Log.hotkeys.info("Hotkey matched \(target.bundleIdentifier, privacy: .public).")
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
        if let eventTap, eventTap.isValid {
            eventTap.enable()
            if eventTap.isEnabled {
                publish(.running)
                Log.hotkeys.info("Event tap re-enabled after \(reason, privacy: .public).")
                return
            }
        }

        stop(publishing: nil)
        startIfPermitted()
        Log.hotkeys.info("Event tap restarted after \(reason, privacy: .public).")
    }

    private func publish(_ state: HotkeyMonitorState) {
        stateDidChange(state)
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let service = Unmanaged<HotkeyRuntimeController>.fromOpaque(userInfo).takeUnretainedValue()
        return service.handle(type: type, event: event)
    }
}
