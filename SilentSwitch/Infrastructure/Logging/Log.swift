import OSLog

enum Log {
    static let config = Logger(subsystem: "com.aix4u.silentswitch", category: "config")
    static let hotkeys = Logger(subsystem: "com.aix4u.silentswitch", category: "hotkeys")
    static let activation = Logger(subsystem: "com.aix4u.silentswitch", category: "activation")
    static let permissions = Logger(subsystem: "com.aix4u.silentswitch", category: "permissions")
    static let loginItem = Logger(subsystem: "com.aix4u.silentswitch", category: "loginitem")
    static let window = Logger(subsystem: "com.aix4u.silentswitch", category: "window")
}
