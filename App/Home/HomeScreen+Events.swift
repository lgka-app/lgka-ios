import SwiftUI
import LGKACore

extension HomeScreen {
    // ── Events ──────────────────────────────────────────────────────────────

    @ViewBuilder var eventsSection: some View {
        if model.eventsLoading {
            ForEach(0..<4, id: \.self) { _ in skeletonRow }
        } else if model.eventsError && model.events.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary.opacity(0.5))
                    .accessibilityHidden(true)
                Text(L.s("serverConnectionFailed"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                retryButton { await model.sync(only: [.events]) }
            }
            .padding(.vertical, 8)
        } else if model.events.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "calendar").foregroundStyle(.secondary.opacity(0.4))
                    .accessibilityHidden(true)
                Text(L.s("noEventsAvailable"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
        } else {
            ForEach(model.events.prefix(4)) { event in
                HStack(spacing: 14) {
                    dateTile(event.date)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text(eventSubtitle(event))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                .accessibilityIdentifier("home.event")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L.f("a11y.event", eventSubtitle(event), event.title))
            }
        }
    }

    private func dateTile(_ iso: String) -> some View {
        let date = LocalDate.parse(iso)
        let day = date.map { Calendar.current.component(.day, from: $0) } ?? 0
        let month = date?.formatted(.dateTime.month(.abbreviated)) ?? ""
        return VStack(spacing: 0) {
            Text("\(day)").font(.title3.weight(.bold)).foregroundStyle(accent)
            Text(month).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(width: 44, height: 44)
        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }

    private func eventSubtitle(_ event: SchoolEvent) -> String {
        guard let date = LocalDate.parse(event.date) else { return event.time ?? "" }
        let base = date.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
        if let time = event.time { return "\(base) · \(time)" }
        return base
    }
}
