import Foundation

/// Errors of the API client. `unauthorized` is a real HTTP 401 only: the
/// school rotated the password (or the user typed it wrong at onboarding).
/// A 403 (WAF, rate limit), 429 or 5xx is `badStatus` — transient, never a
/// reason to sign anyone out.
public enum APIError: Error, Sendable, Equatable {
    case notAuthenticated
    case unauthorized
    case badStatus(Int)
    case invalidResponse
    case decoding(String)

    /// Worth retrying later; the stored login is not in question.
    public var isTransient: Bool {
        switch self {
        case .badStatus, .invalidResponse: return true
        default: return false
        }
    }
}

/// What a second look at the stored credentials found after a 401.
public enum CredentialVerdict: Sendable, Equatable {
    /// `/v1/auth/check` accepted them: the 401 was a fluke, keep going.
    case valid
    /// `/v1/auth/check` also answered 401: the school rotated the password.
    case rotated
    /// The check itself failed (offline, 403, 5xx): decide nothing.
    case undetermined
}

/// School credentials as typed by the user: the only secret the app holds.
public struct SchoolCredentials: Sendable, Equatable {
    public let user: String
    public let password: String

    public init(user: String, password: String) {
        self.user = user
        self.password = password
    }

    public var authorizationHeader: String {
        "Basic " + Data("\(user):\(password)".utf8).base64EncodedString()
    }
}

/// Client for https://api.lgka.app. Stateless; credentials are looked up per
/// request so a sign-out is effective immediately.
public struct APIClient: Sendable {
    public static let productionBase = URL(string: "https://api.lgka.app")!

    public let baseURL: URL
    public let userAgent: String
    public let session: URLSession
    public let credentials: @Sendable () -> SchoolCredentials?

    public init(baseURL: URL = APIClient.productionBase,
                userAgent: String,
                session: URLSession = .shared,
                credentials: @escaping @Sendable () -> SchoolCredentials?) {
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.session = session
        self.credentials = credentials
    }

    // MARK: Requests

    /// Onboarding: `true` when the pair is accepted, `false` on 401 (wrong
    /// credentials). Anything else — 403 from the edge, 429, 5xx — throws
    /// `badStatus`: the service is unavailable, the typed password may be fine.
    public func check(_ pair: SchoolCredentials) async throws -> Bool {
        var req = request(path: "/v1/auth/check", query: [])
        req.setValue(pair.authorizationHeader, forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        switch http.statusCode {
        case 200...299: return true
        case 401: return false
        default: throw APIError.badStatus(http.statusCode)
        }
    }

    /// After a 401 on a data route: ask `/v1/auth/check` with the stored login
    /// before concluding anything. Never throws.
    public func verifyStoredCredentials() async -> CredentialVerdict {
        guard let creds = credentials() else { return .rotated }
        do {
            return try await check(creds) ? .valid : .rotated
        } catch {
            return .undetermined
        }
    }

    /// The launch/resume call. `only` restricts the resources considered;
    /// `embedPdf` inlines every mirrored PDF so plan + files is one request.
    public func sync(hashes: [Resource: String], only: [Resource]? = nil, embedPdf: Bool = true) async throws -> SyncResponse {
        let data = try await get(path: "/v1/sync", query: Self.syncQuery(hashes: hashes, only: only, embedPdf: embedPdf))
        do {
            return try JSONDecoder().decode(SyncResponse.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// A mirrored PDF by content hash (fallback when the embedded copy is missing).
    public func pdf(sha256: String) async throws -> Data {
        try await get(path: "/v1/files/\(sha256).pdf", query: [])
    }

    /// Query items for `/v1/sync`, sorted for stable URLs.
    public static func syncQuery(hashes: [Resource: String], only: [Resource]?, embedPdf: Bool) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        for resource in Resource.allCases {
            if let only, !only.contains(resource) { continue }
            items.append(URLQueryItem(name: resource.rawValue, value: hashes[resource] ?? ""))
        }
        if let only { items.append(URLQueryItem(name: "only", value: only.map(\.rawValue).joined(separator: ","))) }
        if embedPdf { items.append(URLQueryItem(name: "embed", value: "pdf")) }
        return items
    }

    // MARK: Plumbing

    private func request(path: String, query: [URLQueryItem]) -> URLRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        var req = URLRequest(url: components.url!, timeoutInterval: 20)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    private func get(path: String, query: [URLQueryItem]) async throws -> Data {
        guard let creds = credentials() else { throw APIError.notAuthenticated }
        var req = request(path: path, query: query)
        req.setValue(creds.authorizationHeader, forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        switch http.statusCode {
        case 200...299: return data
        case 401: throw APIError.unauthorized
        default: throw APIError.badStatus(http.statusCode) // 403 = WAF/rate limit, not the login
        }
    }
}
