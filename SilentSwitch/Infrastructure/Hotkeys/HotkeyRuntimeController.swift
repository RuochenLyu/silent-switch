import Foundation

enum HotkeyMonitorState: Equatable, Sendable {
    case stopped
    case starting
    case running
    case failed
}

@MainActor
final class HotkeyRuntimeController {
    private var snapshot = HotkeySnapshot.empty
    private var pressedShortcuts: Set<Shortcut> = []
    private var releaseWatchdogs: [Shortcut: Task<Void, Never>] = [:]
    private let activate: (AppTarget) -> Void
    private let registrar: any HotkeyRegistering
    private let stateDidChange: (HotkeyMonitorState) -> Void
    private let stuckKeyTimeout: Duration

    init(
        activate: @escaping (AppTarget) -> Void,
        registrar: any HotkeyRegistering = SystemHotkeyRegistrar(),
        stateDidChange: @escaping (HotkeyMonitorState) -> Void = { _ in },
        stuckKeyTimeout: Duration = .seconds(1)
    ) {
        self.activate = activate
        self.registrar = registrar
        self.stateDidChange = stateDidChange
        self.stuckKeyTimeout = stuckKeyTimeout
    }

    func updateSnapshot(_ snapshot: HotkeySnapshot) {
        self.snapshot = snapshot
        resetPressedShortcuts()

        if registrar.isRunning {
            registerCurrentSnapshot()
        }
    }

    func start() {
        publish(.starting)

        guard registrar.start(handler: { [weak self] shortcut, event in
            self?.handle(shortcut: shortcut, event: event)
        }) else {
            Log.hotkeys.error("Failed to start global hotkey handler.")
            publish(.failed)
            return
        }

        resetPressedShortcuts()
        registerCurrentSnapshot()
    }

    func stop() {
        registrar.stop()
        resetPressedShortcuts()
        publish(.stopped)
    }

    private func registerCurrentSnapshot() {
        let failures = registrar.replaceRegistrations(with: Set(snapshot.routes.keys))

        if failures.isEmpty {
            publish(.running)
            Log.hotkeys.info("Global hotkeys registered: \(self.snapshot.routes.count, privacy: .public).")
        } else {
            publish(.failed)
            Log.hotkeys.error("Some global hotkeys could not be registered: \(failures.count, privacy: .public).")
        }
    }

    private func handle(shortcut: Shortcut, event: HotkeyEvent) {
        switch event {
        case .released:
            clearPressedShortcut(shortcut)
        case .pressed:
            guard pressedShortcuts.insert(shortcut).inserted,
                  let target = snapshot.routes[shortcut] else {
                return
            }

            releaseWatchdogs[shortcut]?.cancel()
            releaseWatchdogs[shortcut] = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: self?.stuckKeyTimeout ?? .seconds(1))
                } catch {
                    return
                }

                self?.clearPressedShortcut(shortcut)
            }

            Log.hotkeys.info("Hotkey matched \(target.bundleIdentifier, privacy: .public).")
            activate(target)
        }
    }

    private func clearPressedShortcut(_ shortcut: Shortcut) {
        pressedShortcuts.remove(shortcut)
        releaseWatchdogs.removeValue(forKey: shortcut)?.cancel()
    }

    private func resetPressedShortcuts() {
        pressedShortcuts.removeAll()
        releaseWatchdogs.values.forEach { $0.cancel() }
        releaseWatchdogs.removeAll()
    }

    private func publish(_ state: HotkeyMonitorState) {
        stateDidChange(state)
    }
}
