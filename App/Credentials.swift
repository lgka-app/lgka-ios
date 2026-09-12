import Foundation
import Security

/// The school website's read-only HTTP basic-auth credentials, entered by
/// the user at login, verified against the server and stored in the
/// Keychain. Nothing in the source tree contains a password.
enum Credentials {
    private static let service = "de.lgka.school-website"
    private static let account = "basic-auth"

    struct Pair: Sendable, Equatable {
        let user: String
        let password: String

        var authorizationHeader: String {
            "Basic " + Data("\(user):\(password)".utf8).base64EncodedString()
        }
    }

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func load() -> Pair? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8),
              let sep = text.firstIndex(of: "\n") else { return nil }
        return Pair(user: String(text[..<sep]), password: String(text[text.index(after: sep)...]))
    }

    @discardableResult
    static func save(_ pair: Pair) -> Bool {
        let data = Data("\(pair.user)\n\(pair.password)".utf8)
        SecItemDelete(query as CFDictionary)
        var q = query
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    static func clear() {
        SecItemDelete(query as CFDictionary)
    }
}
