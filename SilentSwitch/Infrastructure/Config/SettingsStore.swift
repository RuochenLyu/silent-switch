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
            let loaded = try fileClient.load()
            let normalized = loaded.normalized()
            config = normalized

            if normalized != loaded, loaded.version <= AppConfig.currentVersion {
                do {
                    try fileClient.save(normalized)
                } catch {
                    lastError = "settings.configSaveError"
                    Log.config.error("Failed to save normalized configuration: \(String(describing: error), privacy: .public)")
                    return
                }
            }
            lastError = nil
        } catch ConfigFileError.fileMissing {
            config = .default
            persist(config)
        } catch {
            do {
                _ = try fileClient.backupCorruptConfig()
                config = .default
                persist(config)
                lastError = "settings.configReadError"
                Log.config.error("Configuration was corrupt and has been reset: \(String(describing: error), privacy: .public)")
            } catch {
                config = .default
                lastError = "settings.configReadError"
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
        next = next.normalized()

        guard next != config else {
            return
        }

        do {
            try fileClient.save(next)
            config = next
            lastError = nil
        } catch {
            lastError = "settings.configSaveError"
            Log.config.error("Failed to save configuration: \(String(describing: error), privacy: .public)")
        }
    }

    private func persist(_ config: AppConfig) {
        do {
            try fileClient.save(config)
            lastError = nil
        } catch {
            lastError = "settings.configSaveError"
            Log.config.error("Failed to save configuration: \(String(describing: error), privacy: .public)")
        }
    }
}
