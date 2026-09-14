import Foundation
import LGKACore
import LGKAPlanKit

/// The custom plan's words in the app language: course titles, Halbjahr names and the PDF's labels.
/// Subject names and the school's own data stay as the school prints them.
enum CustomPlanLabels {
    /// A subject in the app language ("Mathematik" / "Maths"); religion by the course's stem (kR / eR).
    static func subject(key: String, code: String? = nil) -> String {
        if key == "Rel", let stem = code.flatMap(CourseCode.init)?.stem, stem == "kr" || stem == "er" {
            return L.s("subject.Rel.\(stem)")
        }
        let value = L.s("subject.\(key)")
        return value == "subject.\(key)" ? (SchoolReference.subject(key)?.name ?? key) : value
    }

    static func subject(_ course: CustomPlan.Course) -> String {
        subject(key: course.subjectKey, code: course.codes.first)
    }

    /// "1. Halbjahr" (school data) → "1. Halbjahr" / "1st semester".
    static func halbjahr(_ value: String) -> String {
        if value.hasPrefix("1") { return L.s("firstSemester") }
        if value.hasPrefix("2") { return L.s("secondSemester") }
        return value
    }

    /// "Mathematik (LF, M3)", "Gemeinschaftskunde (LF)", "Sport (s1 / s2 / s3)" with the level in the app language.
    static func title(_ course: CustomPlan.Course) -> String {
        if course.codes.count > 1 { return "\(subject(course)) (\(course.codes.joined(separator: " / ")))" }
        let code = course.codes.first ?? course.id
        switch course.level {
        case .leistungsfach:
            let level = L.s("custom.level.short.LF")
            return CourseCode(code)?.number != nil ? "\(subject(course)) (\(level), \(code))" : "\(subject(course)) (\(level))"
        case .basisfach:
            return "\(subject(course)) (\(code))"
        }
    }

    @MainActor
    static var pdf: CustomPlanPDF.Labels {
        let schoolYear = L.s("custom.pdf.schoolYear"), stand = L.s("custom.pdf.stand"), room = L.s("custom.pdf.room")
        let footer = L.s("custom.pdf.footer"), note = L.s("custom.pdf.sharedSlots")
        return CustomPlanPDF.Labels(
            title: L.s("custom.pdf.title"),
            schoolYear: { String(format: schoolYear, $0) },
            stand: { String(format: stand, $0) },
            room: { String(format: room, $0) },
            days: CustomPlan.dayNames.map { L.weekday($0) },
            halbjahr: { halbjahr($0) },
            footer: { String(format: footer, $0) },
            courseTitle: { title($0) },
            sharedSlotsNote: { course in
                String(format: note, subject(course), course.codes.joined(separator: " / "))
            })
    }
}
