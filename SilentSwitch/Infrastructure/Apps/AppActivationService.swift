import AppKit
import Foundation

@MainActor
protocol AppActivationServicing: AnyObject {
    func activateOrLaunch(_ target: AppTarget)
}

@MainActor
protocol RunningApplicationProviding {
    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [RunningApplicationActivating]
}

@MainActor
protocol RunningApplicationActivating {
    func yieldActivation()
    func activateFromCurrentApplication() -> Bool
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

extension NSRunningApplication: RunningApplicationActivating {
    func yieldActivation() {
        NSApp?.yieldActivation(to: self)
    }

    func activateFromCurrentApplication() -> Bool {
        activate(from: NSRunningApplication.current, options: [])
    }
}
extension NSWorkspace: WorkspaceApplicationOpening {}

@MainActor
struct SystemRunningApplicationProvider: RunningApplicationProviding {
    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [RunningApplicationActivating] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    }
}

@MainActor
final class AppActivationService: AppActivationServicing {
    private let runningApplicationProvider: RunningApplicationProviding
    private let workspace: WorkspaceApplicationOpening

    init(
        runningApplicationProvider: RunningApplicationProviding = SystemRunningApplicationProvider(),
        workspace: WorkspaceApplicationOpening = NSWorkspace.shared
    ) {
        self.runningApplicationProvider = runningApplicationProvider
        self.workspace = workspace
    }

    func activateOrLaunch(_ target: AppTarget) {
        if activateRunningApplication(withBundleIdentifier: target.bundleIdentifier) {
            return
        }

        guard let url = applicationURL(for: target) else {
            Log.activation.error("Could not resolve application URL for \(target.bundleIdentifier, privacy: .public)")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let bundleIdentifier = target.bundleIdentifier

        NSApp?.yieldActivation(toApplicationWithBundleIdentifier: bundleIdentifier)
        workspace.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                Log.activation.error("Failed to open \(bundleIdentifier, privacy: .public): \(String(describing: error), privacy: .public)")
                return
            }

            Task { @MainActor [weak self] in
                await self?.activateLaunchedApplication(withBundleIdentifier: bundleIdentifier)
            }
        }
    }

    private func activateLaunchedApplication(withBundleIdentifier bundleIdentifier: String) async {
        for attempt in 1...8 {
            if activateRunningApplication(withBundleIdentifier: bundleIdentifier, logFailure: attempt == 8) {
                return
            }

            if attempt < 8 {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }

        Log.activation.error("Opened \(bundleIdentifier, privacy: .public) but could not activate the launched application.")
    }

    private func activateRunningApplication(
        withBundleIdentifier bundleIdentifier: String,
        logFailure: Bool = true
    ) -> Bool {
        guard let runningApplication = runningApplicationProvider
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first
        else {
            return false
        }

        runningApplication.yieldActivation()
        let didActivate = runningApplication.activateFromCurrentApplication()
        if !didActivate && logFailure {
            Log.activation.error("Failed to activate running application \(bundleIdentifier, privacy: .public)")
        }
        return didActivate
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
