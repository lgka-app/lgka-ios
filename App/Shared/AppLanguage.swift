import Foundation
import Observation

/// The app's language: the system's, or German / English picked in Settings. Every string goes through
/// `L`, which reads this, so every view that shows text re-renders at once when it changes
/// (Observation tracks the read). Readable from any thread.
final class AppLanguage: Observable, @unchecked Sendable {
    static let shared = AppLanguage()
    static let supported = ["de", "en"]

    private let registrar = ObservationRegistrar()
    private let lock = NSLock()
    private var storedCode: String?
    private var storedBundle: Bundle

    private init() {
        let code = UserDefaults.standard.string(forKey: "appLanguage").flatMap { Self.supported.contains($0) ? $0 : nil }
        storedCode = code
        storedBundle = Self.bundle(for: code)
    }

    /// "de" / "en" when picked in Settings, nil for the system language.
    var code: String? {
        registrar.access(self, keyPath: \.code)
        return lock.withLock { storedCode }
    }

    /// The localization bundle strings are looked up in.
    var bundle: Bundle {
        registrar.access(self, keyPath: \.code)
        return lock.withLock { storedBundle }
    }

    /// The language actually shown: "de" or "en".
    var effective: String {
        code ?? (Bundle.main.preferredLocalizations.first?.hasPrefix("de") == true ? "de" : "en")
    }

    /// Dates and numbers in the picked language, keeping the device's region.
    var locale: Locale {
        guard let code else { return .autoupdatingCurrent }
        return Locale(identifier: "\(code)_\(Locale.current.region?.identifier ?? "DE")")
    }

    func set(_ code: String?) {
        let value = code.flatMap { Self.supported.contains($0) ? $0 : nil }
        registrar.withMutation(of: self, keyPath: \.code) {
            lock.withLock {
                storedCode = value
                storedBundle = Self.bundle(for: value)
            }
        }
        if let value {
            UserDefaults.standard.set(value, forKey: "appLanguage")
        } else {
            UserDefaults.standard.removeObject(forKey: "appLanguage")
        }
    }

    private static func bundle(for code: String?) -> Bundle {
        guard let code, let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}
