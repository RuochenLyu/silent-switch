import XCTest

@MainActor
final class HotkeyRuntimeControllerTests: XCTestCase {
    private let shortcut = Shortcut(modifier: .option, digit: 1)
    private let target = AppTarget(
        bundleIdentifier: "com.apple.TextEdit",
        displayName: "TextEdit",
        path: nil
    )

    func testRefreshKeepsHandlerAndReconcilesRegistrations() {
        let registrar = FakeHotkeyRegistrar()
        let states = HotkeyStateRecorder()
        let service = makeService(registrar: registrar, states: states)
        service.updateSnapshot(HotkeySnapshot(routes: [shortcut: target]))

        service.start()
        service.start()

        XCTAssertEqual(registrar.startCallCount, 2)
        XCTAssertEqual(registrar.stopCallCount, 0)
        XCTAssertEqual(registrar.registrationHistory, [[shortcut], [shortcut]])
        XCTAssertEqual(states.values.last, .running)
    }

    func testSnapshotChangeReplacesRegistrationsWhileRunning() {
        let registrar = FakeHotkeyRegistrar()
        let service = makeService(registrar: registrar)
        let nextShortcut = Shortcut(modifier: .command, digit: 2)

        service.updateSnapshot(HotkeySnapshot(routes: [shortcut: target]))
        service.start()
        service.updateSnapshot(HotkeySnapshot(routes: [nextShortcut: target]))

        XCTAssertEqual(registrar.registrationHistory, [[shortcut], [nextShortcut]])
    }

    func testPublishesFailureWhenHandlerCannotStart() {
        let states = HotkeyStateRecorder()
        let registrar = FakeHotkeyRegistrar(canStart: false)
        let service = makeService(registrar: registrar, states: states)

        service.start()

        XCTAssertEqual(states.values, [.starting, .failed])
    }

    func testPublishesFailureWhenARegistrationFails() {
        let registrar = FakeHotkeyRegistrar(failures: [shortcut])
        let states = HotkeyStateRecorder()
        let service = makeService(registrar: registrar, states: states)
        service.updateSnapshot(HotkeySnapshot(routes: [shortcut: target]))

        service.start()

        XCTAssertEqual(states.values.last, .failed)
    }

    func testActivatesOnceUntilHotkeyIsReleased() {
        let registrar = FakeHotkeyRegistrar()
        var activatedTargets: [AppTarget] = []
        let service = HotkeyRuntimeController(
            activate: { activatedTargets.append($0) },
            registrar: registrar
        )
        service.updateSnapshot(HotkeySnapshot(routes: [shortcut: target]))
        service.start()

        registrar.send(shortcut, .pressed)
        registrar.send(shortcut, .pressed)
        registrar.send(shortcut, .released)
        registrar.send(shortcut, .pressed)

        XCTAssertEqual(activatedTargets, [target, target])
    }

    func testMissingReleaseDoesNotPermanentlyBlockShortcut() async {
        let registrar = FakeHotkeyRegistrar()
        var activatedTargets: [AppTarget] = []
        let service = HotkeyRuntimeController(
            activate: { activatedTargets.append($0) },
            registrar: registrar,
            stuckKeyTimeout: .zero
        )
        service.updateSnapshot(HotkeySnapshot(routes: [shortcut: target]))
        service.start()

        registrar.send(shortcut, .pressed)
        registrar.send(shortcut, .pressed)
        for _ in 0..<100 {
            await Task.yield()
        }
        registrar.send(shortcut, .pressed)

        XCTAssertEqual(activatedTargets, [target, target])
    }

    func testSystemRegistrarCanInstallAndRegisterAHotkey() {
        let registrar = SystemHotkeyRegistrar()
        let integrationShortcut = Shortcut(modifier: .control, digit: 9)

        XCTAssertTrue(registrar.start { _, _ in })
        XCTAssertTrue(registrar.replaceRegistrations(with: [integrationShortcut]).isEmpty)
        XCTAssertTrue(registrar.replaceRegistrations(with: [integrationShortcut]).isEmpty)

        registrar.stop()
        XCTAssertFalse(registrar.isRunning)
    }

    func testSecondCarbonRegistrarInSameProcessDetectsDuplicateShortcut() {
        let first = SystemHotkeyRegistrar()
        let second = SystemHotkeyRegistrar()
        let integrationShortcut = Shortcut(modifier: .control, digit: 8)

        XCTAssertTrue(first.start { _, _ in })
        XCTAssertTrue(second.start { _, _ in })
        XCTAssertTrue(first.replaceRegistrations(with: [integrationShortcut]).isEmpty)
        XCTAssertEqual(second.replaceRegistrations(with: [integrationShortcut]), [integrationShortcut])

        first.stop()
        second.stop()
    }

    func testCarbonRegistrarSurvivesRepeatedStartStopCycles() {
        let registrar = SystemHotkeyRegistrar()
        let integrationShortcut = Shortcut(modifier: .control, digit: 7)

        for _ in 0..<20 {
            XCTAssertTrue(registrar.start { _, _ in })
            XCTAssertTrue(registrar.replaceRegistrations(with: [integrationShortcut]).isEmpty)
            registrar.stop()
        }

        XCTAssertFalse(registrar.isRunning)
    }

    private func makeService(
        registrar: FakeHotkeyRegistrar,
        states: HotkeyStateRecorder = HotkeyStateRecorder()
    ) -> HotkeyRuntimeController {
        HotkeyRuntimeController(
            activate: { _ in },
            registrar: registrar,
            stateDidChange: states.record
        )
    }
}

@MainActor
private final class FakeHotkeyRegistrar: HotkeyRegistering {
    private let canStart: Bool
    private let failures: Set<Shortcut>
    private var handler: ((Shortcut, HotkeyEvent) -> Void)?

    private(set) var isRunning = false
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var registrationHistory: [Set<Shortcut>] = []

    init(canStart: Bool = true, failures: Set<Shortcut> = []) {
        self.canStart = canStart
        self.failures = failures
    }

    func start(handler: @escaping (Shortcut, HotkeyEvent) -> Void) -> Bool {
        startCallCount += 1
        guard canStart else {
            return false
        }
        self.handler = handler
        isRunning = true
        return true
    }

    func replaceRegistrations(with shortcuts: Set<Shortcut>) -> Set<Shortcut> {
        registrationHistory.append(shortcuts)
        return failures.intersection(shortcuts)
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
        handler = nil
    }

    func send(_ shortcut: Shortcut, _ event: HotkeyEvent) {
        handler?(shortcut, event)
    }

}

@MainActor
private final class HotkeyStateRecorder {
    private(set) var values: [HotkeyMonitorState] = []

    func record(_ state: HotkeyMonitorState) {
        values.append(state)
    }
}
