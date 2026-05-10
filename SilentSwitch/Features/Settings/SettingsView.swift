import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var store: SettingsStore
    @ObservedObject private var permissionService: PermissionService
    @ObservedObject private var loginItemService: LoginItemService

    private let container: AppContainer
    @State private var appPickerErrorKey: String?
    @State private var loginError: String?

    init(container: AppContainer) {
        self.container = container
        self.store = container.settingsStore
        self.permissionService = container.permissionService
        self.loginItemService = container.loginItemService
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let lastError = store.lastError {
                        InlineMessage(messageKey: lastError, tone: .error)
                    }

                    if !permissionService.isAccessibilityTrusted {
                        PermissionCallout(
                            request: {
                                permissionService.requestAccessibilityPermission()
                                container.refreshPermissionAndHotkeys()
                            },
                            recheck: {
                                container.refreshPermissionAndHotkeys()
                            }
                        )
                    }

                    ShortcutSection(
                        slots: store.config.slots,
                        duplicateIDs: ShortcutValidator.duplicateSlotIDs(in: store.config.slots),
                        canAddSlot: ShortcutValidator.canAddSlot(to: store.config.slots),
                        appPickerErrorKey: appPickerErrorKey,
                        metadataReader: container.appMetadataReader,
                        updateSlot: store.updateSlot,
                        addSlot: store.addSlot,
                        removeSlot: store.removeSlot,
                        clearTarget: store.clearTarget,
                        chooseApp: chooseApp(for:)
                    )

                    GeneralSection(
                        language: store.config.language,
                        status: loginItemService.status,
                        loginError: loginError,
                        setLanguage: store.setLanguage,
                        setLaunchAtLogin: setLaunchAtLogin,
                        openLoginItemsSettings: loginItemService.openLoginItemsSettings
                    )

                    AboutSection()
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(SettingsPalette.pageBackground)
        .environment(\.locale, store.config.language.locale)
        .frame(minWidth: 620, idealWidth: 700, minHeight: 500, idealHeight: 620)
    }

    private func chooseApp(for slot: Slot) {
        appPickerErrorKey = nil

        let panel = NSOpenPanel()
        panel.title = String(localized: "shortcut.chooseApp")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = FileManager.default.urls(
            for: .applicationDirectory,
            in: .localDomainMask
        ).first ?? URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            var next = slot
            next.target = try container.appMetadataReader.target(for: url)
            store.updateSlot(next)
            appPickerErrorKey = nil
        } catch AppMetadataReaderError.missingBundleIdentifier {
            appPickerErrorKey = "shortcut.invalidApp"
        } catch {
            appPickerErrorKey = "common.error"
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItemService.setEnabled(enabled)
            store.setLaunchAtLogin(enabled)
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
    }
}
