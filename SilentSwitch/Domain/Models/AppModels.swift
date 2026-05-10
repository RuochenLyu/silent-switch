import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case zhHans = "zh-Hans"
    case en

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .zhHans:
            Locale(identifier: "zh-Hans")
        case .en:
            Locale(identifier: "en")
        }
    }
}

enum ShortcutModifier: String, Codable, CaseIterable, Identifiable, Sendable {
    case option
    case command
    case control

    var id: String { rawValue }
}

struct Shortcut: Codable, Hashable, Sendable {
    var modifier: ShortcutModifier
    var digit: Int

    var isValid: Bool {
        (1...9).contains(digit)
    }
}

struct AppTarget: Codable, Hashable, Sendable {
    var bundleIdentifier: String
    var displayName: String
    var path: String?
}

struct Slot: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var enabled: Bool
    var shortcut: Shortcut
    var target: AppTarget?

    enum CodingKeys: String, CodingKey {
        case id
        case enabled
        case shortcut
        case target
    }

    init(id: UUID, enabled: Bool, shortcut: Shortcut, target: AppTarget?) {
        self.id = id
        self.enabled = enabled
        self.shortcut = shortcut
        self.target = target
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        shortcut = try container.decode(Shortcut.self, forKey: .shortcut)
        target = try container.decodeIfPresent(AppTarget.self, forKey: .target)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(shortcut, forKey: .shortcut)

        if let target {
            try container.encode(target, forKey: .target)
        } else {
            try container.encodeNil(forKey: .target)
        }
    }

    static func defaultSlot(id: UUID = UUID(), digit: Int) -> Slot {
        Slot(
            id: id,
            enabled: true,
            shortcut: Shortcut(modifier: .option, digit: digit),
            target: nil
        )
    }
}

struct AppConfig: Codable, Hashable, Sendable {
    static let currentVersion = 1

    var version: Int
    var language: AppLanguage
    var launchAtLogin: Bool
    var slots: [Slot]

    static var `default`: AppConfig {
        AppConfig(
            version: currentVersion,
            language: .system,
            launchAtLogin: false,
            slots: [
                Slot.defaultSlot(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    digit: 1
                ),
                Slot.defaultSlot(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    digit: 2
                ),
                Slot.defaultSlot(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                    digit: 3
                )
            ]
        )
    }
}
