import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class PermissionService: ObservableObject {
    @Published private(set) var isAccessibilityTrusted = false

    func refresh() {
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        isAccessibilityTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
