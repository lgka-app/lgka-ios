import Foundation
import os
import LGKACore

/// The saved custom plan with what it was built from, so a newer Stufenplan (or the next
/// Halbjahr) rebuilds it without scanning again. The Kurswahl holds no SchID or birth date.
struct SavedCustomPlan: Codable, Equatable, Sendable {
    var plan: CustomPlan
    var kurswahl: Kurswahl?
    /// Title of the Stufenplan link the lessons come from ("Stundenpläne - 2026/2027 - 1.HJ - J11").
    var planTitle: String?
}

/// One custom plan per device, as JSON in Application Support. Removed on sign-out.
@Observable
@MainActor
final class CustomPlanStore {
    static let shared = CustomPlanStore()
    private static let log = Logger(subsystem: "com.lgka", category: "custom-plan")

    private(set) var saved: SavedCustomPlan?
    private let url: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = base.appendingPathComponent("custom-plan.json")
        if let data = try? Data(contentsOf: url) {
            do {
                saved = try JSONDecoder().decode(SavedCustomPlan.self, from: data)
            } catch {
                Self.log.error("custom plan unreadable, starting over: \(error)")
            }
        }
    }

    func save(_ value: SavedCustomPlan) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: url, options: [.atomic, .completeFileProtection])
            saved = value
        } catch {
            Self.log.error("custom plan not saved: \(error)")
        }
    }

    func delete() {
        try? FileManager.default.removeItem(at: url)
        saved = nil
    }
}
