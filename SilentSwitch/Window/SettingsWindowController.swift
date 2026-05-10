import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let container: AppContainer
    private var window: NSWindow?
    private var keyDownMonitor: Any?

    init(container: AppContainer) {
        self.container = container
    }

    func show() {
        let window = existingOrNewWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Log.window.info("Settings window shown.")
    }

    private func existingOrNewWindow() -> NSWindow {
        if let window {
            return window
        }

        let view = SettingsView(container: container)
        let defaultContentSize = NSSize(width: 700, height: 620)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Silent Switch"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedWhite: 0.12, alpha: 1)
                : NSColor(calibratedWhite: 0.985, alpha: 1)
        }
        window.minSize = NSSize(width: 620, height: 500)
        window.contentMinSize = NSSize(width: 620, height: 500)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: view)
        window.setContentSize(defaultContentSize)
        window.center()
        installKeyDownMonitor(for: window)

        self.window = window
        return window
    }

    private func installKeyDownMonitor(for window: NSWindow) {
        guard keyDownMonitor == nil else {
            return
        }

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak window] event in
            guard event.window === window else {
                return event
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags == .command,
                  event.charactersIgnoringModifiers?.lowercased() == "q" else {
                return event
            }

            QuitConfirmation.requestQuit(attachedTo: window)
            return nil
        }
    }
}
