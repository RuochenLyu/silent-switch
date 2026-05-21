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
    private var activationRequestID = 0

    init(
        runningApplicationProvider: RunningApplicationProviding = SystemRunningApplicationProvider(),
        workspace: WorkspaceApplicationOpening = NSWorkspace.shared
    ) {
        self.runningApplicationProvider = runningApplicationProvider
        self.workspace = workspace
    }

    func activateOrLaunch(_ target: AppTarget) {
        activationRequestID += 1
        let requestID = activationRequestID

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
            let errorDescription = error.map { String(describing: $0) }

            Task { @MainActor [weak self] in
                guard let self, self.isCurrentRequest(requestID) else {
                    return
                }

                if let errorDescription {
                    Log.activation.error("Failed to open \(bundleIdentifier, privacy: .public): \(errorDescription, privacy: .public)")
                    return
                }

                await self.activateLaunchedApplication(withBundleIdentifier: bundleIdentifier, requestID: requestID)
            }
        }
    }

    private func activateLaunchedApplication(withBundleIdentifier bundleIdentifier: String, requestID: Int) async {
        for attempt in 1...8 {
            guard isCurrentRequest(requestID) else {
                return
            }

            if activateRunningApplication(withBundleIdentifier: bundleIdentifier, logFailure: attempt == 8) {
                return
            }

            if attempt < 8 {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }

        guard isCurrentRequest(requestID) else {
            return
        }

        Log.activation.error("Opened \(bundleIdentifier, privacy: .public) but could not activate the launched application.")
    }

    private func isCurrentRequest(_ requestID: Int) -> Bool {
        requestID == activationRequestID
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
