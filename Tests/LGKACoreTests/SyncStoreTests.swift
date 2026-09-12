import Foundation
import Testing
@testable import LGKACore

@Suite("Sync merge + persistence")
struct SyncStoreTests {
    @Test func firstLaunchStoresEverythingAndWritesPdfs() throws {
        let store = try Fixtures.tempStore()
        var state = store.loadState()
        #expect(state.hashes.isEmpty)

        let outcome = store.apply(try Fixtures.sync("sync_full"), to: &state)
        #expect(outcome.updated == Set(Resource.allCases))
        #expect(outcome.fresh.isEmpty && outcome.unavailable.isEmpty)
        #expect(state.hashes.count == 5)

        // PDFs landed on disk, base64 was stripped from the model + the persisted JSON
        let today = try #require(state.substitutions?.data.today)
        #expect(today.pdf.base64 == nil)
        #expect(store.hasPdf(sha256: today.pdf.sha256))
        let bytes = try Data(contentsOf: store.pdfURL(sha256: today.pdf.sha256))
        #expect(String(decoding: bytes.prefix(5), as: UTF8.self) == "%PDF-")
        for item in state.schedules?.data.items ?? [] {
            if let pdf = item.pdf {
                #expect(pdf.base64 == nil)
                #expect(store.hasPdf(sha256: pdf.sha256))
            }
        }
        let raw = try String(contentsOf: store.directory.appendingPathComponent("substitutions.json"), encoding: .utf8)
        #expect(!raw.contains("\"base64\""))

        // a fresh store instance reloads the same state
        let reloaded = SyncStore(directory: store.directory).loadState()
        #expect(reloaded.hashes == state.hashes)
        #expect(reloaded.news?.data.articles.count == state.news?.data.articles.count)
        #expect(reloaded.weather?.data.hourly.count == 72)
    }

    @Test func freshKeepsLocalUpdatedReplaces() throws {
        let store = try Fixtures.tempStore()
        var state = store.loadState()
        store.apply(try Fixtures.sync("sync_full"), to: &state)
        let newsBefore = state.news
        let weatherBefore = state.weather

        let outcome = store.apply(try Fixtures.sync("sync_partial"), to: &state, now: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(outcome.updated == [.weather])
        #expect(outcome.fresh == [.substitutions, .schedules, .news, .events])
        #expect(state.news?.hash == newsBefore?.hash)
        #expect(state.news?.data == newsBefore?.data)
        #expect(state.news?.storedAt == Date(timeIntervalSince1970: 1_800_000_000), "fresh renews the bookkeeping timestamp")
        #expect(state.weather?.hash == weatherBefore?.hash) // same payload in the fixture, still "updated" path
        #expect(state.weather?.storedAt == Date(timeIntervalSince1970: 1_800_000_000))
    }

    @Test func unavailableChangesNothing() throws {
        let store = try Fixtures.tempStore()
        var state = store.loadState()
        store.apply(try Fixtures.sync("sync_full"), to: &state)
        let before = state.hashes
        let outcome = store.apply(try Fixtures.sync("sync_unavailable"), to: &state)
        #expect(outcome.unavailable == Set(Resource.allCases))
        #expect(outcome.updated.isEmpty)
        #expect(state.hashes == before)
        #expect(state.substitutions != nil)
    }

    @Test func updatedWithoutDataIsTreatedAsUnavailable() throws {
        let store = try Fixtures.tempStore()
        var state = SyncState()
        let broken = SyncResponse(generatedAt: "now", resources: .init(
            substitutions: nil, schedules: nil,
            news: SyncEntry<NewsData>(status: .updated, hash: "abc", data: nil),
            events: nil, weather: nil))
        let outcome = store.apply(broken, to: &state)
        #expect(outcome.unavailable == [.news])
        #expect(state.news == nil)
    }

    @Test func hashesAreSentBackOnTheNextSync() throws {
        let store = try Fixtures.tempStore()
        var state = store.loadState()
        store.apply(try Fixtures.sync("sync_full"), to: &state)
        let query = APIClient.syncQuery(hashes: state.hashes, only: nil, embedPdf: true)
        let dict = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })
        #expect(dict["substitutions"] == state.substitutions?.hash)
        #expect(dict["weather"] == state.weather?.hash)
        #expect(dict["embed"] == "pdf")
        #expect(dict["only"] == nil)

        let onlyWeather = APIClient.syncQuery(hashes: [:], only: [.weather], embedPdf: false)
        #expect(onlyWeather.map(\.name) == ["weather", "only"])
        #expect(onlyWeather[0].value == "")
    }

    @Test func removeAllForgetsEverything() throws {
        let store = try Fixtures.tempStore()
        var state = store.loadState()
        store.apply(try Fixtures.sync("sync_full"), to: &state)
        store.removeAll()
        #expect(SyncStore(directory: store.directory).loadState().hashes.isEmpty)
    }
}
