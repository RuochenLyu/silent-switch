import Combine
import Foundation

@MainActor
final class HotkeyStatusModel: ObservableObject {
    @Published private(set) var state: HotkeyMonitorState = .stopped

    func update(_ state: HotkeyMonitorState) {
        self.state = state
    }
}

@MainActor
final class AppContainer {
    let settingsStore: SettingsStore
    let permissionService: PermissionService
    let loginItemService: LoginItemService
    let hotkeyStatus: HotkeyStatusModel
    let hotkeyRuntime: HotkeyRuntimeController
    let appActivationService: AppActivationService
    let appMetadataReader: AppMetadataReader

    private var cancellables: Set<AnyCancellable> = []

    private init(
        settingsStore: SettingsStore,
        permissionService: PermissionService,
        loginItemService: LoginItemService,
        hotkeyStatus: HotkeyStatusModel,
        hotkeyRuntime: HotkeyRuntimeController,
        appActivationService: AppActivationService,
        appMetadataReader: AppMetadataReader
    ) {
        self.settingsStore = settingsStore
        self.permissionService = permissionService
        self.loginItemService = loginItemService
        self.hotkeyStatus = hotkeyStatus
        self.hotkeyRuntime = hotkeyRuntime
        self.appActivationService = appActivationService
        self.appMetadataReader = appMetadataReader

        settingsStore.$config
            .sink { [weak self] config in
                self?.hotkeyRuntime.updateSnapshot(HotkeySnapshot(config: config))
            }
            .store(in: &cancellables)
    }

    static func bootstrap() -> AppContainer {
        let settingsStore = SettingsStore()
        settingsStore.load()

        let appActivationService = AppActivationService()
        let hotkeyStatus = HotkeyStatusModel()
        let hotkeyRuntime = HotkeyRuntimeController { target in
            Task { @MainActor in
                appActivationService.activateOrLaunch(target)
            }
        } stateDidChange: { state in
            Task { @MainActor in
                hotkeyStatus.update(state)
            }
        }

        let container = AppContainer(
            settingsStore: settingsStore,
            permissionService: PermissionService(),
            loginItemService: LoginItemService(),
            hotkeyStatus: hotkeyStatus,
            hotkeyRuntime: hotkeyRuntime,
            appActivationService: appActivationService,
            appMetadataReader: AppMetadataReader()
        )

        container.hotkeyRuntime.updateSnapshot(HotkeySnapshot(config: settingsStore.config))
        return container
    }

    func refreshPermissionAndHotkeys() {
        permissionService.refresh()

        if permissionService.isAccessibilityTrusted {
            hotkeyRuntime.startIfPermitted()
        } else {
            hotkeyRuntime.stop()
        }
    }
}
