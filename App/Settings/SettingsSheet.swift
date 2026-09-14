import SwiftUI

/// Settings — native Form: DARSTELLUNG (segmented theme + palette accent),
/// MEHR (bug report, privacy, legal, log out), version footer.
struct SettingsSheet: View {
    var onBugReport: () -> Void
    /// Privacy and legal notice: pushed on the home stack like the bug report (a sheet on
    /// top of this sheet is not presented reliably).
    var onOpenWeb: (String, String) -> Void
    @Environment(Prefs.self) private var prefs
    @Environment(HomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmLogout = false

    /// System / Deutsch / English; applies at once, and the personal plan's PDF is rebuilt in the new
    /// language from the stored plan.
    private var languageBinding: Binding<String> {
        Binding(get: { AppLanguage.shared.code ?? "system" }, set: { value in
            Haptics.light()
            AppLanguage.shared.set(value == "system" ? nil : value)
            if let saved = CustomPlanStore.shared.saved { _ = try? CustomPlanSource.pdfFile(for: saved.plan) }
        })
    }

    private let appVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

    var body: some View {
        NavigationStack {
            Form {
                Section(L.s("settingsSectionAppearance")) {
                    LabeledContent(L.s("appearanceTitle")) {
                        ThemeModePicker().frame(maxWidth: 220)
                    }
                    LabeledContent(L.s("accentColor")) {
                        AccentPalettePicker().frame(maxWidth: 220)
                    }
                    Picker(L.s("settings.language"), selection: languageBinding) {
                        Text(L.s("settings.language.system")).tag("system")
                        Text(verbatim: "Deutsch").tag("de")
                        Text(verbatim: "English").tag("en")
                    }
                    .accessibilityIdentifier("settings.language")
                }

                Section {
                    Button {
                        Haptics.light()
                        onBugReport()
                    } label: {
                        Label(L.s("bugReport"), systemImage: "ladybug")
                    }
                    Button {
                        Haptics.light()
                        onOpenWeb("https://privacy.lgka.app", L.s("privacyLabel"))
                    } label: {
                        Label(L.s("privacyLabel"), systemImage: "hand.raised")
                    }
                    Button {
                        Haptics.light()
                        onOpenWeb("https://impressum.lgka.app", L.s("legalLabel"))
                    } label: {
                        Label(L.s("legalLabel"), systemImage: "info.circle")
                    }
                    Button(role: .destructive) {
                        Haptics.light()
                        confirmLogout = true
                    } label: {
                        Label(L.s("logout"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text(L.s("settingsSectionMore"))
                } footer: {
                    HStack(spacing: 0) {
                        Spacer()
                        Text("© \(String(Calendar.current.component(.year, from: Date()))) ")
                        Text("Luka Löhr").foregroundStyle(.tint)
                        Text(" • v\(appVersion)")
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle(L.s("settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.light(); dismiss() } label: {
                        Label(L.s("a11y.close"), systemImage: "xmark")
                    }
                    .accessibilityIdentifier("settings.close")
                }
            }
            .confirmationDialog(L.s("logoutConfirm"), isPresented: $confirmLogout, titleVisibility: .visible) {
                Button(L.s("logout"), role: .destructive) {
                    Haptics.medium()
                    dismiss()
                    model.clear() // explicit sign-out: snapshot, login and every preference go
                    CustomPlanStore.shared.delete()
                    prefs.reset() // back to the welcome screen
                }
                Button(L.s("cancel"), role: .cancel) { Haptics.light() }
            }
        }
    }
}
