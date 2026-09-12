import SwiftUI

/// welcome -> what-you-can-do -> accent-color -> appearance -> auth
struct OnboardingFlow: View {
    @State private var path: [Step] = []

    enum Step: Hashable { case features, accent, appearance, auth }

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeScreen { path.append(.features) }
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .features: FeaturesScreen { path.append(.accent) }
                    case .accent: AccentColorScreen { path.append(.appearance) }
                    case .appearance: AppearanceScreen { path.append(.auth) }
                    case .auth: AuthScreen()
                    }
                }
        }
    }
}

/// Native full-width prominent button used across onboarding.
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }
}

struct WelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("OnboardingLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .accessibilityHidden(true)
            Text(L.s("welcomeHeadline"))
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text(L.s("welcomeSubtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .readableWidth(560)
        .padding(.horizontal, 32)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: L.s("continueLabel")) {
                Haptics.light()
                onContinue()
            }
            .accessibilityIdentifier("onboarding.continue")
            .padding(.horizontal, 32)
            .padding(.bottom, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct FeaturesScreen: View {
    let onContinue: () -> Void
    @Environment(\.appAccent) private var accent

    private let features: [(String, String, String)] = [
        ("calendar", "featureSubstitutionTitle", "featureSubstitutionDesc"),
        ("clock", "featureScheduleTitle", "featureScheduleDesc"),
        ("cloud.sun", "featureWeatherTitle", "featureWeatherDesc"),
        ("newspaper", "featureNewsTitle", "featureNewsDesc"),
        ("cross.case", "featureSickTitle", "featureSickDesc"),
        ("calendar.badge.clock", "featureEventsTitle", "featureEventsDesc"),
    ]

    var body: some View {
        List {
            ForEach(features, id: \.1) { icon, title, desc in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.s(title)).font(.body.weight(.medium))
                        Text(L.s(desc)).font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: icon).foregroundStyle(accent)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.s("infoHeader"))
        .navigationBarBackButtonHidden()
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: L.s("continueLabel")) {
                Haptics.medium()
                onContinue()
            }
            .accessibilityIdentifier("onboarding.continue")
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
}

struct AccentColorScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(L.s("accentColorTitle"))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(L.s("accentColorDescription"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 16)
            AccentPalettePicker()
                .scaleEffect(1.3)
            Spacer()
        }
        .readableWidth(560)
        .padding(.horizontal, 24)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: L.s("continueLabel")) {
                Haptics.medium()
                onContinue()
            }
            .accessibilityIdentifier("onboarding.continue")
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .navigationBarBackButtonHidden()
    }
}

/// Native palette picker bound to the accent preference.
struct AccentPalettePicker: View {
    @Environment(Prefs.self) private var prefs

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Accent.allCases) { accent in
                let selected = prefs.accentColor == accent.rawValue
                Button {
                    guard !selected else { return }
                    prefs.accentColor = accent.rawValue
                    Haptics.light()
                } label: {
                    Circle()
                        .fill(accent.color)
                        .frame(width: 30, height: 30)
                        .overlay {
                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .overlay(Circle().strokeBorder(.primary.opacity(selected ? 0.3 : 0), lineWidth: 2))
                        .frame(width: 44, height: 44) // HIG minimum hit target
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accent.label)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
                .animation(.snappy(duration: 0.2), value: selected)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L.s("accentColor"))
    }
}

struct AppearanceScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(L.s("appearanceTitle"))
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            ThemeModePicker()
                .frame(maxWidth: 340)
            Spacer()
        }
        .readableWidth(560)
        .padding(.horizontal, 24)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: L.s("letsGo")) {
                Haptics.medium()
                onContinue()
            }
            .accessibilityIdentifier("onboarding.continue")
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .navigationBarBackButtonHidden()
    }
}

/// Native segmented control bound to the theme preference.
struct ThemeModePicker: View {
    @Environment(Prefs.self) private var prefs

    var body: some View {
        @Bindable var prefs = prefs
        Picker(L.s("appearanceTitle"), selection: $prefs.themeMode) {
            Label(L.s("themeDark"), systemImage: "moon.fill").tag("dark")
            Label(L.s("themeAuto"), systemImage: "circle.lefthalf.filled").tag("system")
            Label(L.s("themeLight"), systemImage: "sun.max.fill").tag("light")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .onChange(of: prefs.themeMode) { Haptics.light() }
    }
}

/// Login gate — the school website's credentials are verified against the
/// server and stored in the Keychain; the app never compares them locally.
struct AuthScreen: View {
    @Environment(Prefs.self) private var prefs
    @State private var username = ""
    @State private var password = ""
    @State private var flash: Flash = .none
    @State private var isLoading = false
    @State private var message: String?
    @FocusState private var focus: Field?
    enum Flash { case none, error, success }
    enum Field { case username, password }

    private var canLogin: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
            !password.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    private var buttonTint: Color? {
        switch flash {
        case .success: return .green
        case .error: return .red
        case .none: return nil
        }
    }

    /// Password AutoFill is always on in release builds. The screenshot suite
    /// disables it (LGKA_DEBUG_NO_AUTOFILL) so the system "Save Password?" sheet
    /// never covers a capture.
    private var autoFillEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["LGKA_DEBUG_NO_AUTOFILL"] == nil
        #else
        true
        #endif
    }

    var body: some View {
        Form {
            Section {
                TextField(L.s("username"), text: $username)
                    .accessibilityIdentifier("auth.username")
                    .textContentType(autoFillEnabled ? .username : nil)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
                SecureField(L.s("password"), text: $password)
                    .accessibilityIdentifier("auth.password")
                    .textContentType(autoFillEnabled ? .password : nil)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if canLogin { validate() } }
            } header: {
                VStack(spacing: 8) {
                    Text(L.s("authTitle"))
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .accessibilityAddTraits(.isHeader)
                    Text(L.s("authSubtitle"))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                .textCase(nil)
                .foregroundStyle(.primary)
                .padding(.bottom, 24)
                .padding(.top, 40)
            } footer: {
                if let message {
                    Text(message)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }

            Section {
                Button(action: validate) {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else if flash == .success {
                            Image(systemName: "checkmark")
                        } else {
                            Text(L.s("login")).fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(buttonTint)
                .disabled(!canLogin && flash == .none)
                .animation(.easeInOut(duration: 0.3), value: flash)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .accessibilityLabel(L.s("login"))
                .accessibilityIdentifier("auth.login")
            }
        }
        .readableWidth()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func validate() {
        let pair = Credentials.Pair(user: username.trimmingCharacters(in: .whitespaces),
                                    password: password.trimmingCharacters(in: .whitespaces))
        focus = nil
        isLoading = true
        message = nil
        Task {
            defer { isLoading = false }
            do {
                if try await SchoolAPI.verify(pair) {
                    flash = .success
                    Haptics.success()
                    try? await Task.sleep(for: .milliseconds(400))
                    if !prefs.signIn(pair) { fail(L.s("login.storeFailed")) }
                } else {
                    fail(L.s("login.failed"))
                }
            } catch {
                fail(L.s("login.offline"))
            }
        }
    }

    private func fail(_ text: String) {
        flash = .error
        message = text
        Haptics.error()
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation { flash = .none }
        }
    }
}
