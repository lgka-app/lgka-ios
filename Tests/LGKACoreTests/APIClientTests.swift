import Foundation
import Testing
@testable import LGKACore

/// In-memory HTTP: every request is answered by `handler`, no network.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, body) = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeClient(credentials: SchoolCredentials?) -> APIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return APIClient(userAgent: "LGKA+/test", session: URLSession(configuration: config), credentials: { credentials })
}

private let creds = SchoolCredentials(user: "user", password: "pw")

@Suite("API client", .serialized)
struct APIClientTests {
    @Test func authCheckAcceptsAndRejects() async throws {
        let client = makeClient(credentials: nil)
        MockURLProtocol.handler = { req in
            #expect(req.url?.path == "/v1/auth/check")
            #expect(req.value(forHTTPHeaderField: "Authorization") == "Basic dXNlcjpwdw==")
            #expect(req.value(forHTTPHeaderField: "User-Agent") == "LGKA+/test")
            return (204, Data())
        }
        #expect(try await client.check(creds) == true)
        MockURLProtocol.handler = { _ in (401, Data(#"{"error":"unauthorized"}"#.utf8)) }
        #expect(try await client.check(creds) == false)
        MockURLProtocol.handler = { _ in (503, Data()) }
        await #expect(throws: APIError.badStatus(503)) { try await client.check(creds) }
    }

    @Test func syncSendsHashesAndDecodes() async throws {
        let client = makeClient(credentials: creds)
        let body = try Fixtures.data("sync_partial")
        MockURLProtocol.handler = { req in
            let comps = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)!
            let q = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            #expect(comps.path == "/v1/sync")
            #expect(q["news"] == "abc123")
            #expect(q["weather"] == "")
            #expect(q["embed"] == "pdf")
            #expect(req.value(forHTTPHeaderField: "Authorization") == creds.authorizationHeader)
            return (200, body)
        }
        let response = try await client.sync(hashes: [.news: "abc123"])
        #expect(response.resources.news?.status == .fresh)
        #expect(response.resources.weather?.status == .updated)
    }

    @Test func unauthorizedIsSurfacedAsSuch() async throws {
        let client = makeClient(credentials: creds)
        MockURLProtocol.handler = { _ in (401, Data(#"{"error":"unauthorized"}"#.utf8)) }
        await #expect(throws: APIError.unauthorized) { try await client.sync(hashes: [:]) }
        // the WAF answers data routes with 403 for bad credentials; same meaning for the app
        MockURLProtocol.handler = { _ in (403, Data("blocked".utf8)) }
        await #expect(throws: APIError.unauthorized) { try await client.pdf(sha256: String(repeating: "a", count: 64)) }
    }

    @Test func missingCredentialsNeverHitTheNetwork() async throws {
        let client = makeClient(credentials: nil)
        MockURLProtocol.handler = { _ in
            Issue.record("request was sent without credentials")
            return (500, Data())
        }
        await #expect(throws: APIError.notAuthenticated) { try await client.sync(hashes: [:]) }
    }

    @Test func malformedBodyIsADecodingError() async throws {
        let client = makeClient(credentials: creds)
        MockURLProtocol.handler = { _ in (200, Data("not json".utf8)) }
        do {
            _ = try await client.sync(hashes: [:])
            Issue.record("expected a decoding error")
        } catch let APIError.decoding(detail) {
            #expect(!detail.isEmpty)
        }
    }
}
