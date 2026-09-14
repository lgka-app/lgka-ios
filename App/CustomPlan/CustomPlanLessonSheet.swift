import SwiftUI
import LGKACore

/// Details of a tapped lesson: the course, its teachers and rooms, and every lesson of the week.
struct CustomPlanLessonSheet: View {
    let plan: CustomPlan
    let lesson: CustomPlan.Lesson
    @Environment(\.dismiss) private var dismiss

    private var course: CustomPlan.Course? { plan.courses.first { $0.id == lesson.course } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(SubjectTint.color(for: course?.subject ?? lesson.course).opacity(0.3))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Text(lesson.course).font(.caption.weight(.bold)).minimumScaleFactor(0.5).padding(2)
                            }
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(course?.title ?? lesson.course).font(.headline)
                            if let course {
                                Text(L.s("plan.level.\(course.level.rawValue)")).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    Label(Self.when(lesson, in: plan), systemImage: "clock")
                }

                if let course, !course.teachers.isEmpty {
                    Section(L.s(course.teachers.count == 1 ? "plan.teacher" : "plan.teachers")) {
                        ForEach(course.teachers, id: \.code) { teacher in
                            LabeledContent(teacher.name ?? teacher.code, value: teacher.name == nil ? "" : teacher.code)
                        }
                    }
                }

                if !lesson.rooms.isEmpty {
                    Section(L.s(lesson.rooms.count == 1 ? "plan.room" : "plan.rooms")) {
                        ForEach(lesson.rooms, id: \.self) { Text($0) }
                    }
                }

                let week = plan.lessons.filter { $0.course == lesson.course }
                Section(L.f("plan.weeklyHours", week.reduce(0) { $0 + $1.hours })) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, other in
                        HStack {
                            Text(Self.when(other, in: plan))
                            Spacer()
                            Text(other.roomLabel).foregroundStyle(.secondary)
                        }
                        .fontWeight(other == lesson ? .semibold : .regular)
                    }
                }
            }
            .navigationTitle(course?.subject ?? lesson.course)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.light(); dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(L.s("a11y.close"))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// "Mo · 1.–2. Std. · 7:45–9:20".
    static func when(_ lesson: CustomPlan.Lesson, in plan: CustomPlan) -> String {
        let day = String(L.weekday(CustomPlan.dayNames[lesson.day]).prefix(2))
        let periods = lesson.start == lesson.end
            ? L.f("plan.periodSingle", lesson.start)
            : L.f("plan.periodRange", lesson.start, lesson.end)
        let start = plan.periods.first { $0.number == lesson.start }?.start ?? ""
        let end = plan.periods.first { $0.number == lesson.end }?.end ?? ""
        return "\(day) · \(periods) · \(start)–\(end)"
    }
}
