import SwiftUI
import UIKit

/// Default portrait; the PDF viewer temporarily allows rotation
/// (pdf_viewer_screen parity).
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .portrait
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?)
        -> UIInterfaceOrientationMask { Self.orientationLock }
}

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
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var prefs = Prefs()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .onChange(of: scenePhase) { _, phase in
                    // main.dart parity: subs+weather are invalidated on
                    // background, so resume force-refreshes those two
                    if phase == .active && prefs.isAuthenticated {
                        Task {
                            await HomeModel.shared.loadSubstitution(mode: .refresh)
                            await HomeModel.shared.loadWeather(mode: .refresh)
                        }
                    }
                }
                .task {
                    // main.dart parity: 1-minute expired-cache refresh timer
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(60))
                        if prefs.isAuthenticated {
                            await HomeModel.shared.loadAll()
                        }
                    }
                }
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
