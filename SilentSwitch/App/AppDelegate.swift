import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let container = AppContainer.bootstrap()
        let settingsWindowController = SettingsWindowController(container: container)
        self.container = container
        self.settingsWindowController = settingsWindowController

        container.refreshPermissionAndHotkeys()
        container.loginItemService.refresh()

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
        container?.refreshPermissionAndHotkeys()
        container?.loginItemService.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        container?.hotkeyService.stop()
    }
}
