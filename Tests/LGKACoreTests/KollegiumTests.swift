import Foundation
import Testing
@testable import LGKACore

@Suite("Kollegium staff list")
struct KollegiumTests {
    private static let json = """
    {
      "generatedAt": "2026-09-14T19:05:00.000Z",
      "resources": {
        "kollegium": {
          "status": "updated",
          "hash": "k1",
          "updatedAt": "2026-09-14T19:05:00.000Z",
          "data": {
            "updatedAt": "2026-09-14T19:05:00.000Z",
            "source": "https://lessing-gymnasium-karlsruhe.de/cm3/index.php/ansprechpartner/kollegium",
            "schoolYear": null,
            "staff": [
              { "code": "Xab", "lastName": "Muster", "firstName": "Erika", "title": "Dr.",
                "displayName": "Dr. Erika Muster", "subjects": ["M", "Ph"],
                "role": "abteilungsleitung", "roleLabel": "Abteilungsleiter", "roleLabels": ["Abteilungsleiter"] },
              { "code": "Xcd", "lastName": "Beispiel-Name", "firstName": "Max", "title": null,
                "displayName": "Max Beispiel-Name", "subjects": [],
                "role": "lehrkraft", "roleLabel": "Lehrerinnen & Lehrer", "roleLabels": ["Lehrerinnen & Lehrer"] }
            ]
          }
        }
      }
    }
    """

    @Test func syncStoresTheStaffListAndSendsItsHash() throws {
        let store = try Fixtures.tempStore()
        var state = store.loadState()
        let response = try JSONDecoder().decode(SyncResponse.self, from: Data(Self.json.utf8))
        let outcome = store.apply(response, to: &state)
        #expect(outcome.updated == [.kollegium])
        #expect(state.kollegium?.data.staff.count == 2)
        #expect(store.loadState().kollegium?.hash == "k1")

        // always named in the query, empty before the first sync, so the opt-in API includes it
        let first = Dictionary(uniqueKeysWithValues: APIClient.syncQuery(hashes: [:], only: nil, embedPdf: true).map { ($0.name, $0.value ?? "") })
        #expect(first["kollegium"] == "")
        let next = Dictionary(uniqueKeysWithValues: APIClient.syncQuery(hashes: state.hashes, only: nil, embedPdf: true).map { ($0.name, $0.value ?? "") })
        #expect(next["kollegium"] == "k1")
    }

    @Test func directoryResolvesKnownCodesAndKeepsUnknownOnes() throws {
        let response = try JSONDecoder().decode(SyncResponse.self, from: Data(Self.json.utf8))
        let directory = TeacherDirectory(staff: try #require(response.resources.kollegium?.data?.staff))
        #expect(directory.name("Xab") == "Dr. Erika Muster")
        #expect(directory.lastName("Xcd") == "Beispiel-Name")
        #expect(directory.name("New") == nil)
        #expect(directory.lastName("New") == "New")
    }
}
