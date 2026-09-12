# Components

| | |
|---|---|
| **Last updated** | 2026-09-12 |
| **Applies to** | LGKA+ iOS (iOS 26, Swift 6.3, Xcode 26.6) |
| **Owner** | Luka Löhr |
| **Status** | Adopted |

---

## Contents

1. [The row anatomy](#1-the-row-anatomy)
2. [IconSquare](#2-iconsquare)
3. [Cards](#3-cards)
4. [Buttons](#4-buttons)
5. [Pickers and segmented controls](#5-pickers-and-segmented-controls)
6. [Lists](#6-lists)
7. [Text fields](#7-text-fields)
8. [Sheets and alerts](#8-sheets-and-alerts)
9. [Toolbars](#9-toolbars)
10. [Empty and error states](#10-empty-and-error-states)

---

## 1. The row anatomy

Nearly every tappable thing on the home screen is the same shape. Learn it once.

```
┌─────────────────────────────────────────────────────┐
│ [ 44pt tinted    ]  Title (callout/subheadline,      │
│ [ glyph square   ]  semibold, .primary)         ›    │
│ [ radius 12      ]  Subtitle (caption, .secondary)   │
└─────────────────────────────────────────────────────┘
   ↑ 14 pt gap        ↑ 2 pt gap            ↑ chevron
   vertical padding 6 pt · whole row is the hit target
```

The canonical implementation is `homeCard` in [`App/HomeScreen.swift`](../App/HomeScreen.swift):

```swift
private func homeCard(icon: String, title: String, subtitle: String,
                      action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 14) {
            IconSquare(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(title), \(subtitle)")
    .accessibilityAddTraits(.isButton)
}
```

Five things are load-bearing and must be copied into any new row:

- [x] `.buttonStyle(.plain)` — otherwise the whole row turns accent-coloured.
- [x] `.contentShape(Rectangle())` — otherwise the gaps are dead.
- [x] `.accessibilityElement(children: .ignore)` + one composed label — otherwise VoiceOver reads
      the glyph, the title and the subtitle as three separate elements.
- [x] `.accessibilityAddTraits(.isButton)` — `.plain` loses the button trait.
- [x] The chevron uses `.secondary.opacity(0.5)`, not the accent. It is an affordance, not a
      highlight.

> **Provide appropriate feedback when people select a list item.** The feedback can vary depending
> on whether selecting the item reveals a new view or toggles the item's state.
> — [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables)

> **Use an info button only to reveal more information about a row's content.** … If you need to
> let people drill into a list or table row's subviews, use a disclosure indicator accessory control.
> — [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables)

---

## 2. IconSquare

The app's one bespoke atom. [`App/Theme.swift`](../App/Theme.swift):

```swift
struct IconSquare: View {
    let systemName: String
    var alpha: Double = 0.12
    @Environment(\.appAccent) private var accent
    @ScaledMetric(relativeTo: .body) private var size = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.body.weight(.medium))
            .foregroundStyle(accent)
            .frame(width: size, height: size)
            .background(accent.opacity(alpha), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }
}
```

| Property | Value | Why |
|---|---|---|
| Size | 44 pt, `@ScaledMetric` to `.body` | Matches the minimum control size and grows with type |
| Radius | 12 pt `.continuous` | Nests inside the 16 pt card, concentric |
| Glyph | `.body.weight(.medium)` | Matches the weight of the title beside it |
| Fill | accent at `0.12`; `0.08` for a disabled substitution card | One step of de-emphasis |
| A11y | `accessibilityHidden(true)` | Decorative; the row label carries the meaning |

> **In general, match the weights of interface icons and adjacent text.** Unless you want to
> emphasize either the icons or the text, using the same weight for both gives your content a
> consistent appearance and level of emphasis.
> — [Icons](https://developer.apple.com/design/human-interface-guidelines/icons)

The event date tile is the same atom with a number instead of a symbol: 44×44, radius 12, accent
at 12 %, `accessibilityHidden(true)`.

---

## 3. Cards

### 3.1 Weather card (home)

The most elaborate component in the app. It is a `Button` whose *list row background* is the live
Metal sky.

```swift
.listRowInsets(EdgeInsets())
.listRowBackground(
    WeatherSkyView(code: w.code, isDay: w.isDay, particles: false)
        .overlay(LinearGradient(colors: [.clear, .black.opacity(0.18)],
                                startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true))
```

| Detail | Value |
|---|---|
| Height | `minHeight: 112`, full width |
| Padding | 18 pt horizontal, 14 pt vertical |
| Particles | **off** (`particles: false`) — rain and snow are for the full page only |
| Scrim | 18 % black, top→bottom |
| Text | forced `.white` + `black.opacity(0.3)` shadow, radius 4 |
| Left column | city (footnote semibold, 0.85), temperature (`heroSize` rounded medium), condition (footnote medium, 0.9), feels-like (caption2 semibold, 0.8) |
| Right column | multicolor condition symbol (`title`), high/low (caption medium, 0.9) |
| A11y | `accessibilityElement(children: .ignore)` + `a11y.weatherCard` label + `.isButton` |

The opacity ladder — 0.85 / 1.0 / 0.9 / 0.8 — is how hierarchy is expressed on a background where
`.secondary` would be unreadable.

### 3.2 Substitution card

Two rows: today and tomorrow. Three distinct states.

| State | Condition | Appearance |
|---|---|---|
| Available | `plan.canDisplay` | Calendar glyph at 12 %, weekday title `.callout.semibold`, subtitle `„14.09.2026 · 12 Vertretungen"`, chevron |
| Not yet published | `plan` exists but `canDisplay == false` | Title becomes `noInfoYet` („Noch keine Infos"), glyph drops to 8 % and `.opacity(0.5)`, whole row `.opacity(0.6)`, no chevron, `.disabled(true)` |
| Per-day failure | `plan == nil`, not loading, no global error | Row becomes a retry button: `arrow.clockwise` in the square **and** as a trailing tinted glyph |

Three signals mark the unavailable state — different text, lower opacity, missing chevron — so it
never depends on colour alone.

### 3.3 Schedule card

Two states, both `homeCard`:

- No class set → `graduationcap`, „In welcher Klasse bist du?" / „Tippe, um deine Klasse festzulegen".
- Class set → `tablecells`, „Klasse 7b" / „1. Halbjahr", plus a `.contextMenu` with a pencil-labelled
  "Klasse eingeben" action.

> **Use progressive disclosure to make layouts cleaner and easier to interact with.** … Use
> disclosure triangles, menus, or nested views to reduce how much content to initially display.
> — [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)

The context menu is the discoverability compromise: changing class is rare, so it does not earn a
visible control, but it is reachable without going through settings.

### 3.4 Event rows

Date tile + title (`subheadline.semibold`, `lineLimit(2)`) + subtitle
(`„Mo. 14. September · 07:45"`). Not tappable — events have no detail view — so they carry no
chevron and no button trait, only `accessibilityLabel`.

### 3.5 News card

The densest card in the app. [`App/NewsViews.swift`](../App/NewsViews.swift):

1. Title — `callout.semibold`
2. Description — `subheadline`, `.secondary`, `lineLimit(2)`
3. Meta row — person / calendar / eye labels, `caption`, `.tertiary`, wrapped in `ViewThatFits`
4. Up to three tag capsules — `caption2.medium`, `.tint` on `.tint.opacity(0.12)`, `Capsule()`
5. „Mehr erfahren →" — `caption.semibold`, `.tint`, `accessibilityHidden(true)`

The whole card is `.accessibilityElement(children: .combine)` inside a `NavigationLink(value:)`.
The „Mehr erfahren" line is hidden from VoiceOver because the link trait already says it is tappable.

### 3.6 Weather page cards

Three shapes, one recipe: `.padding(14)`, `.thinMaterial` at radius 18 `.continuous`,
`.environment(\.colorScheme, .dark)`, white text, `cardHeader(icon, label)` with
`.accessibilityAddTraits(.isHeader)`.

| Card | Content |
|---|---|
| `hourlyCard` | Horizontal `ScrollView`, 22 pt columns: time, multicolor symbol, precipitation % if ≥ 10 %, temperature |
| `dailyCard` | Day label (52 pt fixed), symbol (28 pt), precipitation (36 pt), min, range capsule, max |
| `statsGrid` | `LazyVGrid` of two flexible columns, 14 pt gutters, four tiles at `minHeight: 92` |

The range capsule is the only data visualisation in the app: a 5 pt track at
`black.opacity(0.25)` with a `LinearGradient(colors: [.cyan, .yellow])` fill positioned by
`GeometryReader` against the week's min and max, with a `max(6, …)` floor so a flat day still
shows a mark.

<table>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/02_home.png" width="180"><br><sub>de · phone · dark — weather, substitution, schedule, event cards</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/03_weather.png" width="180"><br><sub>de · phone · dark — hourly, daily, stat tiles</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/04_news.png" width="180"><br><sub>de · phone · dark — news cards</sub></td>
  </tr>
</table>

---

## 4. Buttons

| Style | Where | Notes |
|---|---|---|
| `.glassProminent` + `.controlSize(.large)` | `PrimaryButton`, login, „Zur Krankmeldung" | Full width via `.frame(maxWidth: .infinity)`, `.fontWeight(.semibold)` |
| `.bordered` | „Erneut versuchen" inside `ContentUnavailableView` and the substitution error block | Secondary weight for a recovery action |
| `.borderedProminent` | „Erneut versuchen" in the web-view error state | The only prominent action on an otherwise empty screen |
| `.glass` | PDF match stepper chevrons | Icon-only, `.labelStyle(.iconOnly)` |
| `.plain` | Every card row | Cards must not look like buttons |
| default | Toolbar items, settings rows, `Link`s | System-managed |

```swift
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).fontWeight(.semibold).frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }
}
```

> **Use style — not size — to visually distinguish the preferred choice among multiple options.**
> — [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)

The login button shows an in-place activity indicator rather than a separate spinner, exactly as
the HIG suggests for iOS:

```swift
Group {
    if isLoading { ProgressView().tint(.white) }
    else if flash == .success { Image(systemName: "checkmark") }
    else { Text(L.s("login")).fontWeight(.semibold) }
}
.frame(maxWidth: .infinity)
```

> **Configure a button to display an activity indicator when you need to provide feedback about
> an action that doesn't instantly complete.** Displaying an activity indicator within a button
> can save space in your user interface while clearly communicating the reason for the delay.
> — [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)

Note `.accessibilityLabel(L.s("login"))` is set explicitly so the label stays "Anmelden" while the
visible content swaps to a spinner or a checkmark.

---

## 5. Pickers and segmented controls

Two pickers, both bound directly to `Prefs`, both reused verbatim in onboarding and in settings.

### 5.1 ThemeModePicker — segmented

```swift
Picker(L.s("appearanceTitle"), selection: $prefs.themeMode) {
    Label(L.s("themeDark"), systemImage: "moon.fill").tag("dark")
    Label(L.s("themeAuto"), systemImage: "circle.lefthalf.filled").tag("system")
    Label(L.s("themeLight"), systemImage: "sun.max.fill").tag("light")
}
.pickerStyle(.segmented)
.labelsHidden()
.onChange(of: prefs.themeMode) { Haptics.light() }
```

Three segments — well inside the limit — ordered dark · auto · light so the neutral option sits
between the two extremes, which is how the value is conceptually ordered.

> **Limit the number of segments in a control.** Too many segments can be hard to parse and
> time-consuming to navigate. Aim for no more than about five to seven segments in a wide
> interface and no more than about five segments on iPhone.
> — [Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls)

> **Use nouns or noun phrases for segment labels.** Write text that describes each segment and
> uses title-style capitalization. A segmented control that displays text labels doesn't need
> introductory text.
> — [Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls)

„Dunkel" / „Auto" / „Hell" are nouns-as-adjectives in title case, and the control carries no
introductory text of its own inside the settings `LabeledContent`.

> **Note**
> Each segment is built from a `Label` with both text and symbol. In the rendered screenshot the
> segmented control shows text only, which is the system's own compaction. The HIG advises
> **Prefer using either text or images — not a mix of both — in a single segmented control**
> ([Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls));
> supplying both and letting the platform choose is the safe way to honour that across widths.

### 5.2 AccentPalettePicker — palette

```swift
Picker(L.s("accentColor"), selection: $prefs.accentColor) {
    ForEach(Accent.allCases) { accent in
        Image(systemName: prefs.accentColor == accent.rawValue ? "checkmark.circle.fill" : "circle.fill")
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(accent.color)
            .tint(accent.color)
            .accessibilityLabel(accent.label)
            .tag(accent.rawValue)
    }
}
.pickerStyle(.palette)
.paletteSelectionEffect(.custom)
.labelsHidden()
```

The selected swatch swaps `circle.fill` → `checkmark.circle.fill`. That is the inclusive-colour
requirement satisfied at the component level: the selection is a *shape* change, not only a colour
change, so it survives colour blindness and a monochrome rendering.

> **Convey information with more than color alone.** … Offer visual indicators, like distinct
> shapes or icons, in addition to color to help people perceive differences in function and
> changes in state.
> — [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

Each swatch also carries `accessibilityLabel(accent.label)` — „Blau", „Mint", „Lavendel", „Rosé",
„Pfirsich" — so VoiceOver announces a colour name rather than "circle".

Both pickers are scaled to 1.3× on the onboarding accent screen and capped at `maxWidth: 220`
in the settings sheet.

<table>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/07_settings.png" width="180"><br><sub>de · phone · dark — both pickers in <code>LabeledContent</code></sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/light/07_settings.png" width="180"><br><sub>en · phone · light</sub></td>
  </tr>
</table>

---

## 6. Lists

`.listStyle(.insetGrouped)` on the home screen, the news list and the onboarding feature list;
`Form` on the login screen and in settings.

| Rule | Applied |
|---|---|
| Section headers name the group | „Vertretungsplan", „Stundenplan", „Bevorstehende Termine" |
| Text-first rows | Every row is a title plus a subtitle; the only image is the weather sky |
| Cap long sections | `model.events.prefix(4)`, `others.prefix(3)`, `md.tags.prefix(3)` |
| Pull to refresh on every list | `.refreshable` on home, news list, weather page |

> **Prefer displaying text in a list or table.** A table can include any type of content, but the
> row-based format is especially well suited to making text easy to scan and read.
> — [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables)

The news list uses value-based navigation, `NavigationLink(value: md)`, with a comment explaining
why:

```swift
/// Navigation is value-based on the article itself (stable id = url), so a
/// refresh while a detail is open can never index out of range.
```

---

## 7. Text fields

Three fields in the whole app.

| Field | Component | Configuration |
|---|---|---|
| Username | `TextField` | `.textContentType(.username)`, `.textInputAutocapitalization(.never)`, `.autocorrectionDisabled()`, `.submitLabel(.next)` → focuses password |
| Password | `SecureField` | `.textContentType(.password)`, `.submitLabel(.go)` → submits if valid |
| Class | `TextField` inside an alert | `.textInputAutocapitalization(.never)`, `.autocorrectionDisabled()`, placeholder „Gib deine Klasse ein" |

> **Use secure text fields to hide private data.** Always use a secure text field when your app
> asks for sensitive data, such as a password.
> — [Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields)

> **Show a hint in a text field to help communicate its purpose.**
> — [Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields)

Placeholders are „Benutzername", „Passwort", „Gib deine Klasse ein". The login form additionally
gates its button: `canLogin` requires both fields non-blank after trimming.

> **When data entry is necessary, make sure people understand that they must provide the required
> data before they can proceed.** For example, if you include a Next or Continue button after a
> set of text fields, make the button available only after people enter the data you require.
> — [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data)

The class input normalises rather than scolds: `trimmingCharacters(in: .whitespaces).lowercased()`,
so "7B " and "7b" are the same class.

---

## 8. Sheets and alerts

### 8.1 Settings sheet

```swift
.sheet(isPresented: $showSettings) {
    SettingsSheet(onBugReport: { showSettings = false; path.append(HomeRoute.bugReport) })
        .presentationDetents([.medium, .large])
}
```

Medium and large detents, with an `xmark` close button on the trailing edge of its own
`NavigationStack` toolbar.

> **In an iPhone app, consider supporting the medium detent to allow progressive disclosure of
> the sheet's content.**
> — [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)

> **Include a grabber in a resizable sheet.** A grabber shows people that they can drag the sheet
> to resize it; they can also tap it to cycle through the detents.
> — [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)

The grabber is visible in the screenshot — SwiftUI draws it for a multi-detent sheet.

Notice the bug-report handoff: the sheet dismisses *first*, then the parent pushes the route. That
avoids stacking a second modal on the first.

> **Display only one sheet at a time from the main interface.** … If something people do within a
> sheet results in another sheet appearing, close the first sheet before displaying the new one.
> — [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)

Sheet contents: a `DARSTELLUNG` section with the two pickers in `LabeledContent`, a `MEHR` section
with bug report, privacy `Link`, legal `Link` and a destructive „Abmelden", and a centred footer
`© 2026 Luka Löhr • v3.0.0`.

> **Minimize the number of settings you offer.** Although people appreciate having control over an
> app or game, too many settings can make the experience feel less approachable.
> — [Settings](https://developer.apple.com/design/human-interface-guidelines/settings)

Six items. That is the whole of settings.

### 8.2 Alerts and confirmation dialogs

| Trigger | Type | Buttons |
|---|---|---|
| Set class | `.alert` with a `TextField` | „Abbrechen" (`.cancel`) · „Speichern" |
| Timetable unavailable | `.alert` | „OK" (`.cancel`) |
| Log out | `.confirmationDialog`, `titleVisibility: .visible` | „Abmelden" (`.destructive`) · „Abbrechen" (`.cancel`) |
| Sky preview (DEBUG only) | `.confirmationDialog` | Live + ten condition presets |

> **Use an action sheet — not an alert — to offer choices related to an intentional action.**
> — [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts)

Log-out is an intentional, irreversible-ish action, so it gets a confirmation dialog, not an alert.
Its title is a full question that states the consequence: „Wirklich abmelden? Du musst die
Zugangsdaten danach erneut eingeben." The button says „Abmelden", not "OK".

> **Avoid using OK as the default button title unless the alert is purely informational.** … A
> specific button title like "Erase," "Convert," "Clear," or "Delete" helps people understand the
> action they're taking.
> — [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts)

The one „OK" in the app is on the purely informational timetable-unavailable alert, which is the
sanctioned use.

> **Warning**
> The timetable-unavailable case is an alert that only informs. The HIG says: **Avoid using an
> alert merely to provide information** ([Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts)).
> The source comment marks it as parity with the Flutter app's SnackBar. A non-modal inline
> message on the schedule row would be more HIG-conformant and is the recommended future change.

---

## 9. Toolbars

### 9.1 Home

```swift
ToolbarItemGroup(placement: .topBarTrailing) {
    Button { Haptics.light(); path.append(HomeRoute.news) } label: {
        Label(L.s("news"), systemImage: "newspaper")
    }.accessibilityIdentifier("home.news")
    Button { Haptics.light(); openKrankmeldung() } label: {
        Label(L.s("krankmeldung"), systemImage: "cross.case")
    }.accessibilityIdentifier("home.sick")
    Button { Haptics.light(); showSettings = true } label: {
        Label(L.s("settings"), systemImage: "gearshape")
    }.accessibilityIdentifier("home.settings")
}
```

Three items in one `ToolbarItemGroup`, so iOS 26 renders them as a single glass capsule — visible
in the home screenshot. Symbols only, no text, no tint, no overflow menu.

> **Minimize the number of groups.** Too many groups of controls can make a toolbar feel cluttered
> and confusing … In general, aim for a maximum of three.
> — [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)

> **Prefer system-provided symbols without borders.** System-provided symbols are familiar,
> automatically receive appropriate coloring and vibrancy, and respond consistently to user
> interactions.
> — [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)

### 9.2 PDF viewer

Leading `xmark` (close), trailing group of `magnifyingglass` and a `ShareLink` with
`square.and.arrow.up`.

> Standard icons: Share — `square.and.arrow.up`; Search — `magnifyingglass`; Cancel — `xmark`.
> — [Icons](https://developer.apple.com/design/human-interface-guidelines/icons)

> **Use the standard Back and Close buttons.** … Prefer the standard symbols for each, and don't
> use a text label that says *Back* or *Close*.
> — [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)

Full list in [09-iconography.md](09-iconography.md).

---

## 10. Empty and error states

Three tiers, chosen by how much of the screen is affected.

| Tier | Component | Used for |
|---|---|---|
| **Full screen** | `ContentUnavailableView` | No news, news load failed, article load failed, weather load failed, PDF unreadable, web form failed |
| **Section block** | Custom `VStack`: `cloud.slash` `.largeTitle`, title `.subheadline.semibold`, hint `.caption` `.secondary` centred, `.bordered` retry | Substitution plans failed |
| **Inline row** | `HStack`: badge glyph, `.subheadline` `.secondary` message, `Spacer`, 44 pt retry glyph | Schedule failed, events failed, weather failed, nothing available |

```swift
ContentUnavailableView {
    Label(L.s("weatherDataNotAvailable"), systemImage: "cloud.slash")
} description: {
    Text(L.s("checkInternetConnection"))
} actions: {
    Button(L.s("tryAgain")) { Task { await model.loadWeather(mode: .refresh) } }
        .buttonStyle(.bordered)
}
```

Every failure state offers a retry. None of them is an alert.

> **Provide clear next steps on any blank screens.** An empty state … can provide a good
> opportunity to make people feel welcome and educate them about your app. … An empty screen can be
> daunting if it isn't obvious what to do next, so guide people on actions they can take, and give
> them a button or link to do so if possible.
> — [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

Loading uses redaction rather than a spinner wherever the shape of the result is known:

```swift
private var skeletonRow: some View {
    HStack(spacing: 14) {
        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary).frame(width: 44, height: 44)
        VStack(alignment: .leading, spacing: 4) {
            Text("Placeholder Title").font(.callout)
            Text("Placeholder sub").font(.caption)
        }
        Spacer()
    }
    .redacted(reason: .placeholder)
    .padding(.vertical, 8)
    .accessibilityLabel(L.s("loading"))
}
```

> **Show something as soon as possible.** If you make people wait for loading to complete before
> displaying anything, they can interpret the lack of content as a problem with your app or game.
> Instead, consider showing placeholder text, graphics, or animations as content loads.
> — [Loading](https://developer.apple.com/design/human-interface-guidelines/loading)

More in [08-motion-and-feedback.md](08-motion-and-feedback.md).

---

## Sources

| Source | Kind | Accessed |
|---|---|---|
| [`App/HomeScreen.swift`](../App/HomeScreen.swift) | App source | 2026-09-12 |
| [`App/WeatherPage.swift`](../App/WeatherPage.swift) | App source | 2026-09-12 |
| [`App/NewsViews.swift`](../App/NewsViews.swift) | App source | 2026-09-12 |
| [`App/OnboardingViews.swift`](../App/OnboardingViews.swift) | App source | 2026-09-12 |
| [`App/SettingsSheet.swift`](../App/SettingsSheet.swift) | App source | 2026-09-12 |
| [`App/PdfViewerScreen.swift`](../App/PdfViewerScreen.swift) | App source | 2026-09-12 |
| [`App/WebViews.swift`](../App/WebViews.swift) | App source | 2026-09-12 |
| [`App/Theme.swift`](../App/Theme.swift) | App source | 2026-09-12 |
| [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) | Apple HIG | 2026-09-12 |
| [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) | Apple HIG | 2026-09-12 |
| [Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls) | Apple HIG | 2026-09-12 |
| [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) | Apple HIG | 2026-09-12 |
| [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) | Apple HIG | 2026-09-12 |
| [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) | Apple HIG | 2026-09-12 |
| [Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields) | Apple HIG | 2026-09-12 |
| [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data) | Apple HIG | 2026-09-12 |
| [Icons](https://developer.apple.com/design/human-interface-guidelines/icons) | Apple HIG | 2026-09-12 |
| [Loading](https://developer.apple.com/design/human-interface-guidelines/loading) | Apple HIG | 2026-09-12 |
| [Settings](https://developer.apple.com/design/human-interface-guidelines/settings) | Apple HIG | 2026-09-12 |
| [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) | Apple HIG | 2026-09-12 |
| [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Apple HIG | 2026-09-12 |
| [Writing](https://developer.apple.com/design/human-interface-guidelines/writing) | Apple HIG | 2026-09-12 |
