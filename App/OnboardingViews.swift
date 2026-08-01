import SwiftUI

/// welcome -> what-you-can-do -> accent-color -> appearance -> auth
struct OnboardingFlow: View {
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeScreen { path.append("features") }
                .navigationDestination(for: String.self) { step in
                    switch step {
                    case "features":
                        FeaturesScreen { path.append("accent") }
                    case "accent":
                        AccentColorScreen { path.append("appearance") }
                    case "appearance":
                        AppearanceScreen { path.append("auth") }
                    default:
                        AuthScreen()
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
            Text(L.s("welcomeHeadline"))
                .font(.largeTitle.bold())
            Text(L.s("welcomeSubtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: L.s("continueLabel")) {
                Haptics.light()
                onContinue()
            }
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
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
}

struct AccentColorScreen: View {
    let onContinue: () -> Void
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(L.s("accentColorTitle"))
                .font(.largeTitle.bold())
            Text(L.s("accentColorDescription"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 16)
            AccentPalettePicker()
                .scaleEffect(1.3)
            Spacer()
        }
        .padding(.horizontal, 24)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: L.s("continueLabel")) {
                Haptics.medium()
                onContinue()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .navigationBarBackButtonHidden()
    }
}

/// Native palette picker bound to the accent preference.
struct AccentPalettePicker: View {
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        Picker(L.s("accentColor"), selection: $prefs.accentColor) {
            ForEach(Accent.allCases, id: \.rawValue) { accent in
                Image(systemName: prefs.accentColor == accent.rawValue
                    ? "checkmark.circle.fill" : "circle.fill")
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(accent.color)
                    .tint(accent.color)
                    .tag(accent.rawValue)
            }
        }
        .pickerStyle(.palette)
        .paletteSelectionEffect(.custom)
        .labelsHidden()
        .onChange(of: prefs.accentColor) { Haptics.light() }
    }
}

struct AppearanceScreen: View {
    let onContinue: () -> Void
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(L.s("appearanceTitle"))
                .font(.largeTitle.bold())
            ThemeModePicker()
                .frame(maxWidth: 340)
            Spacer()
        }
        .padding(.horizontal, 24)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: L.s("letsGo")) {
                Haptics.medium()
                onContinue()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .navigationBarBackButtonHidden()
    }
}

/// Native segmented control bound to the theme preference.
struct ThemeModePicker: View {
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
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

/// Password gate — native Form with content-typed fields.
struct AuthScreen: View {
    @EnvironmentObject private var prefs: Prefs
    @State private var username = ""
    @State private var password = ""
    @State private var flash: Flash = .none
    @State private var isLoading = false
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

    var body: some View {
        Form {
            Section {
                TextField(L.s("username"), text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
                SecureField(L.s("password"), text: $password)
                    .textContentType(.password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if canLogin { validate() } }
            } header: {
                VStack(spacing: 8) {
                    Text(L.s("authTitle"))
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                    Text(L.s("authSubtitle"))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                .textCase(nil)
                .foregroundStyle(.primary)
                .padding(.bottom, 24)
                .padding(.top, 40)
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
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func validate() {
        // Same gate as the Flutter app: the school website's public credentials.
        if username.trimmingCharacters(in: .whitespaces) == "vertretungsplan"
            && password.trimmingCharacters(in: .whitespaces) == "ephraim" {
            flash = .success
            focus = nil
            Haptics.intense()
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                isLoading = true
                try? await Task.sleep(for: .milliseconds(600))
                Haptics.light()
                prefs.isAuthenticated = true
                prefs.onboardingCompleted = true
            }
        } else {
            flash = .error
            Haptics.medium()
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation { flash = .none }
            }
        }
    }
}
