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
protocol RunningApplicationActivating: AnyObject {
    func activate(options: NSApplication.ActivationOptions) -> Bool
}

extension NSRunningApplication: RunningApplicationActivating {}

@MainActor
final class AppActivationService: AppActivationServicing {
    private let workspace: WorkspaceApplicationOpening
    private let frontmostBundleIdentifier: () -> String?
    private let runningApplications: (String) -> [any RunningApplicationActivating]
    private let verificationDelay: Duration
    private var activationGeneration: UInt64 = 0

    init(
        workspace: WorkspaceApplicationOpening = NSWorkspace.shared,
        frontmostBundleIdentifier: @escaping () -> String? = {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        },
        runningApplications: @escaping (String) -> [any RunningApplicationActivating] = { bundleIdentifier in
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        },
        verificationDelay: Duration = .milliseconds(200)
    ) {
        self.workspace = workspace
        self.frontmostBundleIdentifier = frontmostBundleIdentifier
        self.runningApplications = runningApplications
        self.verificationDelay = verificationDelay
    }

    func activateOrLaunch(_ target: AppTarget) {
        activationGeneration &+= 1
        let generation = activationGeneration

        guard let url = applicationURL(for: target) else {
            Log.activation.error("Could not resolve application URL for \(target.bundleIdentifier, privacy: .public)")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let bundleIdentifier = target.bundleIdentifier

        workspace.openApplication(at: url, configuration: configuration) { [weak self] _, error in
            let errorDescription = error.map { String(describing: $0) }

            Task { @MainActor [weak self] in
                guard let self, self.activationGeneration == generation else {
                    return
                }

                if let errorDescription {
                    Log.activation.error("Failed to open \(bundleIdentifier, privacy: .public): \(errorDescription, privacy: .public)")
                    return
                }

                await self.verifyAndRetryActivation(
                    bundleIdentifier: bundleIdentifier,
                    generation: generation
                )
            }
        }
    }

    private func verifyAndRetryActivation(bundleIdentifier: String, generation: UInt64) async {
        try? await Task.sleep(for: verificationDelay)
        guard generation == activationGeneration else { return }

        if frontmostBundleIdentifier() == bundleIdentifier {
            Log.activation.info("Verified frontmost application \(bundleIdentifier, privacy: .public).")
            return
        }

        guard let runningApplication = runningApplications(bundleIdentifier).first else {
            Log.activation.error("Workspace accepted \(bundleIdentifier, privacy: .public), but no running application was available for activation retry.")
            return
        }

        let retryAccepted = runningApplication.activate(options: [.activateAllWindows])
        Log.activation.info("Retried activation for \(bundleIdentifier, privacy: .public); accepted: \(retryAccepted, privacy: .public).")
        try? await Task.sleep(for: verificationDelay)
        guard generation == activationGeneration else { return }

        if frontmostBundleIdentifier() == bundleIdentifier {
            Log.activation.info("Verified frontmost application \(bundleIdentifier, privacy: .public) after retry.")
        } else {
            Log.activation.error("Activation was ignored by macOS for \(bundleIdentifier, privacy: .public).")
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
