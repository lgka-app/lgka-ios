import Foundation
import LGKACore

/// Thin wrapper over the String Catalog (App/Localizable.xcstrings).
/// German is the source language; English is the second localization.
/// Keys are stable identifiers, not the German text.
enum L {
    /// In the app language (Settings), which re-renders every view reading it when it changes.
    static func s(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: AppLanguage.shared.bundle)
    }

    static func f(_ key: String, _ args: any CVarArg...) -> String {
        String(format: s(key), locale: AppLanguage.shared.locale, arguments: args)
    }

    /// Localized weekday for a German Untis weekday name ("Montag").
    static func weekday(_ german: String) -> String { s("weekday.\(german)") }

    /// "Klasse 7b" / "Jahrgang 11".
    static func className(_ cls: String) -> String {
        if let grade = ScheduleGrades.gradeOf(cls), cls.lowercased().hasPrefix("j") {
            return f("jahrgang.named", grade)
        }
        let name = cls.prefix(1).uppercased() + cls.dropFirst()
        return f("class.named", name)
    }
}
