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
    func testAlwaysUsesWorkspaceToPreserveUserActivationIntent() {
        let applicationURL = URL(fileURLWithPath: "/Applications/Resolved.app")
        let workspace = FakeWorkspace(resolvedURL: applicationURL)
        let service = AppActivationService(workspace: workspace)

        service.activateOrLaunch(sampleTarget)

        XCTAssertEqual(workspace.requestedBundleIdentifier, sampleTarget.bundleIdentifier)
        XCTAssertEqual(workspace.openedURL, applicationURL)
        XCTAssertEqual(workspace.openConfigurationActivates, true)
    }

    func testFallsBackToStoredPathWhenBundleIdentifierCannotBeResolved() {
        let workspace = FakeWorkspace(resolvedURL: nil)
        let service = AppActivationService(workspace: workspace)

        service.activateOrLaunch(sampleTarget)

        XCTAssertEqual(workspace.openedURL, URL(fileURLWithPath: sampleTarget.path!))
    }

    func testDoesNotOpenWhenTargetCannotBeResolved() {
        let workspace = FakeWorkspace(resolvedURL: nil)
        let service = AppActivationService(workspace: workspace)
        let target = AppTarget(
            bundleIdentifier: "com.example.Missing",
            displayName: "Missing",
            path: nil
        )

        service.activateOrLaunch(target)

        XCTAssertNil(workspace.openedURL)
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
