import AppKit
import SwiftUI

struct ShortcutSection: View {
    let slots: [Slot]
    let duplicateIDs: Set<UUID>
    let canAddSlot: Bool
    let appPickerErrorKey: String?
    let metadataReader: AppMetadataReader
    let updateSlot: (Slot) -> Void
    let addSlot: () -> Void
    let removeSlot: (UUID) -> Void
    let clearTarget: (UUID) -> Void
    let chooseApp: (Slot) -> Void

    var body: some View {
        SettingsGroup(titleKey: "shortcut.title") {
            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                ShortcutRow(
                    slot: slot,
                    isDuplicate: duplicateIDs.contains(slot.id),
                    canRemove: slots.count > 1,
                    metadataReader: metadataReader,
                    updateSlot: updateSlot,
                    removeSlot: removeSlot,
                    clearTarget: clearTarget,
                    chooseApp: chooseApp
                )

                if index < slots.count - 1 {
                    GroupDivider()
                }
            }

            if let appPickerErrorKey {
                GroupDivider()
                InlineMessage(messageKey: appPickerErrorKey, tone: .error)
                    .padding(10)
            }

            GroupDivider()

            HStack(spacing: 8) {
                Button(action: addSlot) {
                    Label("shortcut.addSlot", systemImage: "plus")
                }
                .controlSize(.small)
                .disabled(!canAddSlot)

                if !canAddSlot {
                    Text("shortcut.maxSlots")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

private struct ShortcutRow: View {
    let slot: Slot
    let isDuplicate: Bool
    let canRemove: Bool
    let metadataReader: AppMetadataReader
    let updateSlot: (Slot) -> Void
    let removeSlot: (UUID) -> Void
    let clearTarget: (UUID) -> Void
    let chooseApp: (Slot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 9) {
                Toggle("shortcut.enabled", isOn: enabledBinding)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .help(Text("shortcut.enabled"))
                    .frame(width: 42, alignment: .leading)

                Picker("shortcut.modifier", selection: modifierBinding) {
                    Text("modifier.option").tag(ShortcutModifier.option)
                    Text("modifier.command").tag(ShortcutModifier.command)
                    Text("modifier.control").tag(ShortcutModifier.control)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 116)
                .disabled(!slot.enabled)

                Picker("shortcut.digit", selection: digitBinding) {
                    ForEach(1...9, id: \.self) { digit in
                        Text("\(digit)").tag(digit)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 50)
                .disabled(!slot.enabled)

                Button {
                    chooseApp(slot)
                } label: {
                    AppTargetLabel(target: slot.target, metadataReader: metadataReader)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!slot.enabled)
                .help(Text(tooltip))
                .accessibilityLabel(Text("shortcut.chooseApp"))
                .accessibilityValue(appAccessibilityValue)

                Button {
                    clearTarget(slot.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                .disabled(slot.target == nil || !slot.enabled)
                .help(Text("common.clear"))
                .accessibilityLabel(Text("shortcut.clearTarget"))

                Button(role: .destructive) {
                    removeSlot(slot.id)
                } label: {
                    Image(systemName: "trash")
                        .imageScale(.medium)
                }
                .buttonStyle(.borderless)
                .disabled(!canRemove)
                .help(Text("shortcut.remove"))
                .accessibilityLabel(Text("shortcut.remove"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isDuplicate {
                Label {
                    Text("shortcut.duplicateWarning")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                .padding(.leading, 51)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(slot.enabled ? 1 : 0.62)
    }

    private var tooltip: String {
        guard let target = slot.target else {
            return String(localized: "shortcut.chooseApp")
        }
        if let path = target.path, !path.isEmpty {
            return "\(target.bundleIdentifier)\n\(path)"
        }
        return target.bundleIdentifier
    }

    private var appAccessibilityValue: Text {
        if let target = slot.target {
            return Text(target.displayName)
        }

        return Text("shortcut.emptyTarget")
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { slot.enabled },
            set: { value in
                var next = slot
                next.enabled = value
                updateSlot(next)
            }
        )
    }

    private var modifierBinding: Binding<ShortcutModifier> {
        Binding(
            get: { slot.shortcut.modifier },
            set: { value in
                var next = slot
                next.shortcut.modifier = value
                updateSlot(next)
            }
        )
    }

    private var digitBinding: Binding<Int> {
        Binding(
            get: { slot.shortcut.digit },
            set: { value in
                var next = slot
                next.shortcut.digit = value
                updateSlot(next)
            }
        )
    }
}

private struct AppTargetLabel: View {
    let target: AppTarget?
    let metadataReader: AppMetadataReader

    var body: some View {
        HStack(spacing: 7) {
            iconView
                .frame(width: 18, height: 18)

            if let target {
                Text(target.displayName)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text("shortcut.emptyTarget")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.up.chevron.down")
                .foregroundStyle(.secondary)
                .font(.caption2)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let target {
            Image(nsImage: metadataReader.icon(for: target))
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.secondary)
                .font(.body)
        }
    }
}
