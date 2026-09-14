import SwiftUI
import LGKACore

/// The week as Untis draws it, but readable on a phone: Mo–Fr columns, a slim period rail,
/// double periods as one tall cell, labelled gaps for the big breaks and a "now" line.
struct CustomPlanGrid: View {
    let plan: CustomPlan
    let onSelect: (CustomPlan.Lesson) -> Void
    @Environment(\.appAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let railWidth: CGFloat = 40
    private let headerHeight: CGFloat = 30
    private let rowHeight: CGFloat = 54
    private let breakHeight: CGFloat = 18
    private let gap: CGFloat = 4

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = BerlinClock(date: context.date)
            GeometryReader { geo in
                let columnWidth = max(40, (geo.size.width - railWidth - gap * 5) / 5)
                ZStack(alignment: .topLeading) {
                    headers(columnWidth: columnWidth, today: now.weekday)
                    rail
                    gridLines(width: geo.size.width)
                    ForEach(Array(plan.lessons.enumerated()), id: \.offset) { _, lesson in
                        cell(lesson, columnWidth: columnWidth, current: now.isDuring(lesson, in: plan))
                    }
                    if let y = nowY(now) {
                        nowLine(y: y, width: geo.size.width, columnWidth: columnWidth, day: now.weekday ?? 0)
                    }
                }
            }
            .frame(height: totalHeight)
        }
    }

    // MARK: Layout

    private var totalHeight: CGFloat {
        guard let last = plan.periods.last else { return headerHeight }
        return top(of: last.number) + rowHeight
    }

    /// Top edge of a period row, below the header and any breaks before it.
    private func top(of period: Int) -> CGFloat {
        let breaksBefore = plan.breaks.filter { $0.after < period }.count
        return headerHeight + CGFloat(period - 1) * rowHeight + CGFloat(breaksBefore) * breakHeight
    }

    private func x(ofDay day: Int, columnWidth: CGFloat) -> CGFloat {
        railWidth + gap + CGFloat(day) * (columnWidth + gap)
    }

    // MARK: Pieces

    private func headers(columnWidth: CGFloat, today: Int?) -> some View {
        ForEach(0..<5, id: \.self) { day in
            let isToday = day == today
            let name = L.weekday(CustomPlan.dayNames[day])
            Text(columnWidth > 110 ? name : String(name.prefix(2)))
                .font(.subheadline.weight(isToday ? .bold : .semibold))
                .foregroundStyle(isToday ? accent : .secondary)
                .frame(width: columnWidth, height: headerHeight - 6)
                .background {
                    if isToday { Capsule().fill(accent.opacity(0.14)) }
                }
                .offset(x: x(ofDay: day, columnWidth: columnWidth))
                .accessibilityAddTraits(isToday ? .isSelected : [])
        }
    }

    private var rail: some View {
        ForEach(plan.periods, id: \.number) { period in
            VStack(spacing: 1) {
                Text("\(period.number)").font(.caption.weight(.bold)).monospacedDigit()
                Text(period.start).font(.system(size: 8)).monospacedDigit().foregroundStyle(.secondary)
            }
            .frame(width: railWidth, height: rowHeight)
            .offset(y: top(of: period.number))
            .accessibilityHidden(true)
        }
    }

    private func gridLines(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(plan.periods, id: \.number) { period in
                Rectangle()
                    .fill(Color.primary.opacity(SchoolReference.blockStarts.contains(period.number) ? 0.1 : 0.04))
                    .frame(width: width - railWidth, height: 0.5)
                    .offset(x: railWidth, y: top(of: period.number))
            }
            ForEach(plan.breaks, id: \.after) { pause in
                Text(L.f("plan.break", pause.start, pause.end))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: width - railWidth, height: breakHeight)
                    .offset(x: railWidth, y: top(of: pause.after) + rowHeight)
                    .accessibilityHidden(true)
            }
        }
    }

    private func cell(_ lesson: CustomPlan.Lesson, columnWidth: CGFloat, current: Bool) -> some View {
        let course = plan.courses.first { $0.id == lesson.course }
        let y = top(of: lesson.start) + gap / 2
        let height = top(of: lesson.end) + rowHeight - top(of: lesson.start) - gap
        let tint = SubjectTint.color(for: course?.subject ?? lesson.course)
        let wide = columnWidth > 110
        let label = wide ? (course?.subject ?? lesson.course) : (course?.codes.count ?? 0) > 1 ? (course?.subject ?? lesson.course) : lesson.course
        return Button {
            Haptics.light()
            onSelect(lesson)
        } label: {
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: wide ? 12 : 11.5, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if wide, let course, course.codes.count == 1 {
                    Text(lesson.course).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                }
                if !lesson.rooms.isEmpty {
                    Text(lesson.roomLabel)
                        .font(.system(size: 9.5, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if height > rowHeight, let teacher = lesson.teachers.first {
                    Text(lesson.teachers.count > 1 ? "\(teacher) +\(lesson.teachers.count - 1)" : teacher)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 3)
            .frame(width: columnWidth, height: height)
            .background(tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(current ? accent : tint.opacity(0.35), lineWidth: current ? 2 : 0.75)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .offset(x: x(ofDay: lesson.day, columnWidth: columnWidth), y: y)
        .accessibilityLabel(accessibilityLabel(lesson, course: course))
        .accessibilityHint(L.s("plan.a11y.hint"))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: current)
    }

    private func nowLine(y: CGFloat, width: CGFloat, columnWidth: CGFloat, day: Int) -> some View {
        let dayX = x(ofDay: day, columnWidth: columnWidth)
        return ZStack(alignment: .leading) {
            Rectangle().fill(accent.opacity(0.35)).frame(width: width - railWidth, height: 1)
                .offset(x: railWidth)
            Rectangle().fill(accent).frame(width: columnWidth, height: 2)
                .offset(x: dayX)
            Circle().fill(accent).frame(width: 7, height: 7)
                .offset(x: dayX - 3.5)
        }
        .offset(y: y - 3.5)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Where the current minute is, during school hours on a weekday.
    private func nowY(_ now: BerlinClock) -> CGFloat? {
        guard now.weekday != nil else { return nil }
        for (index, period) in plan.periods.enumerated() {
            guard let start = Minutes.parse(period.start), let end = Minutes.parse(period.end) else { continue }
            if now.minutes >= start, now.minutes <= end {
                return top(of: period.number) + rowHeight * CGFloat(now.minutes - start) / CGFloat(max(1, end - start))
            }
            // between two periods (change or break): the gap after this one
            if index + 1 < plan.periods.count, let nextStart = Minutes.parse(plan.periods[index + 1].start),
               now.minutes > end, now.minutes < nextStart {
                return top(of: period.number) + rowHeight + (top(of: period.number + 1) - top(of: period.number) - rowHeight) / 2
            }
        }
        return nil
    }

    private func accessibilityLabel(_ lesson: CustomPlan.Lesson, course: CustomPlan.Course?) -> String {
        let day = L.weekday(CustomPlan.dayNames[lesson.day])
        let periods = lesson.start == lesson.end
            ? L.f("plan.a11y.periodSingle", lesson.start)
            : L.f("plan.a11y.periodRange", lesson.start, lesson.end)
        let what = course.map { "\($0.subject) \(L.s("plan.level.\($0.level.rawValue)")) \($0.codes.joined(separator: ", "))" } ?? lesson.course
        let room = lesson.rooms.isEmpty ? "–" : lesson.roomLabel
        return L.f("plan.a11y.lesson", day, periods, what, room, course?.teacherLabel ?? "")
    }
}

// MARK: - Helpers

/// A soft, stable colour per subject: the hue comes from a hash of the name, saturation and
/// brightness are fixed, so every subject keeps its colour and none shouts.
enum SubjectTint {
    static func color(for subject: String) -> Color {
        // FNV-1a: stable across launches (Hasher is seeded per process)
        var hash: UInt32 = 2_166_136_261
        for byte in subject.utf8 { hash = (hash ^ UInt32(byte)) &* 16_777_619 }
        let hue = Double(hash % 360) / 360
        return Color(hue: hue, saturation: 0.55, brightness: 0.82)
    }
}

enum Minutes {
    /// "7:45" → 465.
    static func parse(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }
}

/// The school's clock: Berlin weekday (0 = Montag, nil at the weekend) and minutes since midnight.
struct BerlinClock {
    let weekday: Int?
    let minutes: Int

    init(date: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        let index = ((parts.weekday ?? 1) + 5) % 7 // Sunday = 1 → 6, Monday = 2 → 0
        weekday = index < 5 ? index : nil
        minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    func isDuring(_ lesson: CustomPlan.Lesson, in plan: CustomPlan) -> Bool {
        guard weekday == lesson.day,
              let start = plan.periods.first(where: { $0.number == lesson.start }).flatMap({ Minutes.parse($0.start) }),
              let end = plan.periods.first(where: { $0.number == lesson.end }).flatMap({ Minutes.parse($0.end) })
        else { return false }
        return minutes >= start && minutes <= end
    }
}
