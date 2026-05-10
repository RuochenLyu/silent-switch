import AppKit
import SwiftUI

enum SettingsPalette {
    static let pageBackground = dynamicColor(
        light: NSColor(calibratedWhite: 0.985, alpha: 1),
        dark: NSColor(calibratedWhite: 0.12, alpha: 1)
    )

    static let groupBackground = dynamicColor(
        light: NSColor(calibratedWhite: 0.94, alpha: 1),
        dark: NSColor(calibratedWhite: 0.18, alpha: 1)
    )

    static let separator = Color(nsColor: .separatorColor).opacity(0.22)

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let matched = appearance.bestMatch(from: [.darkAqua, .aqua])
            return matched == .darkAqua ? dark : light
        })
    }
}

enum InlineMessageTone {
    case error
    case warning

    var color: Color {
        switch self {
        case .error: .red
        case .warning: .orange
        }
    }

    var symbol: String {
        switch self {
        case .error: "exclamationmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        }
    }
}

struct InlineMessage: View {
    let messageKey: String
    let tone: InlineMessageTone

    var body: some View {
        Label {
            Text(LocalizedStringKey(messageKey))
                .font(.callout)
                .foregroundStyle(tone.color)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: tone.symbol)
                .foregroundStyle(tone.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SettingsGroup<Content: View>: View {
    let titleKey: LocalizedStringKey?
    let footerKey: LocalizedStringKey?
    let content: Content

    init(
        titleKey: LocalizedStringKey? = nil,
        footerKey: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.titleKey = titleKey
        self.footerKey = footerKey
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let titleKey {
                Text(titleKey)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.leading, 2)
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SettingsPalette.groupBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let footerKey {
                Text(footerKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }
}

struct SettingsRow<Trailing: View>: View {
    let titleKey: LocalizedStringKey
    let trailing: Trailing

    init(_ titleKey: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) {
        self.titleKey = titleKey
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(titleKey)
                .font(.body)
            Spacer(minLength: 16)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 42)
        .frame(maxWidth: .infinity)
    }
}

struct SettingsDetailRow<Trailing: View>: View {
    let titleKey: LocalizedStringKey
    let descriptionKey: LocalizedStringKey
    let trailing: Trailing

    init(
        _ titleKey: LocalizedStringKey,
        descriptionKey: LocalizedStringKey,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(titleKey)
                    .font(.body)
                Text(descriptionKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 54)
        .frame(maxWidth: .infinity)
    }
}

struct GroupDivider: View {
    var body: some View {
        Divider()
            .overlay(SettingsPalette.separator)
            .padding(.leading, 14)
    }
}

struct AboutSection: View {
    private static let repositoryURLString = "https://github.com/RuochenLyu/silent-switch"

    var body: some View {
        SettingsGroup(titleKey: "about.title") {
            SettingsRow("about.version") {
                Text(versionText)
                    .foregroundStyle(.secondary)
            }

            GroupDivider()

            SettingsRow("about.repository") {
                if let repositoryURL {
                    Link(destination: repositoryURL) {
                        Text("about.github")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(repositoryURL.absoluteString)
                } else {
                    Text("about.github")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var repositoryURL: URL? {
        URL(string: Self.repositoryURLString)
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        return String(
            format: String(localized: "about.versionFormat"),
            version,
            build
        )
    }
}
