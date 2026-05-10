import Combine
import Foundation
import ServiceManagement

enum LoginItemStatus: Equatable, Sendable {
    case unknown
    case enabled
    case disabled
    case requiresApproval
    case notFound
    case error(String)

    var isToggleOn: Bool {
        switch self {
        case .enabled, .requiresApproval:
            true
        case .disabled, .notFound, .unknown, .error:
            false
        }
    }
}

@MainActor
final class LoginItemService: ObservableObject {
    @Published private(set) var status: LoginItemStatus = .unknown

    func refresh() {
        status = LoginItemStatus(status: SMAppService.mainApp.status)
    }

    func setEnabled(_ enabled: Bool) throws {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            refresh()
        } catch {
            status = .error(error.localizedDescription)
            Log.loginItem.error("Failed to update login item: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

private extension LoginItemStatus {
    init(status: SMAppService.Status) {
        switch status {
        case .enabled:
            self = .enabled
        case .notRegistered:
            self = .disabled
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .notFound
        @unknown default:
            self = .unknown
        }
    }
}
