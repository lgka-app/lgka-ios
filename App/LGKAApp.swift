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
    /// Observable mirror of "a credential pair exists in the Keychain".
    private(set) var hasCredentials: Bool
    /// Transient: the API rejected the stored login, so the login screen explains why.
    var passwordRotated = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        onboardingCompleted = defaults.bool(forKey: "onboardingCompleted")
        isAuthenticated = defaults.bool(forKey: "isAuthenticated")
        accentColor = defaults.string(forKey: "accentColor") ?? "blue"
        themeMode = defaults.string(forKey: "themeMode") ?? "system"
        krankmeldungInfoShown = defaults.bool(forKey: "krankmeldungInfoShown")
        selectedScheduleClass = defaults.string(forKey: "selectedScheduleClass") ?? ""
        hasCredentials = Credentials.load() != nil
        #if DEBUG
        // Applied here (not in the App initializer) so it acts on the very
        // instance SwiftUI installs; @State values mutated in App.init are lost.
        DebugSeed.apply(to: self)
        #endif
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
    var isSignedIn: Bool { isAuthenticated && hasCredentials }

    /// Stores the verified credentials and completes onboarding. Returns
    /// false (and changes nothing) if the Keychain refused the write.
    @discardableResult
    func signIn(_ pair: Credentials.Pair) -> Bool {
        guard Credentials.save(pair) else { return false }
        hasCredentials = true
        isAuthenticated = true
        onboardingCompleted = true
        passwordRotated = false
        return true
    }

    func signOut() {
        Credentials.clear()
        hasCredentials = false
        isAuthenticated = false
    }

    /// Fresh-install state: an explicit sign-out in Settings starts over at the
    /// welcome screen (also the seed for automated screenshots). A rotated school
    /// password uses `signOut()` instead and keeps the preferences.
    func reset() {
        signOut()
        onboardingCompleted = false
        krankmeldungInfoShown = false
        selectedScheduleClass = ""
        accentColor = "blue"
        themeMode = "system"
        passwordRotated = false
    }
}

@main
struct LGKAApp: App {
    @State private var web: WebItem?
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var prefs = Prefs()
    @State private var model = HomeModel()
    @Environment(\.scenePhase) private var scenePhase


    var body: some Scene {
        WindowGroup {
            RootView()
                .onChange(of: scenePhase) { _, phase in
                    // resume: one hash sync (fresh answers cost ~0.5 KB)
                    if phase == .active && prefs.isSignedIn {
                        Task { await model.refreshOnForeground() }
                    }
                }
                .task(id: scenePhase) {
                    // while active: re-sync every minute (substitution plans change during the day)
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(60))
                        if !Task.isCancelled && prefs.isSignedIn {
                            await model.sync()
                        }
                    }
                }
                .onChange(of: model.unauthorized) { _, rejected in
                    // the school rotated the password (confirmed by /v1/auth/check):
                    // back to the login gate; the snapshot stays on disk
                    guard rejected else { return }
                    model.unauthorized = false
                    prefs.passwordRotated = true
                    prefs.signOut()
                }
                .environment(prefs)
                .environment(model)
                .environment(\.appAccent, prefs.accent)
                // every Link / inline link in the app: tap haptic, then the app's own web
                // screen (the one the bug report uses); non-web URLs go to the system
                .environment(\.openURL, OpenURLAction { url in
                    Haptics.light()
                    guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return .systemAction }
                    web = WebItem(url: url)
                    return .handled
                })
                .sheet(item: $web) { item in
                    NavigationStack {
                        WebScreen(url: item.url.absoluteString, title: item.title)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button { Haptics.light(); web = nil } label: {
                                        Label(L.s("a11y.close"), systemImage: "xmark")
                                    }
                                }
                            }
                    }
                }
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
        if env["LGKA_DEBUG_RESET"] != nil { prefs.reset() }
        if let pair = env["LGKA_DEBUG_LOGIN"], let sep = pair.firstIndex(of: ":") {
            prefs.signIn(.init(user: String(pair[..<sep]), password: String(pair[pair.index(after: sep)...])))
        }
        if let accent = env["LGKA_DEBUG_ACCENT"] { prefs.accentColor = accent }
        if let theme = env["LGKA_DEBUG_THEME"] { prefs.themeMode = theme }
        if let cls = env["LGKA_DEBUG_CLASS"] { prefs.selectedScheduleClass = cls }
    }
}
#endif

struct WebItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
    var title: String { url.host?.replacingOccurrences(of: "www.", with: "") ?? "" }
}
