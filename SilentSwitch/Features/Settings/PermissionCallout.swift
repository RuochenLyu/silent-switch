import SwiftUI

struct PermissionCallout: View {
    let request: () -> Void
    let recheck: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("permission.missing.short")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("permission.missing.description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                Button(action: request) {
                    Text("permission.request")
                        .frame(minWidth: 82)
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.regular)

                Button(action: recheck) {
                    Text("common.recheck")
                        .frame(minWidth: 82)
                }
                .controlSize(.regular)
            }
            .frame(alignment: .trailing)
        }
        .padding(.leading, 14)
        .padding(.vertical, 14)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsPalette.groupBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
