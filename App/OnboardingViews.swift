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
                .font(.system(size: 32, weight: .bold))
            Text(L.s("welcomeSubtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 24)
            ContinueButton(title: L.s("continueLabel")) {
                Haptics.light()
                onContinue()
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .themeBg()
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct FeaturesScreen: View {
    let onContinue: () -> Void

    private let features: [(String, String, String)] = [
        ("calendar", "featureSubstitutionTitle", "featureSubstitutionDesc"),
        ("clock", "featureScheduleTitle", "featureScheduleDesc"),
        ("cloud", "featureWeatherTitle", "featureWeatherDesc"),
        ("newspaper", "featureNewsTitle", "featureNewsDesc"),
        ("cross.case", "featureSickTitle", "featureSickDesc"),
        ("calendar.badge.clock", "featureEventsTitle", "featureEventsDesc"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.s("infoHeader"))
                .font(.system(size: 30, weight: .bold))
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(features, id: \.1) { icon, title, desc in
                        HStack(alignment: .top, spacing: 16) {
                            IconSquare(systemName: icon, alpha: 0.1)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L.s(title)).font(.callout.weight(.semibold))
                                Text(L.s(desc))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .surfaceCard()
                    }
                }
            }
            ContinueButton(title: L.s("continueLabel")) {
                Haptics.medium()
                onContinue()
            }
        }
        .padding(16)
        .themeBg()
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct AccentColorScreen: View {
    let onContinue: () -> Void
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(L.s("accentColorTitle"))
                .font(.system(size: 30, weight: .bold))
            Text(L.s("accentColorDescription"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 16)
            HStack(spacing: 12) {
                ForEach(Accent.allCases, id: \.rawValue) { accent in
                    ColorSwatch(accent: accent,
                                isSelected: prefs.accentColor == accent.rawValue) {
                        Haptics.light()
                        prefs.accentColor = accent.rawValue
                    }
                }
            }
            Spacer()
            ContinueButton(title: L.s("continueLabel")) {
                Haptics.medium()
                onContinue()
            }
            Spacer().frame(height: 8)
        }
        .padding(16)
        .themeBg()
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ColorSwatch: View {
    let accent: Accent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 20)
                .fill(accent.color)
                .frame(width: 60, height: 60)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(.white, lineWidth: 3)
                        Image(systemName: "checkmark")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle().fill(.white.opacity(0.24))
                            .frame(width: 14, height: 14)
                    }
                }
                .shadow(color: isSelected ? accent.color.opacity(0.4) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct AppearanceScreen: View {
    let onContinue: () -> Void
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(L.s("appearanceTitle"))
                .font(.system(size: 30, weight: .bold))
            Spacer().frame(height: 8)
            ThemeModePicker(order: ["dark", "system", "light"], iconSize: 18, labels: true)
            Spacer()
            ContinueButton(title: L.s("letsGo")) {
                Haptics.medium()
                onContinue()
            }
            Spacer().frame(height: 8)
        }
        .padding(16)
        .themeBg()
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Segmented theme selector — shared by onboarding and settings.
struct ThemeModePicker: View {
    var order: [String]
    var iconSize: CGFloat
    var labels: Bool
    @EnvironmentObject private var prefs: Prefs
    @Environment(\.colorScheme) private var scheme

    private func icon(_ mode: String) -> String {
        switch mode {
        case "dark": return "moon.fill"
        case "light": return "sun.max.fill"
        default: return "circle.lefthalf.filled"
        }
    }

    private func label(_ mode: String) -> String {
        switch mode {
        case "dark": return L.s("themeDark")
        case "light": return L.s("themeLight")
        default: return L.s("themeAuto")
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(order, id: \.self) { mode in
                let isSelected = prefs.themeMode == mode
                Button {
                    Haptics.light()
                    prefs.themeMode = mode
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: icon(mode)).font(.system(size: iconSize))
                        if labels { Text(label(mode)).font(.subheadline) }
                    }
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? prefs.accent : Color.secondary)
                    .padding(.horizontal, labels ? 18 : 10)
                    .padding(.vertical, labels ? 10 : 6)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(scheme == .dark ? Color.white.opacity(0.15) : .white)
                                .shadow(color: .black.opacity(scheme == .dark ? 0.3 : 0.08),
                                        radius: 4, y: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.15), value: prefs.themeMode)
    }
}

/// Full-width accent button — the onboarding continue button.
struct ContinueButton: View {
    let title: String
    let action: () -> Void
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(prefs.accent, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: prefs.accent.opacity(0.3), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

/// Password gate — mirrors auth_screen.dart (school website credentials).
struct AuthScreen: View {
    @EnvironmentObject private var prefs: Prefs
    @Environment(\.colorScheme) private var scheme
    @State private var username = ""
    @State private var password = ""
    @State private var flash: Flash = .none
    @State private var isLoading = false
    enum Flash { case none, error, success }

    private var canLogin: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
            !password.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    private var buttonColor: Color {
        switch flash {
        case .success: return .green
        case .error: return .red
        case .none: return canLogin ? prefs.accent : prefs.accent.opacity(0.5)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text(L.s("authTitle"))
                .font(.system(size: 28, weight: .bold))
            Spacer().frame(height: 12)
            Text(L.s("authSubtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 48)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "person").foregroundStyle(.secondary)
                    TextField(L.s("username"), text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(16)
                Divider().padding(.leading, 16)
                HStack(spacing: 12) {
                    Image(systemName: "lock").foregroundStyle(.secondary)
                    SecureField(L.s("password"), text: $password)
                }
                .padding(16)
            }
            .surfaceCard()
            .frame(maxWidth: 400)

            Spacer().frame(height: 32)

            Button(action: validate) {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(L.s("login")).font(.subheadline.weight(.semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 400)
                .frame(height: 46)
                .background(buttonColor, in: RoundedRectangle(cornerRadius: 12))
                .animation(.easeInOut(duration: 0.3), value: buttonColor)
            }
            .buttonStyle(.plain)
            .disabled(!canLogin && flash == .none)
            Spacer()
        }
        .padding(.horizontal, 24)
        .themeBg()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func validate() {
        // Same gate as the Flutter app: the school website's public credentials.
        if username.trimmingCharacters(in: .whitespaces) == "vertretungsplan"
            && password.trimmingCharacters(in: .whitespaces) == "ephraim" {
            flash = .success
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
