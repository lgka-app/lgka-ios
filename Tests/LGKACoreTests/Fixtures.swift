import Foundation
import Testing
@testable import LGKACore

/// Recorded responses of https://api.lgka.app (2026-09-12). Embedded PDFs are
/// replaced by a few stub bytes so the fixtures stay small.
enum Fixtures {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
                               "missing fixture \(name).json")
        return try Data(contentsOf: url)
    }

    static func sync(_ name: String) throws -> SyncResponse {
        try JSONDecoder().decode(SyncResponse.self, from: data(name))
    }

    static func tempStore() throws -> SyncStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lgka-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return SyncStore(directory: dir)
    }
}
