import SwiftUI
import UIKit

/// Orientation policy: the app is portrait-only except while a PDF is open
/// (pdf_viewer_screen parity). Main-actor isolated so the delegate and the
/// viewer agree without unsynchronized global state.
@MainActor
final class OrientationLock {
    static let shared = OrientationLock()
    var mask: UIInterfaceOrientationMask = .portrait

    func allowAll() { mask = .all }

    func restorePortrait() {
        mask = .portrait
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?)
        -> UIInterfaceOrientationMask { OrientationLock.shared.mask }
}

/// Persisted preferences — mirrors PreferencesManager. Observable so views
/// re-render on change; every write lands in UserDefaults immediately.
@Observable
@MainActor
final class Prefs {
    private let defaults: UserDefaults

    var onboardingCompleted: Bool { didSet { defaults.set(onboardingCompleted, forKey: "onboardingCompleted") } }
    var isAuthenticated: Bool { didSet { defaults.set(isAuthenticated, forKey: "isAuthenticated") } }
    var accentColor: String { didSet { defaults.set(accentColor, forKey: "accentColor") } }
    var themeMode: String { didSet { defaults.set(themeMode, forKey: "themeMode") } }
    var krankmeldungInfoShown: Bool { didSet { defaults.set(krankmeldungInfoShown, forKey: "krankmeldungInfoShown") } }
    var selectedScheduleClass: String { didSet { defaults.set(selectedScheduleClass, forKey: "selectedScheduleClass") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        onboardingCompleted = defaults.bool(forKey: "onboardingCompleted")
        isAuthenticated = defaults.bool(forKey: "isAuthenticated")
        accentColor = defaults.string(forKey: "accentColor") ?? "blue"
        themeMode = defaults.string(forKey: "themeMode") ?? "system"
        krankmeldungInfoShown = defaults.bool(forKey: "krankmeldungInfoShown")
        selectedScheduleClass = defaults.string(forKey: "selectedScheduleClass") ?? ""
    }

    var accent: Color { (Accent(rawValue: accentColor) ?? .blue).color }

    var colorScheme: ColorScheme? {
        switch themeMode {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    /// Signed in means both the flag and stored credentials exist; a
    /// missing keychain item (restored device, cleared keychain) sends the
    /// user back through the login gate instead of failing every request.
    var isSignedIn: Bool { isAuthenticated && Credentials.load() != nil }

    func signOut() {
        Credentials.clear()
        isAuthenticated = false
    }
}

@main
struct LGKAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var prefs = Prefs()
    @State private var model = HomeModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        DebugSeed.apply(to: prefs)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onChange(of: scenePhase) { _, phase in
                    // main.dart parity: substitution + weather are
                    // invalidated on background; resume force-refreshes them.
                    if phase == .active && prefs.isSignedIn {
                        Task { await model.refreshOnForeground() }
                    }
                }
                .task(id: scenePhase) {
                    // main.dart parity: 1-minute expired-cache refresh timer,
                    // only while the scene is active.
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(60))
                        if !Task.isCancelled && prefs.isSignedIn {
                            await model.loadAll()
                        }
                    }
                }
                .environment(prefs)
                .environment(model)
                .environment(\.appAccent, prefs.accent)
                .tint(prefs.accent)
                .preferredColorScheme(prefs.colorScheme)
                .overlay(FireworksOverlay())
        }
    }
}

/// Route gating — mirrors main.dart's initialRoute logic, kept live.
struct RootView: View {
    @Environment(Prefs.self) private var prefs

    var body: some View {
        if !prefs.onboardingCompleted {
            OnboardingFlow()
        } else if !prefs.isSignedIn {
            AuthScreen()
        } else {
            HomeScreen()
        }
    }
}

#if DEBUG
/// Debug builds only: seed login and preferences from launch environment
/// variables so simulator screenshots can skip onboarding, e.g.
/// `SIMCTL_CHILD_LGKA_DEBUG_LOGIN=user:pass xcrun simctl launch booted com.lgka`
/// (also LGKA_DEBUG_ACCENT=mint, LGKA_DEBUG_THEME=dark, LGKA_DEBUG_CLASS=7b).
@MainActor
enum DebugSeed {
    static func apply(to prefs: Prefs) {
        let env = ProcessInfo.processInfo.environment
        if let pair = env["LGKA_DEBUG_LOGIN"], let sep = pair.firstIndex(of: ":") {
            Credentials.save(.init(user: String(pair[..<sep]), password: String(pair[pair.index(after: sep)...])))
            prefs.isAuthenticated = true
            prefs.onboardingCompleted = true
        }
        if let accent = env["LGKA_DEBUG_ACCENT"] { prefs.accentColor = accent }
        if let theme = env["LGKA_DEBUG_THEME"] { prefs.themeMode = theme }
        if let cls = env["LGKA_DEBUG_CLASS"] { prefs.selectedScheduleClass = cls }
    }
}
#endif
