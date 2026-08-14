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
    private let activate: (AppTarget) -> Void
    private let registrar: any HotkeyRegistering
    private let stateDidChange: (HotkeyMonitorState) -> Void

    init(
        activate: @escaping (AppTarget) -> Void,
        registrar: any HotkeyRegistering = SystemHotkeyRegistrar(),
        stateDidChange: @escaping (HotkeyMonitorState) -> Void = { _ in }
    ) {
        self.activate = activate
        self.registrar = registrar
        self.stateDidChange = stateDidChange
    }

    func updateSnapshot(_ snapshot: HotkeySnapshot) {
        self.snapshot = snapshot
        pressedShortcuts.removeAll()

        if registrar.isRunning {
            registerCurrentSnapshot()
        }
    }

    func start() {
        publish(.starting)

        if !registrar.isRunning {
            guard registrar.start(handler: { [weak self] shortcut, event in
                self?.handle(shortcut: shortcut, event: event)
            }) else {
                Log.hotkeys.error("Failed to start global hotkey handler.")
                publish(.failed)
                return
            }
        }

        pressedShortcuts.removeAll()
        registerCurrentSnapshot()
    }

    func stop() {
        registrar.stop()
        pressedShortcuts.removeAll()
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
            pressedShortcuts.remove(shortcut)
        case .pressed:
            guard pressedShortcuts.insert(shortcut).inserted,
                  let target = snapshot.routes[shortcut] else {
                return
            }

            Log.hotkeys.info("Hotkey matched \(target.bundleIdentifier, privacy: .public).")
            activate(target)
        }
    }

    private func publish(_ state: HotkeyMonitorState) {
        stateDidChange(state)
    }
}
