import AppKit
import Foundation

@MainActor
protocol AppActivationServicing: AnyObject {
    func activateOrLaunch(_ target: AppTarget)
}

@MainActor
protocol RunningApplicationProviding {
    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [RunningApplicationActivating]
    func frontmostApplication() -> RunningApplicationActivating?
}

@MainActor
protocol RunningApplicationActivating {
    var isActive: Bool { get }

    func activateAllWindows(from source: RunningApplicationActivating?) -> Bool
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
    func activateAllWindows(from source: RunningApplicationActivating?) -> Bool {
        if let source = source as? NSRunningApplication {
            return activate(from: source, options: [.activateAllWindows])
        }

        return activate(options: [.activateAllWindows])
    }
}
extension NSWorkspace: WorkspaceApplicationOpening {}

@MainActor
struct SystemRunningApplicationProvider: RunningApplicationProviding {
    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [RunningApplicationActivating] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    }

    func frontmostApplication() -> RunningApplicationActivating? {
        NSWorkspace.shared.frontmostApplication
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

        if let runningApplication = requestActivationOfRunningApplication(
            withBundleIdentifier: target.bundleIdentifier
        ) {
            verifyRunningApplicationActivation(
                runningApplication,
                target: target,
                requestID: requestID
            )
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

            if let runningApplication = requestActivationOfRunningApplication(
                withBundleIdentifier: bundleIdentifier,
                logFailure: attempt == 8
            ) {
                if runningApplication.isActive {
                    Log.activation.info("Activated launched application \(bundleIdentifier, privacy: .public).")
                    return
                }
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

    private func requestActivationOfRunningApplication(
        withBundleIdentifier bundleIdentifier: String,
        logFailure: Bool = true
    ) -> RunningApplicationActivating? {
        guard let runningApplication = runningApplicationProvider
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first
        else {
            return nil
        }

        let source = runningApplicationProvider.frontmostApplication()
        let didActivate = runningApplication.activateAllWindows(from: source)
        if !didActivate && logFailure {
            Log.activation.error("Failed to activate running application \(bundleIdentifier, privacy: .public)")
        }

        if didActivate {
            Log.activation.info("Activation requested for \(bundleIdentifier, privacy: .public).")
            return runningApplication
        }

        return nil
    }

    private func verifyRunningApplicationActivation(
        _ runningApplication: RunningApplicationActivating,
        target: AppTarget,
        requestID: Int
    ) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))

            guard let self, self.isCurrentRequest(requestID) else {
                return
            }

            if runningApplication.isActive {
                Log.activation.info("Activated running application \(target.bundleIdentifier, privacy: .public).")
                return
            }

            Log.activation.info("Activation did not make \(target.bundleIdentifier, privacy: .public) active; reopening it.")
            self.reopenRunningApplicationIfPossible(target, requestID: requestID)
        }
    }

    private func reopenRunningApplicationIfPossible(_ target: AppTarget, requestID: Int) {
        guard let url = applicationURL(for: target) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let bundleIdentifier = target.bundleIdentifier

        workspace.openApplication(at: url, configuration: configuration) { _, error in
            let errorDescription = error.map { String(describing: $0) }

            Task { @MainActor [weak self] in
                guard let self, self.isCurrentRequest(requestID), let errorDescription else {
                    return
                }

                Log.activation.error("Failed to reopen \(bundleIdentifier, privacy: .public): \(errorDescription, privacy: .public)")
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
