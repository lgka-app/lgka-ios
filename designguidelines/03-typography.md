# Typography

| | |
|---|---|
| **Last updated** | 2026-09-12 |
| **Applies to** | LGKA+ iOS (iOS 26, Swift 6.3, Xcode 26.6) |
| **Owner** | Luka Löhr |
| **Status** | Adopted |

---

## 1. One typeface

LGKA+ ships **no font files**. Every glyph is San Francisco, requested through SwiftUI text
styles so that Dynamic Type, optical sizing and tracking are handled by the system.

> **Consider using the built-in text styles.** The system-defined text styles give you a
> convenient and consistent way to convey your information hierarchy through font size and
> weight. Using text styles with the system fonts also ensures support for Dynamic Type and
> larger accessibility type sizes (where available).
> — [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)

Two SF variants are in use:

| Variant | Where | Requested by |
|---|---|---|
| SF Pro | Everything | the default, `Font.Design.default` |
| SF Pro Rounded | The two temperature numerals only | `.font(.system(size:weight:design: .rounded))` |

> The system also offers SF Pro, SF Compact, SF Arabic, SF Armenian, SF Georgian, and SF Hebrew
> in rounded variants you can use to coordinate text with the appearance of soft or rounded UI
> elements, or to provide an alternative typographic voice.
> — [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)

The rounded voice is reserved for the weather hero, where it reads as a temperature readout
rather than as body copy. It appears nowhere else.

---

## 2. The type scale in use

Every style below was taken from the source. Sizes are the system's, not the app's.

| Text style | Weight applied | Where |
|---|---|---|
| `largeTitle` | `.bold` | Onboarding headlines: „Willkommen!", „Deine Akzentfarbe", „Erscheinungsbild" |
| `title2` | `.bold` | Login header „Anmeldung erforderlich"; news article title |
| `title2` | `.medium` | Weather hero city name |
| `title2` | regular | Krankmeldung info-card glyphs |
| `title3` | `.bold` | „Weitere Neuigkeiten" section heading |
| `title3` | `.bold` | Event date tile day number |
| `title3` | `.medium` | Weather stat-tile value (`36 %`, `9 km/h`) |
| `title3` | regular | Hourly-forecast condition glyph |
| `title` | regular | Home weather-card condition glyph |
| `body` | `.medium` | Onboarding feature titles |
| `body` | regular | News article body text |
| `body` | `.medium` | `IconSquare` glyph |
| `callout` | `.semibold` | Substitution card title (weekday); news card title |
| `callout` | `.medium` | Weather page condition line, high/low line, daily row day label |
| `callout` | `.semibold` | Daily-row maximum temperature |
| `subheadline` | `.semibold` | Schedule card title, event title, recommended-article title |
| `subheadline` | regular | News card description, login subtitle, empty/error states |
| `footnote` | `.semibold` | Home weather-card city, weather card-header labels, hourly time |
| `footnote` | `.medium` | Weather condition line on the card; PDF search feedback toast |
| `footnote` | regular | Chevrons, retry glyphs, toolbar-adjacent glyphs |
| `caption` | `.semibold` | Stat-tile label; daily precipitation percentage |
| `caption` | `.medium` | Home card high/low line |
| `caption` | regular | Card subtitles, event subtitles, news meta row, attribution link |
| `caption2` | `.semibold` | „Gefühlt …" line; event date-tile month; hourly precipitation |
| `caption2` | `.medium` | News tag capsules |
| `subheadline` + `.monospacedDigit()` | — | PDF match counter `3/17` |

### 2.1 The two custom sizes

Both are `@ScaledMetric`, so they grow with Dynamic Type instead of freezing.

```swift
// App/HomeScreen.swift — the home weather card
@ScaledMetric(relativeTo: .largeTitle) private var heroSize = 40
Text("\(Int(w.temp.rounded()))°")
    .font(.system(size: heroSize, weight: .medium, design: .rounded))

// App/WeatherPage.swift — the weather page hero
@ScaledMetric(relativeTo: .largeTitle) private var heroSize = 96
Text("\(Int(w.temp.rounded()))°")
    .font(.system(size: heroSize, weight: .thin, design: .rounded))
    .padding(.leading, 24) // optically center over the degree sign
```

> **Warning**
> The 96 pt hero uses `.thin`. The HIG says: **In general, avoid light font weights.** For
> example, if you're using system-provided fonts, prefer Regular, Medium, Semibold, or Bold font
> weights, and avoid Ultralight, Thin, and Light font weights, which can be difficult to see,
> especially when text is small.
> — [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
>
> This is an accepted deviation, on two grounds: the text is 96 pt, far past the size at which
> thin weights become hard to see, and it is white with a `radius: 8` black shadow over a
> controlled background. The 40 pt card version steps up to `.medium` precisely because it is
> smaller. Do not extend `.thin` to any other string.

Note also the `.padding(.leading, 24)` on the page hero: it optically centres the numeral by
compensating for the degree sign's right-side weight. That is the typographic equivalent of the
optical-centring advice in [Icons](https://developer.apple.com/design/human-interface-guidelines/icons).

---

## 3. Dynamic Type

- [x] Every string uses a text style or a `@ScaledMetric` size — nothing is a frozen point value.
- [x] `IconSquare` sizes itself with `@ScaledMetric(relativeTo: .body) private var size = 44`, so
      the glyph square grows with the label beside it.
- [x] Both `ViewThatFits` uses in [`App/NewsViews.swift`](../App/NewsViews.swift) exist for this
      reason: the author · date · views meta row lays out horizontally when it fits and stacks
      vertically when large type makes it not fit.

```swift
ViewThatFits(in: .horizontal) {
    metaRow(spacing: 12)
    VStack(alignment: .leading, spacing: 2) { metaRow(spacing: 12) }
}
```

> **Consider adjusting your layout at large font sizes.** When font size increases in a
> horizontally constrained context, inline items (like glyphs and timestamps) and container
> boundaries can crowd text and cause truncation or overlapping. To improve readability, consider
> using a stacked layout where text appears above secondary items.
> — [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)

### 3.1 Truncation policy

| Element | Limit | Rationale |
|---|---|---|
| News card description | `lineLimit(2)` | Teaser; the full text is one tap away |
| News card title, event title | `lineLimit(2)` | Titles must stay scannable |
| Weather condition, feels-like, high/low | `lineLimit(1)` | Fixed-height card |
| News meta row | `lineLimit(1)` | Stacks rather than wraps, via `ViewThatFits` |
| Article body | none | Never truncate content the user came to read |

> **Keep text truncation to a minimum as font size increases.** In general, aim to display as
> much useful text at the largest accessibility font size as you do at the largest standard font
> size. Avoid truncating text in scrollable regions unless people can open a separate view to
> read the rest of the content.
> — [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)

The `lineLimit(1)` on the home weather card is the one place to watch at accessibility sizes: the
card has a `minHeight: 112` but the text can still clip. See
[10-accessibility.md](10-accessibility.md) for the open verification list.

---

## 4. Case and emphasis conventions

| Convention | Applied to | Example |
|---|---|---|
| Sentence case | Everything that is a sentence or a question | „In welcher Klasse bist du?" |
| Title case (German capitalisation of nouns) | Card titles, section titles | „Bevorstehende Termine" |
| All caps, via the string itself | Settings section headers; weather card headers | `settingsSectionAppearance` = „DARSTELLUNG", `hourlyForecastLabel` = „STÜNDLICH" |
| All caps, via `.uppercased()` | Weather stat-tile labels only | `Text(label.uppercased())` |

> **Note**
> The uppercase settings headers come from the *string catalog*, not from `.textCase()`. That
> means a translator sees and controls the casing, which matters for languages where mechanical
> uppercasing is wrong. The one `.uppercased()` call — in `statTile` — is the exception and is
> applied to already-short weather nouns.

Weight, not colour, is the primary emphasis tool: a card title is `.semibold` against a regular
`.caption` subtitle, at the same hue.

> **Adjust font weight, size, and color as needed to emphasize important information and help
> people visualize hierarchy.** Be sure to maintain the relative hierarchy and visual distinction
> of text elements when people adjust text sizes.
> — [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)

---

## 5. Numerals

- Temperatures are rounded to whole degrees and always carry `°`: `Int(w.temp.rounded())`.
- The PDF match counter uses `.monospacedDigit()` so `3/17` → `4/17` does not shift the layout.
- Event day numbers sit in a fixed 44×44 tile, so they are `title3.bold` and never wrap.
- Percentages are suppressed below 10 %: `if h.pop >= 0.1`. Below that the number is noise.

---

## 6. Do / don't

- [x] Pick a text style, then adjust weight with `.weight(...)` or `.bold`.
- [x] Wrap any literal point size in `@ScaledMetric(relativeTo:)`.
- [x] Use `.monospacedDigit()` for any number that updates in place.
- [ ] Don't add a second typeface. There is no design problem in this app that a custom font solves.
- [ ] Don't use `.thin`, `.light` or `.ultraLight` below 96 pt.
- [ ] Don't hard-code `.font(.system(size: 13))` without a scaled metric.
- [ ] Don't `.uppercased()` a sentence. If a string should be uppercase, write it uppercase in the
      catalog so it can be localised.

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
| [`App/Theme.swift`](../App/Theme.swift) | App source | 2026-09-12 |
| [`App/Localizable.xcstrings`](../App/Localizable.xcstrings) | App source | 2026-09-12 |
| [Typography](https://developer.apple.com/design/human-interface-guidelines/typography) | Apple HIG | 2026-09-12 |
| [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Apple HIG | 2026-09-12 |
| [Icons](https://developer.apple.com/design/human-interface-guidelines/icons) | Apple HIG | 2026-09-12 |
