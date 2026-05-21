import AppKit
import Foundation
import XCTest

final class AppMetadataReaderTests: XCTestCase {
    func testReadsBundleIdentifierAndDisplayNameFromApplicationBundle() throws {
        let url = try XCTUnwrap([
            URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
            URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
            URL(fileURLWithPath: "/Applications/Safari.app")
        ].first { FileManager.default.fileExists(atPath: $0.path) })

        let target = try AppMetadataReader().target(for: url)

        XCTAssertFalse(target.bundleIdentifier.isEmpty)
        XCTAssertFalse(target.displayName.isEmpty)
        XCTAssertEqual(target.path, url.path)
    }
}

@MainActor
final class AppActivationServiceTests: XCTestCase {
    func testActivatesRunningApplicationAndDoesNotLaunch() {
        let runningApplication = FakeRunningApplication()
        let provider = FakeRunningApplicationProvider(applications: [runningApplication])
        let workspace = FakeWorkspace()
        let service = AppActivationService(
            runningApplicationProvider: provider,
            workspace: workspace
        )

        service.activateOrLaunch(sampleTarget)

        XCTAssertEqual(runningApplication.activateCallCount, 1)
        XCTAssertEqual(runningApplication.yieldActivationCallCount, 1)
        XCTAssertNil(workspace.openedURL)
    }

    func testLaunchesResolvedBundleIdentifierWhenApplicationIsNotRunning() async {
        let applicationURL = URL(fileURLWithPath: "/Applications/Resolved.app")
        let launchedApplication = FakeRunningApplication()
        let provider = FakeRunningApplicationProvider(applicationResponses: [[], [launchedApplication]])
        let workspace = FakeWorkspace(resolvedURL: applicationURL)
        let service = AppActivationService(
            runningApplicationProvider: provider,
            workspace: workspace
        )

        service.activateOrLaunch(sampleTarget)
        await Task.yield()

        XCTAssertEqual(workspace.requestedBundleIdentifier, sampleTarget.bundleIdentifier)
        XCTAssertEqual(workspace.openedURL, applicationURL)
        XCTAssertEqual(workspace.openConfigurationActivates, true)
        XCTAssertEqual(provider.requestedBundleIdentifiers, [sampleTarget.bundleIdentifier, sampleTarget.bundleIdentifier])
        XCTAssertEqual(launchedApplication.yieldActivationCallCount, 1)
        XCTAssertEqual(launchedApplication.activateCallCount, 1)
    }

    func testFallsBackToStoredPathWhenBundleIdentifierCannotBeResolved() async {
        let launchedApplication = FakeRunningApplication()
        let provider = FakeRunningApplicationProvider(applicationResponses: [[], [launchedApplication]])
        let workspace = FakeWorkspace(resolvedURL: nil)
        let service = AppActivationService(
            runningApplicationProvider: provider,
            workspace: workspace
        )

        service.activateOrLaunch(sampleTarget)
        await Task.yield()

        XCTAssertEqual(workspace.openedURL, URL(fileURLWithPath: sampleTarget.path!))
        XCTAssertEqual(launchedApplication.activateCallCount, 1)
    }

    func testRetriesActivationUntilLaunchedApplicationIsRunning() async {
        let applicationURL = URL(fileURLWithPath: "/Applications/Resolved.app")
        let launchedApplication = FakeRunningApplication()
        let provider = FakeRunningApplicationProvider(applicationResponses: [[], [], [], [launchedApplication]])
        let workspace = FakeWorkspace(resolvedURL: applicationURL)
        let service = AppActivationService(
            runningApplicationProvider: provider,
            workspace: workspace
        )

        service.activateOrLaunch(sampleTarget)
        try? await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertEqual(workspace.openedURL, applicationURL)
        XCTAssertEqual(provider.requestedBundleIdentifiers.count, 4)
        XCTAssertEqual(launchedApplication.yieldActivationCallCount, 1)
        XCTAssertEqual(launchedApplication.activateCallCount, 1)
    }

    func testStaleLaunchRetryDoesNotStealFocusAfterNewShortcutRequest() async {
        let firstTarget = AppTarget(
            bundleIdentifier: "com.example.First",
            displayName: "First",
            path: "/Applications/First.app"
        )
        let secondTarget = AppTarget(
            bundleIdentifier: "com.example.Second",
            displayName: "Second",
            path: "/Applications/Second.app"
        )
        let firstApplication = FakeRunningApplication()
        let secondApplication = FakeRunningApplication()
        let provider = FakeRunningApplicationProvider(applicationResponsesByBundleIdentifier: [
            firstTarget.bundleIdentifier: [[], [], [firstApplication]],
            secondTarget.bundleIdentifier: [[secondApplication]]
        ])
        let workspace = FakeWorkspace(resolvedURL: URL(fileURLWithPath: "/Applications/Resolved.app"))
        let service = AppActivationService(
            runningApplicationProvider: provider,
            workspace: workspace
        )

        service.activateOrLaunch(firstTarget)
        await Task.yield()
        service.activateOrLaunch(secondTarget)
        try? await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertEqual(secondApplication.activateCallCount, 1)
        XCTAssertEqual(firstApplication.activateCallCount, 0)
    }

    private var sampleTarget: AppTarget {
        AppTarget(
            bundleIdentifier: "com.example.Target",
            displayName: "Target",
            path: "/Applications/Target.app"
        )
    }
}

@MainActor
private final class FakeRunningApplicationProvider: RunningApplicationProviding {
    private var applicationResponses: [[RunningApplicationActivating]]
    private var applicationResponsesByBundleIdentifier: [String: [[RunningApplicationActivating]]]
    private(set) var requestedBundleIdentifiers: [String] = []

    init(applications: [RunningApplicationActivating]) {
        self.applicationResponses = [applications]
        self.applicationResponsesByBundleIdentifier = [:]
    }

    init(applicationResponses: [[RunningApplicationActivating]]) {
        self.applicationResponses = applicationResponses
        self.applicationResponsesByBundleIdentifier = [:]
    }

    init(applicationResponsesByBundleIdentifier: [String: [[RunningApplicationActivating]]]) {
        self.applicationResponses = []
        self.applicationResponsesByBundleIdentifier = applicationResponsesByBundleIdentifier
    }

    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [RunningApplicationActivating] {
        requestedBundleIdentifiers.append(bundleIdentifier)

        if var responses = applicationResponsesByBundleIdentifier[bundleIdentifier] {
            if responses.count > 1 {
                let response = responses.removeFirst()
                applicationResponsesByBundleIdentifier[bundleIdentifier] = responses
                return response
            }

            return responses.first ?? []
        }

        if applicationResponses.count > 1 {
            return applicationResponses.removeFirst()
        }

        return applicationResponses.first ?? []
    }
}

@MainActor
private final class FakeRunningApplication: RunningApplicationActivating {
    private(set) var activateCallCount = 0
    private(set) var yieldActivationCallCount = 0
    var activationResult = true

    func yieldActivation() {
        yieldActivationCallCount += 1
    }

    func activateFromCurrentApplication() -> Bool {
        activateCallCount += 1
        return activationResult
    }
}

@MainActor
private final class FakeWorkspace: WorkspaceApplicationOpening {
    private let resolvedURL: URL?
    private(set) var requestedBundleIdentifier: String?
    private(set) var openedURL: URL?
    private(set) var openConfigurationActivates: Bool?

    init(resolvedURL: URL? = nil) {
        self.resolvedURL = resolvedURL
    }

    func urlForApplication(withBundleIdentifier bundleIdentifier: String) -> URL? {
        requestedBundleIdentifier = bundleIdentifier
        return resolvedURL
    }

    func openApplication(
        at applicationURL: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: (@Sendable (NSRunningApplication?, (any Error)?) -> Void)?
    ) {
        openedURL = applicationURL
        openConfigurationActivates = configuration.activates
        completionHandler?(nil, nil)
    }
}
