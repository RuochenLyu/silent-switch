import ApplicationServices
import Foundation

protocol HotkeyEventTap: AnyObject {
    var isValid: Bool { get }
    var isEnabled: Bool { get }

    func enable()
    func invalidate()
}

protocol HotkeyEventTapCreating {
    func makeTap(
        callback: CGEventTapCallBack,
        userInfo: UnsafeMutableRawPointer
    ) -> (any HotkeyEventTap)?
}

private final class SystemHotkeyEventTap: HotkeyEventTap {
    private let port: CFMachPort
    private let source: CFRunLoopSource

    init(port: CFMachPort, source: CFRunLoopSource) {
        self.port = port
        self.source = source
    }

    var isValid: Bool {
        CFMachPortIsValid(port)
    }

    var isEnabled: Bool {
        CGEvent.tapIsEnabled(tap: port)
    }

    func enable() {
        CGEvent.tapEnable(tap: port, enable: true)
    }

    func invalidate() {
        CGEvent.tapEnable(tap: port, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        CFMachPortInvalidate(port)
    }
}

struct SystemHotkeyEventTapFactory: HotkeyEventTapCreating {
    func makeTap(
        callback: CGEventTapCallBack,
        userInfo: UnsafeMutableRawPointer
    ) -> (any HotkeyEventTap)? {
        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: userInfo
        ) else {
            return nil
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CFMachPortInvalidate(port)
            return nil
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        return SystemHotkeyEventTap(port: port, source: source)
    }
}
