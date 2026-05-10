import SwiftUI

struct GeneralSection: View {
    let language: AppLanguage
    let status: LoginItemStatus
    let loginError: String?
    let setLanguage: (AppLanguage) -> Void
    let setLaunchAtLogin: (Bool) -> Void
    let openLoginItemsSettings: () -> Void

    var body: some View {
        SettingsGroup(titleKey: "general.title") {
            SettingsDetailRow(
                "login.toggle",
                descriptionKey: "general.launchAtLogin.description"
            ) {
                Toggle("login.toggle", isOn: Binding(
                    get: { status.isToggleOn },
                    set: { value in setLaunchAtLogin(value) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .disabled(status == .requiresApproval)
            }

            if status == .requiresApproval {
                GroupDivider()
                HStack(alignment: .center, spacing: 10) {
                    Label {
                        Text("login.requiresApproval")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .foregroundStyle(.orange)
                    Spacer(minLength: 12)
                    Button("general.openLoginItems", action: openLoginItemsSettings)
                        .controlSize(.small)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }

            if case .error(let message) = status {
                GroupDivider()
                InlineMessage(messageKey: message, tone: .error)
                    .padding(10)
            }

            if let loginError {
                GroupDivider()
                InlineMessage(messageKey: loginError, tone: .error)
                    .padding(10)
            }

            GroupDivider()

            SettingsRow("language.title") {
                Picker("language.title", selection: Binding(
                    get: { language },
                    set: { value in setLanguage(value) }
                )) {
                    Text("language.system").tag(AppLanguage.system)
                    Text("language.zhHans").tag(AppLanguage.zhHans)
                    Text("language.en").tag(AppLanguage.en)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }

            GroupDivider()

            SettingsDetailRow(
                "runtime.status.title",
                descriptionKey: "runtime.status.description"
            ) {
                Button(role: .destructive) {
                    QuitConfirmation.requestQuit()
                } label: {
                    Text("danger.quit")
                }
            }
        }
    }
}
