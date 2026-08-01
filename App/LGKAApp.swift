import SwiftUI

/// Persisted preferences — mirrors PreferencesManager.
final class Prefs: ObservableObject {
    @AppStorage("onboardingCompleted") var onboardingCompleted = false
    @AppStorage("isAuthenticated") var isAuthenticated = false
    @AppStorage("accentColor") var accentColor = "blue"
    @AppStorage("themeMode") var themeMode = "system"
    @AppStorage("krankmeldungInfoShown") var krankmeldungInfoShown = false
    @AppStorage("selectedScheduleClass") var selectedScheduleClass = ""

    var accent: Color { (Accent(rawValue: accentColor) ?? .blue).color }
    var colorScheme: ColorScheme? {
        switch themeMode {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
}

@main
struct LGKAApp: App {
    @StateObject private var prefs = Prefs()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(prefs)
                .environment(\.appAccent, prefs.accent)
                .tint(prefs.accent)
                .preferredColorScheme(prefs.colorScheme)
                .overlay(FireworksOverlay())
        }
    }
}

/// Route gating — mirrors main.dart's initialRoute logic, kept live.
struct RootView: View {
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        if !prefs.onboardingCompleted {
            OnboardingFlow()
        } else if !prefs.isAuthenticated {
            AuthScreen()
        } else {
            HomeScreen()
        }
    }
}
