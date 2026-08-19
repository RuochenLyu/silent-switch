import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer?
    private var settingsWindowController: SettingsWindowController?
    private var workspaceObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let container = AppContainer.bootstrap()
        let settingsWindowController = SettingsWindowController(container: container)
        self.container = container
        self.settingsWindowController = settingsWindowController

        container.refreshHotkeys()
        container.loginItemService.refresh()
        installWorkspaceObservers()

        if !LaunchContext.current.launchedAsLoginItem {
            settingsWindowController.show()
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        settingsWindowController?.show()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        container?.refreshHotkeys()
        container?.loginItemService.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(notificationCenter.removeObserver)
        workspaceObservers.removeAll()
        container?.hotkeyRuntime.stop()
    }

    private func installWorkspaceObservers() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification
        ]

        workspaceObservers = names.map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    Log.hotkeys.info("Refreshing global hotkeys after workspace lifecycle change.")
                    self?.container?.refreshHotkeys()
                }
            }
        }
    }

}
