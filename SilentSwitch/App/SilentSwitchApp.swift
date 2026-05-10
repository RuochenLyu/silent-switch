import SwiftUI

@main
struct SilentSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // AppDelegate owns the only visible settings window; this scene only satisfies SwiftUI's App contract.
        Settings {
            EmptyView()
        }
    }
}
