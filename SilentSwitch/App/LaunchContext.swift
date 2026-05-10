import AppKit
import Carbon
import Foundation

struct LaunchContext: Sendable {
    let launchedAsLoginItem: Bool

    static var current: LaunchContext {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let isLoginItem = event?.eventClass == kCoreEventClass
            && event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem

        return LaunchContext(launchedAsLoginItem: isLoginItem)
    }
}
