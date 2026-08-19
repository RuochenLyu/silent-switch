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
    func testAlwaysUsesWorkspaceToPreserveUserActivationIntent() async {
        let applicationURL = URL(fileURLWithPath: "/Applications/Resolved.app")
        let workspace = FakeWorkspace(resolvedURL: applicationURL)
        let service = AppActivationService(
            workspace: workspace,
            frontmostBundleIdentifier: { self.sampleTarget.bundleIdentifier },
            verificationDelay: .zero
        )

        service.activateOrLaunch(sampleTarget)

        XCTAssertEqual(workspace.requestedBundleIdentifier, sampleTarget.bundleIdentifier)
        XCTAssertEqual(workspace.openedURL, applicationURL)
        XCTAssertEqual(workspace.openConfigurationActivates, true)
        for _ in 0..<3 { await Task.yield() }
    }

    func testFallsBackToStoredPathWhenBundleIdentifierCannotBeResolved() async {
        let workspace = FakeWorkspace(resolvedURL: nil)
        let service = AppActivationService(
            workspace: workspace,
            frontmostBundleIdentifier: { self.sampleTarget.bundleIdentifier },
            verificationDelay: .zero
        )

        service.activateOrLaunch(sampleTarget)

        XCTAssertEqual(workspace.openedURL, URL(fileURLWithPath: sampleTarget.path!))
        for _ in 0..<3 { await Task.yield() }
    }

    func testDoesNotOpenWhenTargetCannotBeResolved() {
        let workspace = FakeWorkspace(resolvedURL: nil)
        let target = AppTarget(
            bundleIdentifier: "com.example.Missing",
            displayName: "Missing",
            path: nil
        )
        let service = AppActivationService(
            workspace: workspace,
            frontmostBundleIdentifier: { target.bundleIdentifier },
            verificationDelay: .zero
        )

        service.activateOrLaunch(target)

        XCTAssertNil(workspace.openedURL)
    }

    func testRetriesRunningApplicationWhenWorkspaceDidNotMakeItFrontmost() async {
        let workspace = FakeWorkspace(resolvedURL: URL(fileURLWithPath: sampleTarget.path!))
        var frontmostBundleIdentifier = "com.example.Foreground"
        let runningApplication = FakeRunningApplication {
            frontmostBundleIdentifier = self.sampleTarget.bundleIdentifier
        }
        let service = AppActivationService(
            workspace: workspace,
            frontmostBundleIdentifier: { frontmostBundleIdentifier },
            runningApplications: { _ in [runningApplication] },
            verificationDelay: .zero
        )

        service.activateOrLaunch(sampleTarget)
        for _ in 0..<4 { await Task.yield() }

        XCTAssertEqual(runningApplication.activateCallCount, 1)
        XCTAssertEqual(frontmostBundleIdentifier, sampleTarget.bundleIdentifier)
    }

    func testNewActivationSupersedesPendingRetry() async {
        let workspace = FakeWorkspace(resolvedURL: URL(fileURLWithPath: sampleTarget.path!))
        let nextTarget = AppTarget(
            bundleIdentifier: "com.example.Next",
            displayName: "Next",
            path: "/Applications/Next.app"
        )
        let firstApplication = FakeRunningApplication()
        let nextApplication = FakeRunningApplication()
        let service = AppActivationService(
            workspace: workspace,
            frontmostBundleIdentifier: { "com.example.Foreground" },
            runningApplications: { bundleIdentifier in
                bundleIdentifier == self.sampleTarget.bundleIdentifier
                    ? [firstApplication]
                    : [nextApplication]
            },
            verificationDelay: .zero
        )

        service.activateOrLaunch(sampleTarget)
        service.activateOrLaunch(nextTarget)
        for _ in 0..<6 { await Task.yield() }

        XCTAssertEqual(firstApplication.activateCallCount, 0)
        XCTAssertEqual(nextApplication.activateCallCount, 1)
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
private final class FakeRunningApplication: RunningApplicationActivating {
    private let onActivate: () -> Void
    private(set) var activateCallCount = 0

    init(onActivate: @escaping () -> Void = {}) {
        self.onActivate = onActivate
    }

    func activate(options: NSApplication.ActivationOptions) -> Bool {
        activateCallCount += 1
        onActivate()
        return true
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
