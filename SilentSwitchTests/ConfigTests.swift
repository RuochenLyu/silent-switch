import Foundation
import XCTest

final class ConfigTests: XCTestCase {
    func testDefaultConfig() {
        let config = AppConfig.default

        XCTAssertEqual(config.version, 1)
        XCTAssertEqual(config.language, .system)
        XCTAssertFalse(config.launchAtLogin)
        XCTAssertEqual(config.slots.count, 3)
        XCTAssertEqual(config.slots.map(\.shortcut.digit), [1, 2, 3])
        XCTAssertTrue(config.slots.allSatisfy(\.enabled))
        XCTAssertTrue(config.slots.allSatisfy { $0.target == nil })
    }

    func testConfigRoundTrip() throws {
        let directory = try temporaryDirectory()
        let client = ConfigFileClient(configURL: directory.appendingPathComponent("config.json"))

        var config = AppConfig.default
        config.language = .en
        config.launchAtLogin = true
        config.slots[0].target = AppTarget(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            path: "/System/Applications/TextEdit.app"
        )

        try client.save(config)
        let loaded = try client.load()

        XCTAssertEqual(loaded, config)
    }

    func testNullTargetsAreWrittenExplicitly() throws {
        let directory = try temporaryDirectory()
        let configURL = directory.appendingPathComponent("config.json")
        let client = ConfigFileClient(configURL: configURL)

        try client.save(.default)

        let data = try Data(contentsOf: configURL)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let slots = try XCTUnwrap(object["slots"] as? [[String: Any]])

        XCTAssertTrue(slots.allSatisfy { slot in
            guard let target = slot["target"] else {
                return false
            }

            return target is NSNull
        })
    }

    @MainActor
    func testCorruptConfigIsBackedUpAndReset() throws {
        let directory = try temporaryDirectory()
        let configURL = directory.appendingPathComponent("config.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: configURL)

        let store = SettingsStore(fileClient: ConfigFileClient(configURL: configURL))
        store.load()

        XCTAssertEqual(store.config, .default)
        XCTAssertEqual(store.lastError, "settings.configError")

        let backups = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("config.json.corrupt-") }

        XCTAssertEqual(backups.count, 1)
        XCTAssertNoThrow(try ConfigFileClient(configURL: configURL).load())
    }

    func testAppLanguageCoding() throws {
        let encoded = try JSONEncoder().encode(AppLanguage.zhHans)
        let decoded = try JSONDecoder().decode(AppLanguage.self, from: encoded)

        XCTAssertEqual(decoded, .zhHans)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SilentSwitchTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

final class LoginItemStatusTests: XCTestCase {
    func testToggleValueFollowsSystemLoginItemStatus() {
        XCTAssertTrue(LoginItemStatus.enabled.isToggleOn)
        XCTAssertTrue(LoginItemStatus.requiresApproval.isToggleOn)
        XCTAssertFalse(LoginItemStatus.disabled.isToggleOn)
        XCTAssertFalse(LoginItemStatus.notFound.isToggleOn)
        XCTAssertFalse(LoginItemStatus.unknown.isToggleOn)
        XCTAssertFalse(LoginItemStatus.error("failed").isToggleOn)
    }
}
