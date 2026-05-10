import Combine
import Foundation

@MainActor
final class AppContainer {
    let settingsStore: SettingsStore
    let permissionService: PermissionService
    let loginItemService: LoginItemService
    let hotkeyService: EventTapHotkeyService
    let appActivationService: AppActivationService
    let appMetadataReader: AppMetadataReader

    private var cancellables: Set<AnyCancellable> = []

    private init(
        settingsStore: SettingsStore,
        permissionService: PermissionService,
        loginItemService: LoginItemService,
        hotkeyService: EventTapHotkeyService,
        appActivationService: AppActivationService,
        appMetadataReader: AppMetadataReader
    ) {
        self.settingsStore = settingsStore
        self.permissionService = permissionService
        self.loginItemService = loginItemService
        self.hotkeyService = hotkeyService
        self.appActivationService = appActivationService
        self.appMetadataReader = appMetadataReader

        settingsStore.$config
            .sink { [weak self] config in
                self?.hotkeyService.updateSnapshot(HotkeySnapshot(config: config))
            }
            .store(in: &cancellables)
    }

    static func bootstrap() -> AppContainer {
        let settingsStore = SettingsStore()
        settingsStore.load()

        let appActivationService = AppActivationService()
        let hotkeyService = EventTapHotkeyService { target in
            Task { @MainActor in
                appActivationService.activateOrLaunch(target)
            }
        }

        let container = AppContainer(
            settingsStore: settingsStore,
            permissionService: PermissionService(),
            loginItemService: LoginItemService(),
            hotkeyService: hotkeyService,
            appActivationService: appActivationService,
            appMetadataReader: AppMetadataReader()
        )

        container.hotkeyService.updateSnapshot(HotkeySnapshot(config: settingsStore.config))
        return container
    }

    func refreshPermissionAndHotkeys() {
        permissionService.refresh()

        if permissionService.isAccessibilityTrusted {
            hotkeyService.startIfPermitted()
        } else {
            hotkeyService.stop()
        }
    }
}
