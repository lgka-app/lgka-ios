import SwiftUI

struct EventsView: View {
    var body: some View {
        NavigationStack {
            LoadableView(load: { try await SchoolAPI.events() }) { events in
                if events.isEmpty {
                    ContentUnavailableView("Keine Termine",
                        systemImage: "calendar.badge.checkmark",
                        description: Text("In den nächsten drei Wochen stehen keine Termine an."))
                } else {
                    List {
                        let days = Dictionary(grouping: events, by: \.date)
                        ForEach(days.keys.sorted(), id: \.self) { day in
                            Section(germanDayLabel(day)) {
                                ForEach(days[day] ?? []) { event in
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        Text(event.time ?? "Ganztägig")
                                            .font(.caption.weight(.semibold).monospacedDigit())
                                            .foregroundStyle(event.time == nil ? .secondary : .primary)
                                            .frame(width: 64, alignment: .leading)
                                        Text(event.title)
                                            .font(.subheadline)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Termine")
        }
    }
}
