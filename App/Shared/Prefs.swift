import SwiftUI
import LGKACore

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
        AppLanguage.shared.set(nil)
        passwordRotated = false
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
        // seeded before any timetable is loaded, so it can only be normalised, not validated
        if let cls = env["LGKA_DEBUG_CLASS"] { prefs.selectedScheduleClass = ScheduleClasses.normalize(cls) }
    }
}
#endif
