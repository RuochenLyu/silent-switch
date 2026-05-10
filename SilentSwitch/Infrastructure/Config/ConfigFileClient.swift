import Foundation

protocol ConfigFileClienting {
    var configURL: URL { get }

    func load() throws -> AppConfig
    func save(_ config: AppConfig) throws
    func backupCorruptConfig() throws -> URL
}

enum ConfigFileError: Error, Equatable {
    case fileMissing
}

struct ConfigFileClient: ConfigFileClienting {
    let configURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configURL: URL = ConfigFileClient.defaultConfigURL(),
        fileManager: FileManager = .default
    ) {
        self.configURL = configURL
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    static func defaultConfigURL() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return applicationSupport
            .appendingPathComponent("com.aix4u.silentswitch", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    func load() throws -> AppConfig {
        guard fileManager.fileExists(atPath: configURL.path) else {
            throw ConfigFileError.fileMissing
        }

        let data = try Data(contentsOf: configURL)
        return try decoder.decode(AppConfig.self, from: data)
    }

    func save(_ config: AppConfig) throws {
        let directoryURL = configURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: [.atomic])
    }

    func backupCorruptConfig() throws -> URL {
        let timestamp = ConfigFileClient.backupTimestamp()
        let backupURL = configURL.deletingLastPathComponent()
            .appendingPathComponent("config.json.corrupt-\(timestamp)")

        guard fileManager.fileExists(atPath: configURL.path) else {
            return backupURL
        }

        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }

        try fileManager.moveItem(at: configURL, to: backupURL)
        return backupURL
    }

    private static func backupTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: Date())
    }
}
