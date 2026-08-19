import AppKit
import Foundation

@MainActor
protocol AppActivationServicing: AnyObject {
    func activateOrLaunch(_ target: AppTarget)
}

@MainActor
protocol WorkspaceApplicationOpening {
    func urlForApplication(withBundleIdentifier bundleIdentifier: String) -> URL?
    func openApplication(
        at applicationURL: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: (@Sendable (NSRunningApplication?, (any Error)?) -> Void)?
    )
}

extension NSWorkspace: WorkspaceApplicationOpening {}

@MainActor
final class AppActivationService: AppActivationServicing {
    private let workspace: WorkspaceApplicationOpening

    init(workspace: WorkspaceApplicationOpening = NSWorkspace.shared) {
        self.workspace = workspace
    }

    func activateOrLaunch(_ target: AppTarget) {
        guard let url = applicationURL(for: target) else {
            Log.activation.error("Could not resolve application URL for \(target.bundleIdentifier, privacy: .public)")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let bundleIdentifier = target.bundleIdentifier

        workspace.openApplication(at: url, configuration: configuration) { _, error in
            let errorDescription = error.map { String(describing: $0) }

            Task { @MainActor in
                if let errorDescription {
                    Log.activation.error("Failed to open \(bundleIdentifier, privacy: .public): \(errorDescription, privacy: .public)")
                    return
                }

                Log.activation.info("Asked the workspace to activate \(bundleIdentifier, privacy: .public).")
            }
        }
    }

    private func applicationURL(for target: AppTarget) -> URL? {
        if let url = workspace.urlForApplication(withBundleIdentifier: target.bundleIdentifier) {
            return url
        }

        if let path = target.path {
            return URL(fileURLWithPath: path)
        }

        return nil
    }
}
