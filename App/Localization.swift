import Foundation

/// Minimal DE/EN string catalog — mirrors lib/l10n/app_de.arb (German is the
/// canonical wording; English mirrors app_en.arb's intent).
enum L {
    static var isGerman: Bool {
        Locale.preferredLanguages.first?.hasPrefix("de") ?? true
    }

    static func s(_ key: String) -> String {
        (isGerman ? de[key] : en[key]) ?? de[key] ?? key
    }

    static let de: [String: String] = [
        "appTitle": "LGKA+",
        "welcomeHeadline": "Willkommen!",
        "welcomeSubtitle": "Bei der neuen App fürs Lessing-Gymnasium Karlsruhe.",
        "continueLabel": "Weiter",
        "infoHeader": "Alle Funktionen im Überblick",
        "featureSubstitutionTitle": "Vertretungsplan",
        "featureSubstitutionDesc": "Aktueller Vertretungsplan für heute/morgen",
        "featureScheduleTitle": "Stundenplan",
        "featureScheduleDesc": "Stundenplan fürs 1./2. Halbjahr",
        "featureWeatherTitle": "Wetterdaten",
        "featureWeatherDesc": "Aktuelle Wetterdaten via Open-Meteo",
        "featureNewsTitle": "Neuigkeiten",
        "featureNewsDesc": "Aktuelle Neuigkeiten und Ankündigungen der Schule",
        "featureSickTitle": "Krankmeldung",
        "featureSickDesc": "Krankmeldung direkt über die App einreichen",
        "featureEventsTitle": "Schulveranstaltungen",
        "featureEventsDesc": "Alle anstehenden Schulveranstaltungen auf einen Blick",
        "accentColorTitle": "Deine Akzentfarbe",
        "accentColorDescription": "Wähle deine Lieblingsfarbe aus. Diese wird überall in der App verwendet.",
        "appearanceTitle": "Erscheinungsbild",
        "themeDark": "Dunkel", "themeLight": "Hell", "themeAuto": "Auto",
        "letsGo": "Los geht's!",
        "authTitle": "Anmeldung erforderlich",
        "authSubtitle": "Verwende die Zugangsdaten, die du bereits von der Schulwebsite kennst",
        "username": "Benutzername", "password": "Passwort", "login": "Anmelden",
        "substitutionPlan": "Vertretungsplan",
        "schedule": "Stundenplan",
        "termine": "Bevorstehende Termine",
        "news": "Neuigkeiten",
        "krankmeldung": "Krankmeldung",
        "settings": "Einstellungen",
        "today": "Heute", "tomorrow": "Morgen",
        "noInfoYet": "Noch keine Infos",
        "errorLoading": "Fehler beim Laden",
        "serverConnectionFailed": "Serververbindung fehlgeschlagen",
        "serverConnectionHint": "Möglicherweise besteht keine Internetverbindung oder es finden gerade Wartungsarbeiten am Lessing-Gymnasium statt.",
        "tryAgain": "Erneut versuchen",
        "noSchedulesAvailable": "Keine Stundenpläne verfügbar",
        "noEventsAvailable": "Keine Termine verfügbar",
        "scheduleNoClassTitle": "In welcher Klasse bist du?",
        "scheduleNoClassSub": "Tippe, um deine Klasse festzulegen",
        "setClassTitle": "Klasse eingeben",
        "setClassButton": "Speichern",
        "searchHint": "Gib deine Klasse ein",
        "loadingSchedule": "Lade Stundenplan...",
        "scheduleNotAvailable": "ist noch nicht verfügbar",
        "firstSemester": "1. Halbjahr", "secondSemester": "2. Halbjahr",
        "jahrgang11": "Jahrgang 11", "jahrgang12": "Jahrgang 12",
        "weatherPageTitle": "Wetter Karlsruhe",
        "weatherDataNotAvailable": "Wetterdaten nicht verfügbar",
        "checkInternetConnection": "Bitte prüfe deine Internetverbindung.",
        "hourlyForecastLabel": "STÜNDLICH", "threeDayForecastLabel": "3 TAGE",
        "weatherAttribution": "Wetterdaten von Open-Meteo.com",
        "weatherHumidityShort": "Luftfeuchte", "weatherWindShort": "Wind",
        "uviLow": "Niedrig", "uviMedium": "Mittel", "uviHigh": "Hoch",
        "uviVeryHigh": "Sehr hoch", "uviExtreme": "Extrem",
        "krankmeldungInfoHeader": "Hinweis zur Krankmeldung",
        "krankmeldungDisclaimer": "Die Krankmeldung wird vom Lessing-Gymnasium bereitgestellt und ist unabhängig von der LGKA+ App.",
        "krankmeldungContact": "Bei technischen Fragen oder Problemen wende dich bitte direkt an das Lessing-Gymnasium Karlsruhe.",
        "krankmeldungButton": "Zur Krankmeldung",
        "settingsSectionAppearance": "DARSTELLUNG", "settingsSectionMore": "MEHR",
        "accentColor": "Akzentfarbe",
        "bugReport": "Fehler gefunden?", "bugReportTitle": "Bug Report",
        "privacyLabel": "Datenschutzerklärung", "legalLabel": "Impressum",
        "loading": "Lädt...",
        "formLoadError": "Formular konnte nicht geladen werden",
        "formLoadErrorHint": "Bitte überprüfe deine Internetverbindung und versuche es erneut.",
        "noNewsAvailable": "Keine Neuigkeiten verfügbar",
        "openInBrowser": "Im Browser öffnen",
        "sharePdf": "PDF teilen", "searchInPdf": "Im PDF suchen",
        "cancel": "Abbrechen",
        "weitereNeuigkeiten": "Weitere Neuigkeiten",
        "mehrErfahren": "Mehr erfahren",
        "views": "Zugriffe",
    ]

    /// "Klasse {x} existiert nicht." (noResultsFound parity)
    static func noResults(_ query: String) -> String {
        isGerman ? "Klasse \(query.uppercased()) existiert nicht."
            : "Class \(query.uppercased()) does not exist."
    }

    /// "Deine Klasse wurde auf {x} geändert." (classChanged parity)
    static func classChanged(_ name: String) -> String {
        isGerman ? "Deine Klasse wurde auf \(name) geändert."
            : "Your class was changed to \(name)."
    }

    static let en: [String: String] = [
        "welcomeHeadline": "Welcome!",
        "welcomeSubtitle": "To the new app for Lessing-Gymnasium Karlsruhe.",
        "continueLabel": "Continue",
        "infoHeader": "All features at a glance",
        "featureSubstitutionTitle": "Substitution plan",
        "featureSubstitutionDesc": "Current substitution plan for today/tomorrow",
        "featureScheduleTitle": "Timetable",
        "featureScheduleDesc": "Timetable for the 1st/2nd semester",
        "featureWeatherTitle": "Weather data",
        "featureWeatherDesc": "Current weather data via Open-Meteo",
        "featureNewsTitle": "News",
        "featureNewsDesc": "Current news and announcements from the school",
        "featureSickTitle": "Sick note",
        "featureSickDesc": "Submit a sick note directly from the app",
        "featureEventsTitle": "School events",
        "featureEventsDesc": "All upcoming school events at a glance",
        "accentColorTitle": "Your accent color",
        "accentColorDescription": "Choose your favorite color. It is used everywhere in the app.",
        "appearanceTitle": "Appearance",
        "themeDark": "Dark", "themeLight": "Light", "themeAuto": "Auto",
        "letsGo": "Let's go!",
        "authTitle": "Login required",
        "authSubtitle": "Use the credentials you already know from the school website",
        "username": "Username", "password": "Password", "login": "Log in",
        "substitutionPlan": "Substitution plan",
        "schedule": "Timetable",
        "termine": "Upcoming events",
        "news": "News",
        "krankmeldung": "Sick note",
        "settings": "Settings",
        "today": "Today", "tomorrow": "Tomorrow",
        "noInfoYet": "No info yet",
        "errorLoading": "Error loading",
        "serverConnectionFailed": "Server connection failed",
        "serverConnectionHint": "You may be offline, or maintenance is being carried out at the Lessing-Gymnasium.",
        "tryAgain": "Try again",
        "noSchedulesAvailable": "No timetables available",
        "noEventsAvailable": "No events available",
        "scheduleNoClassTitle": "Which class are you in?",
        "scheduleNoClassSub": "Tap to set your class",
        "setClassTitle": "Enter class",
        "setClassButton": "Save",
        "searchHint": "Enter your class",
        "loadingSchedule": "Loading timetable...",
        "scheduleNotAvailable": "is not available yet",
        "firstSemester": "1st semester", "secondSemester": "2nd semester",
        "jahrgang11": "Year 11", "jahrgang12": "Year 12",
        "weatherPageTitle": "Weather Karlsruhe",
        "weatherDataNotAvailable": "Weather data not available",
        "checkInternetConnection": "Please check your internet connection.",
        "hourlyForecastLabel": "HOURLY", "threeDayForecastLabel": "3 DAYS",
        "weatherAttribution": "Weather data by Open-Meteo.com",
        "weatherHumidityShort": "Humidity", "weatherWindShort": "Wind",
        "uviLow": "Low", "uviMedium": "Medium", "uviHigh": "High",
        "uviVeryHigh": "Very high", "uviExtreme": "Extreme",
        "krankmeldungInfoHeader": "About the sick note",
        "krankmeldungDisclaimer": "The sick note is provided by the Lessing-Gymnasium and is independent of the LGKA+ app.",
        "krankmeldungContact": "For technical questions or problems, please contact the Lessing-Gymnasium Karlsruhe directly.",
        "krankmeldungButton": "To the sick note",
        "settingsSectionAppearance": "APPEARANCE", "settingsSectionMore": "MORE",
        "accentColor": "Accent color",
        "bugReport": "Found a bug?", "bugReportTitle": "Bug Report",
        "privacyLabel": "Privacy policy", "legalLabel": "Legal notice",
        "loading": "Loading...",
        "formLoadError": "Form could not be loaded",
        "formLoadErrorHint": "Please check your internet connection and try again.",
        "noNewsAvailable": "No news available",
        "openInBrowser": "Open in browser",
        "sharePdf": "Share PDF", "searchInPdf": "Search in PDF",
        "cancel": "Cancel",
        "weitereNeuigkeiten": "More news",
        "mehrErfahren": "Learn more",
        "views": "Views",
    ]

    /// German WMO description (WmoUtils.description) with EN fallback.
    static func wmo(_ code: Int) -> String {
        if isGerman { return Wmo.description(code) }
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51...57: return "Drizzle"
        case 61: return "Light rain"
        case 63: return "Moderate rain"
        case 65: return "Heavy rain"
        case 66, 67: return "Freezing rain"
        case 71...77: return "Snowfall"
        case 80...82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Unknown"
        }
    }
}
