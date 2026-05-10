import Carbon.HIToolbox
import Foundation

enum KeyCodeMap {
    static func digit(forKeyCode keyCode: CGKeyCode) -> Int? {
        switch Int(keyCode) {
        case kVK_ANSI_1:
            1
        case kVK_ANSI_2:
            2
        case kVK_ANSI_3:
            3
        case kVK_ANSI_4:
            4
        case kVK_ANSI_5:
            5
        case kVK_ANSI_6:
            6
        case kVK_ANSI_7:
            7
        case kVK_ANSI_8:
            8
        case kVK_ANSI_9:
            9
        default:
            nil
        }
    }

    static func keyCode(forDigit digit: Int) -> CGKeyCode? {
        switch digit {
        case 1:
            CGKeyCode(kVK_ANSI_1)
        case 2:
            CGKeyCode(kVK_ANSI_2)
        case 3:
            CGKeyCode(kVK_ANSI_3)
        case 4:
            CGKeyCode(kVK_ANSI_4)
        case 5:
            CGKeyCode(kVK_ANSI_5)
        case 6:
            CGKeyCode(kVK_ANSI_6)
        case 7:
            CGKeyCode(kVK_ANSI_7)
        case 8:
            CGKeyCode(kVK_ANSI_8)
        case 9:
            CGKeyCode(kVK_ANSI_9)
        default:
            nil
        }
    }
}
