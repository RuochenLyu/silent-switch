import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published private(set) var config: AppConfig
    @Published private(set) var lastError: String?

    private let fileClient: ConfigFileClienting

    init(fileClient: ConfigFileClienting = ConfigFileClient()) {
        self.fileClient = fileClient
        self.config = .default
    }

    func load() {
        do {
            config = try fileClient.load()
            lastError = nil
        } catch ConfigFileError.fileMissing {
            config = .default
            persist()
        } catch {
            do {
                _ = try fileClient.backupCorruptConfig()
                config = .default
                persist()
                lastError = "settings.configError"
                Log.config.error("Configuration was corrupt and has been reset: \(String(describing: error), privacy: .public)")
            } catch {
                config = .default
                lastError = "settings.configError"
                Log.config.error("Failed to back up corrupt configuration: \(String(describing: error), privacy: .public)")
            }
        }
    }

    func setLanguage(_ language: AppLanguage) {
        update { $0.language = language }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        update { $0.launchAtLogin = enabled }
    }

    func updateSlot(_ slot: Slot) {
        update { config in
            guard let index = config.slots.firstIndex(where: { $0.id == slot.id }) else {
                return
            }

            config.slots[index] = slot
        }
    }

    func addSlot() {
        update { config in
            guard let slot = ShortcutValidator.nextSlot(for: config.slots) else {
                return
            }

            config.slots.append(slot)
        }
    }

    func removeSlot(id: UUID) {
        update { config in
            config.slots.removeAll { $0.id == id }
        }
    }

    func clearTarget(for id: UUID) {
        update { config in
            guard let index = config.slots.firstIndex(where: { $0.id == id }) else {
                return
            }

            config.slots[index].target = nil
        }
    }

    private func update(_ transform: (inout AppConfig) -> Void) {
        var next = config
        transform(&next)
        config = next
        persist()
    }

    private func persist() {
        do {
            try fileClient.save(config)
            lastError = nil
        } catch {
            lastError = "settings.configError"
            Log.config.error("Failed to save configuration: \(String(describing: error), privacy: .public)")
        }
    }
}
