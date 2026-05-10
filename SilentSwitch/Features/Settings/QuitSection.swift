import AppKit

@MainActor
enum QuitConfirmation {
    private static var isShowing = false

    static func requestQuit(attachedTo window: NSWindow? = NSApp.keyWindow) {
        guard !isShowing else {
            return
        }

        isShowing = true

        let alert = NSAlert()
        alert.messageText = String(localized: "quit.confirm.title")
        alert.informativeText = String(localized: "quit.confirm.message")
        alert.alertStyle = .warning

        let quitButton = alert.addButton(withTitle: String(localized: "danger.quit"))
        quitButton.hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "common.cancel"))

        if let window {
            alert.beginSheetModal(for: window) { response in
                Task { @MainActor in
                    isShowing = false
                    if response == .alertFirstButtonReturn {
                        NSApp.terminate(nil)
                    }
                }
            }
            return
        }

        let response = alert.runModal()
        isShowing = false

        if response == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }
}
