import Foundation

enum ShortcutValidator {
    static let maxSlotCount = 9

    static func duplicateSlotIDs(in slots: [Slot]) -> Set<UUID> {
        let enabledSlots = slots.filter { $0.enabled && $0.shortcut.isValid && $0.target != nil }
        let counts = Dictionary(grouping: enabledSlots, by: \.shortcut)
        let duplicatedShortcuts = Set(counts.compactMap { shortcut, groupedSlots in
            groupedSlots.count > 1 ? shortcut : nil
        })

        return Set(enabledSlots.compactMap { slot in
            duplicatedShortcuts.contains(slot.shortcut) ? slot.id : nil
        })
    }

    static func routes(from slots: [Slot]) -> [Shortcut: AppTarget] {
        let duplicatedIDs = duplicateSlotIDs(in: slots)
        var routes: [Shortcut: AppTarget] = [:]

        for slot in slots {
            guard slot.enabled,
                  slot.shortcut.isValid,
                  !duplicatedIDs.contains(slot.id),
                  let target = slot.target
            else {
                continue
            }

            routes[slot.shortcut] = target
        }

        return routes
    }

    static func canAddSlot(to slots: [Slot]) -> Bool {
        slots.count < maxSlotCount
    }

    static func nextSlot(for slots: [Slot]) -> Slot? {
        guard canAddSlot(to: slots) else {
            return nil
        }

        let usedDigits = Set(slots.map(\.shortcut.digit))
        let digit = (1...9).first { !usedDigits.contains($0) } ?? min(slots.count + 1, 9)
        return Slot.defaultSlot(digit: digit)
    }
}
