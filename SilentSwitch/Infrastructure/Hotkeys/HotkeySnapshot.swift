import Foundation

struct HotkeySnapshot: Sendable {
    var routes: [Shortcut: AppTarget]

    static let empty = HotkeySnapshot(routes: [:])

    init(routes: [Shortcut: AppTarget]) {
        self.routes = routes
    }

    init(config: AppConfig) {
        self.routes = ShortcutValidator.routes(from: config.slots)
    }
}
