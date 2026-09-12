import SwiftUI
import LGKACore

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
        Button { Haptics.medium(); action() } label: {
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

/// Login gate — the school's credentials are verified by the API
/// (`/v1/auth/check`) and stored in the Keychain; the app never compares them
/// locally and never sends them anywhere but api.lgka.app.
struct AuthScreen: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.appAccent) private var accent
    @State private var username = ""
    @State private var password = ""
    @State private var flash: Flash = .none
    @State private var isLoading = false
    @State private var hint: String?
    @FocusState private var focus: Field?
    enum Flash { case none, error, success }
    enum Field { case username, password }

    private var canLogin: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
            !password.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    /// auth_screen.dart: red / green flashes, half-opacity accent while a field is empty.
    private var buttonTint: Color {
        switch flash {
        case .success: return Color(red: 0.30, green: 0.69, blue: 0.31)
        case .error: return Color(red: 0.96, green: 0.26, blue: 0.21)
        case .none: return canLogin || isLoading ? accent : accent.opacity(0.5)
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

    /// A secure field alone is enough for iOS to offer "Save Password?" after a login (iPad
    /// shows it even without a content type), so the screenshot run uses a plain field. The
    /// login form itself is never captured.
    @ViewBuilder private var passwordField: some View {
        if autoFillEnabled {
            SecureField(L.s("password"), text: $password)
                .textContentType(.password)
        } else {
            TextField(L.s("password"), text: $password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    var body: some View {
        // Centred in whatever height the keyboard leaves: the safe area shrinks when the
        // keyboard shows, the geometry follows, and the form glides up (native avoidance).
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: 12) {
                        Text(L.s("authTitle"))
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(L.s("authSubtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 32)

                    VStack(spacing: 0) {
                        field(L.s("username"), systemImage: "person") {
                            TextField(L.s("username"), text: $username)
                                .textContentType(autoFillEnabled ? .username : nil)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focus, equals: .username)
                                .submitLabel(.next)
                                .onSubmit { focus = .password }
                                .accessibilityIdentifier("auth.username")
                        }
                        Divider().padding(.leading, 52)
                        field(L.s("password"), systemImage: "lock") {
                            passwordField
                                .focused($focus, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { if canLogin { validate() } }
                                .accessibilityIdentifier("auth.password")
                        }
                    }
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if let hint {
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    }

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
                    .animation(.easeInOut(duration: 0.3), value: canLogin)
                    .accessibilityIdentifier("auth.login")
                    .padding(.top, 24)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .frame(minHeight: geometry.size.height)
                .readableWidth(560)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .themeBg()
        .animation(.easeOut(duration: 0.25), value: focus)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // the API rejected the stored login: the school rotated the password
            if prefs.passwordRotated { hint = L.s("login.passwordChanged") }
        }
    }

    private func field<Content: View>(_ label: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            content()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    /// auth_screen.dart timing: 300 ms into the colour, 600 ms hold, 300 ms back. No error text.
    private func validate() {
        guard canLogin, flash == .none else { return }
        Haptics.medium()
        let pair = Credentials.Pair(user: username.trimmingCharacters(in: .whitespaces),
                                    password: password.trimmingCharacters(in: .whitespaces))
        focus = nil
        isLoading = true
        Task {
            do {
                let ok = try await SchoolAPI.verify(pair)
                isLoading = false
                if ok {
                    flash = .success
                    Haptics.success()
                    try? await Task.sleep(for: .milliseconds(900))
                    if !prefs.signIn(pair) { fail() }
                } else {
                    fail()
                }
            } catch {
                // offline, 403 from the edge, 429, 5xx: the same calm red, no text
                isLoading = false
                fail()
            }
        }
    }

    private func fail() {
        flash = .error
        Haptics.error()
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            flash = .none
        }
    }
}
