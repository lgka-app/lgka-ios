import Foundation

// MARK: - Events

public struct EventsData: Codable, Hashable, Sendable {
    public var events: [SchoolEvent]
    public var horizonWeeks: Int

    public init(events: [SchoolEvent], horizonWeeks: Int = 3) {
        self.events = events
        self.horizonWeeks = horizonWeeks
    }
}

public struct SchoolEvent: Codable, Hashable, Sendable, Identifiable {
    public var id: String { "\(date)|\(title)" }
    /// YYYY-MM-DD
    public var date: String
    /// "HH:MM" or nil for all-day events.
    public var time: String?
    public var title: String
}
