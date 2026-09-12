import Foundation
import Testing
@testable import LGKACore

/// Opt-in end-to-end check against the real API (no simulator, just HTTPS):
///   LGKA_LIVE_AUTH=user:pass swift test --filter LiveAPITests
@Suite(.enabled(if: ProcessInfo.processInfo.environment["LGKA_LIVE_AUTH"] != nil, "set LGKA_LIVE_AUTH=user:pass to run against api.lgka.app"))
struct LiveAPITests {
    private static var credentials: SchoolCredentials? {
        guard let pair = ProcessInfo.processInfo.environment["LGKA_LIVE_AUTH"],
              let sep = pair.firstIndex(of: ":") else { return nil }
        return SchoolCredentials(user: String(pair[..<sep]), password: String(pair[pair.index(after: sep)...]))
    }

    @Test func authCheckAndFullSyncRoundTrip() async throws {
        let creds = try #require(Self.credentials)
        let client = APIClient(userAgent: "LGKA-App-Luka-Loehr/3.0.0-test", credentials: { creds })
        #expect(try await client.check(creds) == true)
        #expect(try await client.check(SchoolCredentials(user: creds.user, password: "definitely-wrong")) == false)

        let store = try Fixtures.tempStore()
        var state = SyncState()
        let first = store.apply(try await client.sync(hashes: [:]), to: &state)
        #expect(first.updated == Set(Resource.allCases), "first launch receives every resource")
        let today = try #require(state.substitutions?.data.today)
        #expect(store.hasPdf(sha256: today.pdf.sha256))
        let bytes = try Data(contentsOf: store.pdfURL(sha256: today.pdf.sha256))
        #expect(bytes.count == today.pdf.bytes)
        #expect(String(decoding: bytes.prefix(5), as: UTF8.self) == "%PDF-")

        // second launch with the hashes we now hold: everything fresh, no payload
        let second = store.apply(try await client.sync(hashes: state.hashes), to: &state)
        #expect(second.fresh == Set(Resource.allCases))
        #expect(second.updated.isEmpty)
        #expect(state.weather?.data.hourly(from: WeatherWindow.localNow()).count ?? 0 > 0)
    }
}
