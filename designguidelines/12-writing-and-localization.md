# Writing and Localization

| | |
|---|---|
| **Last updated** | 2026-09-12 |
| **Applies to** | LGKA+ iOS (iOS 26, Swift 6.3, Xcode 26.6) |
| **Owner** | Luka Löhr |
| **Status** | Adopted |

---

## 1. Setup

| Fact | Value |
|---|---|
| Source language | German (`developmentLanguage: de` in [`project.yml`](../project.yml)) |
| Second localization | English |
| Catalog | [`App/Localizable.xcstrings`](../App/Localizable.xcstrings) — 164 keys |
| Access | `L.s(_:)` and `L.f(_:_:)` in [`App/Localization.swift`](../App/Localization.swift) |
| Symbol generation | `STRING_CATALOG_GENERATE_SYMBOLS: NO`; `SWIFT_EMIT_LOC_STRINGS: YES` |

German first is correct here — the school is in Karlsruhe, the substitution plans arrive in German,
and writing English first would have produced translated-sounding German.

```swift
/// Thin wrapper over the String Catalog (App/Localizable.xcstrings).
/// German is the source language; English is the second localization.
/// Keys are stable identifiers, not the German text.
enum L {
    static func s(_ key: String) -> String { … }
    static func f(_ key: String, _ args: any CVarArg...) -> String { … }
}
```

**Keys are identifiers, not English.** `scheduleNoClassTitle`, not `"Which class are you in?"`. That
means rewording a string never breaks a lookup, and no screen ever falls back to a raw key.

---

## 2. Voice

The app addresses one audience: pupils at one school.

| Decision | Evidence |
|---|---|
| **German informal `du`** | „In welcher Klasse bist du?", „Tippe, um deine Klasse festzulegen", „Wähle deine Lieblingsfarbe aus." |
| **Never `Sie`** | No string in the catalog uses the formal address |
| **No `wir`** | No string says „wir". Errors are stated impersonally: „Serververbindung fehlgeschlagen" |
| **Sparing possessives** | „Deine Akzentfarbe" and „deine Klasse" appear where ownership is the point; „Bevorstehende Termine" is not „Deine Termine" |

> **Use possessive pronouns sparingly.** Possessive pronouns like *my* and *your* are often
> unnecessary to establish context. … Avoid using *we* altogether because it may be unclear who the
> "we" in question refers to. This is particularly problematic in error messages like "We're having
> trouble loading this content." Something like "Unable to load content" is much clearer.
> — [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

The app follows this exactly. „Serververbindung fehlgeschlagen" is the „Unable to load content"
construction in German.

> **Determine your app's voice.** Think about who you're talking to, so you can figure out the type
> of vocabulary you'll use.
> — [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

---

## 3. Tone by context

> **Match your tone to the context.** Once you've established your app's voice, vary your tone based
> on the situation.
> — [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

| Context | Tone | Example |
|---|---|---|
| Onboarding | Warm, a little excited | „Willkommen!" · „Los geht's!" |
| Everyday chrome | Flat and factual | „Vertretungsplan" · „Stundenplan" · „Bevorstehende Termine" |
| Errors | Calm, specific, no blame | „Zugangsdaten sind falsch." |
| Server trouble | Explains the likely cause | „Möglicherweise besteht keine Internetverbindung oder es finden gerade Wartungsarbeiten am Lessing-Gymnasium statt." |
| Destructive confirmation | States the consequence | „Wirklich abmelden? Du musst die Zugangsdaten danach erneut eingeben." |
| Legal boundary | Formal, unambiguous | „Die Krankmeldung wird vom Lessing-Gymnasium bereitgestellt und ist unabhängig von der LGKA+ App." |

The server-trouble string is the best piece of writing in the app. It does not say "something went
wrong". It names the two real causes a pupil might be experiencing — no signal, or the school's
server being worked on — and by naming the second one it stops the user blaming the app.

---

## 4. Buttons and labels

> **Be action oriented.** Active voice and clear labels help people navigate through your app from
> one step to the next … When labeling buttons and links, it's almost always best to use a verb.
> Prioritize clarity and avoid the temptation to be too cute or clever with your labels.
> — [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

| Key | German | English | Verb? |
|---|---|---|---|
| `login` | Anmelden | Log in | ✅ |
| `logout` | Abmelden | Log out | ✅ |
| `continueLabel` | Weiter | Continue | ✅ |
| `tryAgain` | Erneut versuchen | Try again | ✅ |
| `setClassButton` | Speichern | Save | ✅ |
| `cancel` | Abbrechen | Cancel | ✅ |
| `krankmeldungButton` | Zur Krankmeldung | To the sick note | directional |
| `mehrErfahren` | Mehr erfahren | Learn more | ✅ |
| `letsGo` | Los geht's! | Let's go! | the one flourish |

„Mehr erfahren" is worth noting against the HIG's specific advice:

> For links, avoid using "Click here" in favor of more descriptive words or phrases, such as "Learn
> more about UX Writing." This is especially important for people using screen readers.
> — [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

The app escapes the problem structurally rather than lexically: „Mehr erfahren →" is
`accessibilityHidden(true)`, and the containing card is one combined element whose label is the
article title. A screen reader hears the headline, not "learn more".

„Los geht's!" is the one moment of levity. It is on the last onboarding screen, it is one string,
and it has an exclamation mark the rest of the app never uses.

---

## 5. Errors

> **Write clear error messages.** It's always best to help people avoid errors. When an error
> message is necessary, display it as close to the problem as possible, avoid blame, and be clear
> about what someone can do to fix it. … Interjections like "oops!" or "uh-oh" are typically
> unnecessary and can sound insincere.
> — [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

No string in the catalog contains „Hoppla", „Ups", „Oops" or an emoji.

| Key | German | What it does right |
|---|---|---|
| `login.failed` | Zugangsdaten sind falsch. | Names the cause precisely |
| `login.offline` | Anmeldung nicht möglich – bitte Internetverbindung prüfen. | Names the remedy |
| `login.storeFailed` | Zugangsdaten konnten nicht gespeichert werden. | Distinguishes a storage failure from a wrong password |
| `noResults` | Klasse %@ existiert nicht. | States a fact about the data, not about the user's typing |
| `scheduleNotAvailable` | %@ ist noch nicht verfügbar | „noch" — not yet, so try later |
| `formLoadErrorHint` | Bitte überprüfe deine Internetverbindung und versuche es erneut. | Two concrete steps |

„Klasse 9Z existiert nicht." is the model. Compare it with „Ungültige Eingabe": one describes the
school, the other accuses the user.

Empty states follow the same rule — `noEventsAvailable`, `noNewsAvailable`, `noSchedulesAvailable`,
`noInfoYet` — each naming what is missing rather than saying "nothing here".

---

## 6. Capitalisation

| Rule | Applied to |
|---|---|
| Sentence case | Every full sentence and question |
| German noun capitalisation | Naturally throughout — „Vertretungsplan", „Bevorstehende Termine" |
| ALL CAPS **in the string** | `settingsSectionAppearance` „DARSTELLUNG", `settingsSectionMore` „MEHR", `hourlyForecastLabel` „STÜNDLICH", `threeDayForecastLabel` „3 TAGE" |
| `.uppercased()` in code | Only the four weather stat-tile labels |

> **Adopt capitalization rules that align with your app's style, then apply them consistently.**
> … Choose a style for each UI element type and use it consistently throughout your app.
> — [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

Putting the uppercase in the *string* rather than in a `.textCase()` modifier is the localisation-
safe choice: a translator can see it and can override it for a language where mechanical
uppercasing is wrong.

- [ ] The one `.uppercased()` call, in `statTile`, is the inconsistency. Moving „Luftfeuchte",
      „Wind", „Luftdruck", „UV-Index" into the catalog as uppercase strings would make the rule
      uniform.

---

## 7. Format strings

Every interpolated string uses **positional** specifiers.

| Key | Pattern |
|---|---|
| `a11y.day` | `%1$@: %2$@, Höchstwert %3$lld Grad, Tiefstwert %4$lld Grad` |
| `feelsLike.range` | `Gefühlt %1$lld°  ·  %2$lld° – %3$lld°` |
| `highLow` | `H: %1$lld°  T: %2$lld°` |
| `titleWithSemester` | `%1$@ – %2$@` |
| `class.named` | `Klasse %@` |

Positional specifiers let a translation reorder the arguments. `highLow` shows why this matters:
German uses H/T (Hoch/Tief) and English uses H/L, and both need the same two numbers in the same
order — but the next language may not.

`substitutions.count %lld` is declared as a **plural variant** in the catalog, so German and English
each get their own singular and plural forms rather than a hard-coded „%d Vertretungen".

Dates and numbers are formatted by the system, never by hand:

```swift
date.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
date?.formatted(.dateTime.month(.abbreviated))
String(format: s(key), locale: .current, arguments: args)
```

Note `locale: .current` in `L.f` — decimal separators follow the user's region, not the developer's.

> **Use a number formatter to help with numeric data.** … Don't assume the actual presentation of
> data, however, as formatting can vary significantly based on people's locale.
> — [Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields)

---

## 8. Domain vocabulary

The school's own terms are preserved rather than invented.

| German | English | Note |
|---|---|---|
| Vertretungsplan | Substitution plan | The school's word |
| Stundenplan | Timetable | |
| Krankmeldung | Sick note | |
| Halbjahr | Semester | „1. Halbjahr" / „1st semester" |
| Klasse 7b | Class 7b | Via `class.named` |
| Jahrgang 11 / 12 | Year 11 / 12 | Separate keys, because „Klasse J11" would be wrong |
| Termine | Events | |
| Neuigkeiten | News | |
| Impressum | Legal notice | The German legal term, translated by function |

The `L.className(_:)` helper encodes a real piece of domain knowledge:

```swift
static func className(_ cls: String) -> String {
    if cls == "j11" { return s("jahrgang11") }
    if cls == "j12" { return s("jahrgang12") }
    let name = cls.prefix(1).uppercased() + cls.dropFirst()
    return f("class.named", name)
}
```

Years 11 and 12 are „Jahrgang", grades 5–10 are „Klasse". A generic formatter would say „Klasse J11",
which no one at the school would say. Weekdays get the same treatment: `L.weekday(_:)` maps the
German Untis weekday name to a localised one, so „Montag" from the source data renders as „Monday"
in English.

> **Build language patterns.** Consistency builds familiarity, helping your app feel cohesive,
> intuitive, and thoughtfully designed.
> — [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

---

## 9. Writing for the device

> **Write for how people use each device.** … Make sure you describe gestures correctly on each
> device — for example, not saying "click" for a touch device like iPhone or iPad where you mean "tap."
> — [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

The app says „Tippe, um deine Klasse festzulegen" and „Tippen für Details." — tap, never click. No
string mentions a mouse, a keyboard or a window.

---

## 10. Length and German

German strings run roughly 20–30 % longer than English. Two places already feel it:

- „Hinweis zur Krankmeldung" (24 characters) as a navigation title, against the HIG's 15-character
  guidance in [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars).
- „In welcher Klasse bist du?" as a `subheadline.semibold` card title inside a row that also holds a
  44 pt square and a chevron.

- [ ] Re-check both at accessibility type sizes. See [10-accessibility.md](10-accessibility.md).

Because German is the *source* language, the app is being designed against its longest strings
first, which is the safer direction.

---

## 11. Adding a string

1. Add a key to [`Localizable.xcstrings`](../App/Localizable.xcstrings). Name it for what it *is*,
   not what it says: `scheduleNoClassSub`, not `tapToSetYourClass`.
2. Write the German first. Read it aloud; if it sounds like a translation, rewrite it.
3. Translate to English. Match the register — informal, not casual-American.
4. Use positional specifiers for anything interpolated.
5. If it is uppercase in the UI, write it uppercase in the catalog.
6. Prefix accessibility-only strings with `a11y.` and spell out abbreviations there — „Grad", not
   „°"; see [10-accessibility.md](10-accessibility.md) §3.2.
7. Reference it with `L.s(...)` or `L.f(...)`. Never a literal in a view.

---

## 12. Do / don't

- [x] Address the user as `du`.
- [x] Start button labels with a verb.
- [x] Name the cause and the remedy in every error.
- [x] Use positional format specifiers, always.
- [x] Let `.formatted(...)` handle every date and number.
- [ ] Don't use „wir" or „Sie".
- [ ] Don't write „Fehler" as a standalone message.
- [ ] Don't put a literal string in a SwiftUI view.
- [ ] Don't concatenate translated fragments — add a format string instead.
- [ ] Don't add an emoji. There are none, and the app is better for it.

---

## Sources

| Source | Kind | Accessed |
|---|---|---|
| [`App/Localizable.xcstrings`](../App/Localizable.xcstrings) | App source | 2026-09-12 |
| [`App/Localization.swift`](../App/Localization.swift) | App source | 2026-09-12 |
| [`App/HomeScreen.swift`](../App/HomeScreen.swift) | App source | 2026-09-12 |
| [`App/WeatherPage.swift`](../App/WeatherPage.swift) | App source | 2026-09-12 |
| [`App/OnboardingViews.swift`](../App/OnboardingViews.swift) | App source | 2026-09-12 |
| [`App/SettingsSheet.swift`](../App/SettingsSheet.swift) | App source | 2026-09-12 |
| [`project.yml`](../project.yml) | App source | 2026-09-12 |
| [Writing](https://developer.apple.com/design/human-interface-guidelines/writing) | Apple HIG | 2026-09-12 |
| [Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields) | Apple HIG | 2026-09-12 |
| [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) | Apple HIG | 2026-09-12 |
| [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) | Apple HIG | 2026-09-12 |
