# Iconography

| | |
|---|---|
| **Last updated** | 2026-09-12 |
| **Applies to** | LGKA+ iOS (iOS 26, Swift 6.3, Xcode 26.6) |
| **Owner** | Luka Löhr |
| **Status** | Adopted |

---

## 1. One rule

**Every glyph in LGKA+ is an SF Symbol.** There is not a single custom interface icon, PDF glyph or
vector asset in the app. The only bitmaps are the three app-icon layers and the onboarding logo.

> **If you create a custom interface icon, use a vector format like PDF or SVG.** … Alternatively,
> you can create a custom SF Symbol and specify a scale that ensures the symbol's emphasis matches
> adjacent text.
> — [Icons](https://developer.apple.com/design/human-interface-guidelines/icons)

> **Consider using symbols when you need to convey a concept or depict an object, especially
> within text.**
> — [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)

The payoff is automatic: weight matching with adjacent text, Dynamic Type scaling, Dark Mode
adaptation, localisation-aware variants, and VoiceOver support — none of which the app has to build.

---

## 2. Symbols that match Apple's standard-action table

The HIG publishes a table of symbols for common actions. Where LGKA+ performs one of those actions,
it uses Apple's symbol, unchanged.

| Action | HIG symbol | LGKA+ uses it in |
|---|---|---|
| Cancel / Close | `xmark` | Settings sheet close, PDF close |
| Done | `checkmark` | Login success state |
| Search | `magnifyingglass` | PDF search toggle |
| Share | `square.and.arrow.up` | PDF `ShareLink` |
| Rename / edit | `pencil` | „Klasse eingeben" context-menu item |
| Calendar | `calendar` | Substitution card, news metadata, 3-day card header |

> Standard icons — Cancel: `xmark`; Done: `checkmark `; Search: `magnifyingglass`;
> Share: `square.and.arrow.up`; Rename: `pencil`; Calendar: `calendar`.
> — [Icons](https://developer.apple.com/design/human-interface-guidelines/icons)

> **Try to associate familiar actions with familiar icons.** For example, people can predict that a
> button containing the `square.and.arrow.up` symbol will help them perform share-related activities.
> — [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)

---

## 3. The full inventory

### 3.1 Navigation and chrome

| Symbol | Where | Style |
|---|---|---|
| `newspaper` | Home toolbar → news | outline |
| `cross.case` | Home toolbar → sick note | outline |
| `gearshape` | Home toolbar → settings | outline |
| `xmark` | Settings close, PDF close | outline |
| `magnifyingglass` | PDF search | outline |
| `square.and.arrow.up` | PDF share | outline |
| `safari` | Article → open in browser | outline |
| `chevron.right` | Row disclosure | outline, `.secondary.opacity(0.5)` |
| `chevron.up` / `chevron.down` | PDF previous / next match | outline, on glass |
| `arrow.right` | „Mehr erfahren" affordance | outline, `.tint` |
| `arrow.clockwise` | Retry, everywhere | outline |

Toolbars use the outline variant throughout, which is what the HIG prescribes:

> The outline variant works well in toolbars, lists, and other places where you display a symbol
> alongside text. … In many cases, the view that displays a symbol determines whether to use outline
> or fill, so you don't have to specify a variant. For example, an iOS tab bar prefers the fill
> variant, whereas a toolbar takes the outline variant.
> — [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)

### 3.2 Content types

| Symbol | Where |
|---|---|
| `calendar` | Substitution card square; news and article metadata; 3-day card header |
| `tablecells` | Timetable card square, when a class is set |
| `graduationcap` | Timetable card square, when no class is set yet |
| `clock` | Hourly-forecast card header; onboarding feature list |
| `person` | Article author |
| `eye` | View count |
| `cloud.sun` | Onboarding feature list — weather |
| `calendar.badge.clock` | Onboarding feature list — events |

The timetable card's `graduationcap` → `tablecells` swap is a small, good detail: the empty state
asks a question about *you* (which class are you in), so the symbol is a person-shaped concept; the
filled state points at a *document*, so the symbol is a table.

### 3.3 Status, empty and error

| Symbol | State |
|---|---|
| `cloud.slash` | Weather unavailable — section and full screen |
| `wifi.exclamationmark` | News or article load failed; web form failed |
| `clock.badge.exclamationmark` | Timetable list failed |
| `calendar.badge.exclamationmark` | Events failed |
| `calendar` | No events available |
| `clock` | No timetables available |
| `newspaper` | No news available |
| `doc.questionmark` | PDF could not be opened |
| `exclamationmark.triangle` | Krankmeldung disclaimer card |
| `person.wave.2` | Krankmeldung contact card |

The **badge grammar** is worth naming: the *empty* state reuses the plain content symbol
(`calendar`, `clock`, `newspaper`), while the *failure* state uses the same symbol with an
`.badge.exclamationmark` suffix. Two different situations, two visibly different glyphs, built from
one family. That is exactly what design variants are for.

> SF Symbols defines several design variants — such as fill, slash, and enclosed — that can help you
> communicate precise states and actions while maintaining visual consistency and simplicity in
> your UI. For example, you could use the slash variant of a symbol to show that an item or action
> is unavailable.
> — [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)

`cloud.slash` for "no weather data" is the slash variant used precisely as described.

### 3.4 Settings and onboarding

| Symbol | Where |
|---|---|
| `ladybug` | „Fehler gefunden?" |
| `hand.raised` | „Datenschutzerklärung" |
| `info.circle` | „Impressum" |
| `rectangle.portrait.and.arrow.right` | „Abmelden" (destructive role) |
| `moon.fill` / `circle.lefthalf.filled` / `sun.max.fill` | Appearance segments |
| `circle.fill` / `checkmark.circle.fill` | Accent palette swatches, unselected / selected |

The appearance-picker trio is a coherent set: `circle.lefthalf.filled` for "Auto" is literally half
dark and half light, so the three glyphs form a visual spectrum rather than three unrelated icons.

### 3.5 Weather conditions

Mapped from the WMO weather code in `Wmo.symbol` ([`App/SchoolAPI.swift`](../App/SchoolAPI.swift)):

| WMO codes | Day | Night |
|---|---|---|
| 0, 1 — clear / mainly clear | `sun.max.fill` | `moon.stars.fill` |
| 2 — partly cloudy | `cloud.sun.fill` | `cloud.moon.fill` |
| 3 — overcast | `cloud.fill` | `cloud.fill` |
| 45, 48 — fog | `cloud.fog.fill` | |
| 51–57 — drizzle | `cloud.drizzle.fill` | |
| 61, 63, 80, 81 — rain / showers | `cloud.rain.fill` | |
| 65, 82 — heavy rain | `cloud.heavyrain.fill` | |
| 66, 67 — freezing rain | `cloud.sleet.fill` | |
| 71–77, 85, 86 — snow | `cloud.snow.fill` | |
| 95, 96, 99 — thunderstorm | `cloud.bolt.rain.fill` | |
| anything else | `cloud.fill` | |

Three notes.

1. **Fill variants throughout.** Weather glyphs sit over a sky at small sizes; the fill variant has
   the mass to stay legible there, and it is what Apple's own Weather app uses.
2. **Day/night only where it changes meaning.** Only codes 0–2 branch on `isDay`, because only those
   have a sun or a moon in them. A foggy night and a foggy day look the same.
3. **`symbolRenderingMode(.multicolor)`** on every weather glyph — home card, hourly row, daily row.

   > **Multicolor** — Applies intrinsic colors to some symbols to enhance meaning. For example, the
   > `leaf` symbol uses green to reflect the appearance of leaves in the physical world.
   > — [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)

   > **Confirm that a symbol's rendering mode works well in every context.** Depending on factors
   > like the size of a symbol and its contrast with the current background color, different
   > rendering modes can affect how well people can discern the symbol's details.
   > — [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)

   Multicolor is the right mode here — the sun should be yellow — but it is the one place in the app
   where a glyph's colour is not app-controlled, and the daily card forces `isDay: true` so the
   3-day forecast never shows moons. Worth re-checking on an overcast light-mode capture that the
   grey `cloud.fill` still separates from a grey overcast sky.

### 3.6 Weather stat tiles

| Symbol | Metric |
|---|---|
| `humidity` | Luftfeuchte |
| `wind` | Wind |
| `gauge.with.needle` | Luftdruck |
| `sun.max.fill` | UV-Index |

---

## 4. Rendering modes in use

| Mode | Where | Why |
|---|---|---|
| Default (monochrome, inherits `foregroundStyle`) | Everything except weather and the palette picker | Keeps the accent and the semantic greys in charge |
| `.multicolor` | Weather condition glyphs | Intrinsic meaning — yellow sun, blue rain |
| `.monochrome` (explicit) | Accent palette swatches | Forces the flat colour circle; no hierarchy shading |

No hierarchical or palette rendering anywhere. No gradients. No variable colour.

---

## 5. Sizing and alignment

| Context | Font |
|---|---|
| `IconSquare` glyph | `.body.weight(.medium)` — matches the card title's weight |
| Home weather condition | `.title` |
| Hourly condition | `.title3`, in a fixed `frame(height: 24)` |
| Daily condition | default, in a fixed `frame(width: 28)` |
| Krankmeldung info glyph | `.title2` |
| Substitution error glyph | `.largeTitle` |
| Toolbar and chevrons | `.footnote` or system default |

> **Maintain visual consistency across all interface icons in your app.** Whether you use only
> custom icons or mix custom and system-provided ones, all interface icons in your app need to use a
> consistent size, level of detail, stroke thickness (or weight), and perspective.
> — [Icons](https://developer.apple.com/design/human-interface-guidelines/icons)

> **Increase the size of meaningful interface icons as font size increases.** … When you use SF
> Symbols, you get icons that scale automatically with Dynamic Type size changes.
> — [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)

Fixed frames on the hourly and daily condition glyphs are alignment devices, not size caps — the
symbol scales inside them so the columns stay in register regardless of which condition is shown.

---

## 6. Accessibility of glyphs

Two clean rules, applied consistently.

**Decorative glyphs are hidden.**

```swift
IconSquare(...)            // .accessibilityHidden(true) inside the component
dateTile(event.date)       // .accessibilityHidden(true)
Image("OnboardingLogo")    // .accessibilityHidden(true)
WeatherSkyView(...)        // .accessibilityHidden(true)
```

**Meaningful glyphs carry a label**, either through `Label(text, systemImage:)` — which gives
VoiceOver the text automatically — or through an explicit `accessibilityLabel`.

Every toolbar button is a `Label`, so the glyph-only presentation still announces „Neuigkeiten",
„Krankmeldung", „Einstellungen".

> **Provide alternative text labels for custom interface icons.** Alternative text labels — or
> accessibility descriptions — aren't visible, but they let VoiceOver audibly describe what's
> onscreen, simplifying navigation for people with visual disabilities.
> — [Icons](https://developer.apple.com/design/human-interface-guidelines/icons)

The weather glyph is the interesting case: it is inside an `accessibilityElement(children: .ignore)`
card whose single label is `a11y.weatherCard` — „Wetter in Karlsruhe: Teilweise bewölkt, 25 Grad.
Tippen für Details." The condition is spoken as words, so the symbol never needs to be.

---

## 7. The app icon

Covered in [01-brand-identity.md](01-brand-identity.md) §3. Two rules bear repeating here:

> Be sure to understand the terms and conditions for using SF Symbols, including the prohibition
> against using symbols — or images that are confusingly similar — in app icons, logos, or any other
> trademarked use.
> — [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)

The LGKA+ icon is original artwork of the school's entrance — lions, pillars, arch — and contains no
SF Symbol. Correct.

> **Avoid using replicas of Apple hardware products.** Hardware designs tend to change frequently
> and can make your interface icons and other content appear dated.
> — [Icons](https://developer.apple.com/design/human-interface-guidelines/icons)

No device imagery appears anywhere in the app.

---

## 8. Do / don't

- [x] Check Apple's standard-action table before picking a symbol for a common action.
- [x] Use the outline variant in toolbars and rows, the fill variant for weather and status.
- [x] Build empty/error pairs from the same symbol family, using a `.badge.*` suffix for failure.
- [x] Wrap toolbar glyphs in `Label(text, systemImage:)`, never a bare `Image`.
- [x] Mark decorative glyphs `accessibilityHidden(true)`.
- [ ] Don't draw a custom glyph. If SF Symbols lacks it, reconsider the concept first.
- [ ] Don't use `.multicolor` outside weather.
- [ ] Don't put an SF Symbol in the app icon.
- [ ] Don't tint a status or error glyph with the accent. Those use `.secondary` at reduced opacity.

---

## Sources

| Source | Kind | Accessed |
|---|---|---|
| [`App/SchoolAPI.swift`](../App/SchoolAPI.swift) | App source | 2026-09-12 |
| [`App/HomeScreen.swift`](../App/HomeScreen.swift) | App source | 2026-09-12 |
| [`App/WeatherPage.swift`](../App/WeatherPage.swift) | App source | 2026-09-12 |
| [`App/NewsViews.swift`](../App/NewsViews.swift) | App source | 2026-09-12 |
| [`App/OnboardingViews.swift`](../App/OnboardingViews.swift) | App source | 2026-09-12 |
| [`App/SettingsSheet.swift`](../App/SettingsSheet.swift) | App source | 2026-09-12 |
| [`App/PdfViewerScreen.swift`](../App/PdfViewerScreen.swift) | App source | 2026-09-12 |
| [`App/WebViews.swift`](../App/WebViews.swift) | App source | 2026-09-12 |
| [`App/Theme.swift`](../App/Theme.swift) | App source | 2026-09-12 |
| [`App/AppIcon.icon/icon.json`](../App/AppIcon.icon/icon.json) | App source | 2026-09-12 |
| [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) | Apple HIG | 2026-09-12 |
| [Icons](https://developer.apple.com/design/human-interface-guidelines/icons) | Apple HIG | 2026-09-12 |
| [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) | Apple HIG | 2026-09-12 |
| [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) | Apple HIG | 2026-09-12 |
| [Typography](https://developer.apple.com/design/human-interface-guidelines/typography) | Apple HIG | 2026-09-12 |
