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
    let loginItemService: LoginItemService
    let hotkeyStatus: HotkeyStatusModel
    let hotkeyRuntime: HotkeyRuntimeController
    let appMetadataReader: AppMetadataReader

    private var cancellables: Set<AnyCancellable> = []

    private init(
        settingsStore: SettingsStore,
        loginItemService: LoginItemService,
        hotkeyStatus: HotkeyStatusModel,
        hotkeyRuntime: HotkeyRuntimeController,
        appMetadataReader: AppMetadataReader
    ) {
        self.settingsStore = settingsStore
        self.loginItemService = loginItemService
        self.hotkeyStatus = hotkeyStatus
        self.hotkeyRuntime = hotkeyRuntime
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
            appActivationService.activateOrLaunch(target)
        } stateDidChange: { state in
            hotkeyStatus.update(state)
        }

        let container = AppContainer(
            settingsStore: settingsStore,
            loginItemService: LoginItemService(),
            hotkeyStatus: hotkeyStatus,
            hotkeyRuntime: hotkeyRuntime,
            appMetadataReader: AppMetadataReader()
        )

        container.hotkeyRuntime.updateSnapshot(HotkeySnapshot(config: settingsStore.config))
        return container
    }

    func refreshHotkeys() {
        hotkeyRuntime.start()
    }
}
