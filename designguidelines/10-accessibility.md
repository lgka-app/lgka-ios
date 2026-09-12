# Accessibility

| | |
|---|---|
| **Last updated** | 2026-09-12 |
| **Applies to** | LGKA+ iOS (iOS 26, Swift 6.3, Xcode 26.6) |
| **Owner** | Luka Löhr |
| **Status** | Adopted, with open verification items |

---

## 1. Scope

LGKA+ is used by every pupil at one school. It is not a product with an addressable market you can
decide to under-serve: if a pupil in that building uses VoiceOver, the app either works for them or
it does not. That is the standard this document holds the app to.

> An accessible interface allows people to experience your app or game regardless of their
> capabilities or how they use their devices. Accessibility makes information and interactions
> available to everyone. An accessible interface is: **Intuitive** … **Perceivable** … **Adaptable**.
> — [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

---

## 2. Vision

### 2.1 Dynamic Type

- [x] Every text style is a system style — see [03-typography.md](03-typography.md).
- [x] The two custom sizes are `@ScaledMetric(relativeTo: .largeTitle)`.
- [x] `IconSquare` is `@ScaledMetric(relativeTo: .body)`, so the glyph square grows with its label.
- [x] Both metadata rows in the news UI use `ViewThatFits` to stack when horizontal space runs out.

```swift
ViewThatFits(in: .horizontal) {
    HStack(spacing: 12) { metaLabels }
    VStack(alignment: .leading, spacing: 4) { metaLabels }
}
```

> **Support larger text sizes.** … Ideally, give people the option to enlarge text by at least 200
> percent (or 140 percent in watchOS apps).
> — [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

**Open verification items.** These have not been checked at accessibility type sizes in this pass:

- [ ] The home weather card. It is `minHeight: 112` with four `lineLimit(1)` strings stacked in the
      leading column. At AX5 the temperature alone may consume the card.
- [ ] The 44 pt `dateTile` in the events section is a **fixed** `frame(width: 44, height: 44)`, not
      a `@ScaledMetric` like `IconSquare`. The day number is `title3.bold` and will clip first.
- [ ] The `ThemeModePicker` at `maxWidth: 220` inside `LabeledContent` — three German words in a
      segmented control at a large type size is the classic truncation case.
- [ ] The daily forecast row's fixed widths: 52 pt day label, 28 pt symbol, 36 pt precipitation.

The fix pattern is already in the codebase — use `@ScaledMetric` as `IconSquare` does, or
`ViewThatFits` as `NewsCard` does.

### 2.2 Contrast

> Accessibility Inspector uses the following values from WCAG Level AA as guidance …
> Up to 17 pts — all weights — **4.5:1**; 18 pts — all weights — **3:1**; all sizes, bold — **3:1**.
> — [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

Where contrast is handled well:

- Semantic label colours (`.primary` / `.secondary` / `.tertiary`) carry Apple's own contrast
  guarantees in both appearances and under Increase Contrast.
- White-on-sky text always carries a shadow — `black.opacity(0.3)` radius 4 on the card,
  `black.opacity(0.25)` radius 8 on the page hero.
- The home weather card adds an 18 % black gradient scrim over the bottom of the sky.

> **Aim for sufficient color contrast in all appearances.** … At a minimum, make sure the contrast
> ratio between colors is no lower than 4.5:1. For custom foreground and background colors, strive
> for a contrast ratio of 7:1, especially in small text.
> — [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)

**Measured, 2026-09-12.** The five accents have been computed against white, the light grouped
background and black. Full table in [02-color.md](02-color.md) §2.2. The finding that matters here:

| | Light mode | Dark mode |
|---|---|---|
| `blue` `#3770D4` | 4.74 on white — clears AA | 4.43 on black |
| `lavender` `#9B6BDF` | 3.38 on `#F2F2F7` — large text only | 5.56 |
| `peach` `#BF7F46` | 2.97 on `#F2F2F7` — below 3:1 | 6.34 |
| `rose` `#C47A7A` | 2.94 on `#F2F2F7` — below 3:1 | 6.41 |
| `mint` `#45A88A` | 2.61 on `#F2F2F7` — below 3:1 | 7.22 |

Consequence: accent-coloured **text at body or caption size on a light surface fails AA for four of
the five accents**. Two places in the app do this — the news tag capsules and the inline links in
article text. Both are fine under the default `blue` and degrade under the rest. The remedy is a
colour-system change (light/dark variants per accent), not a per-view fix; it is tracked as an open
item in [02-color.md](02-color.md) §2.4.

In dark mode all five clear 4.4:1, so this is a light-mode problem only.

**Still open:**

- [ ] `.tertiary` on the news meta row at caption size — the lowest-contrast text in the app.
- [ ] The `caption2` „Gefühlt 24° · 14° – 26°" line at `opacity(0.8)` over a bright sky.
- [ ] `.cyan` precipitation percentages inside a `.thinMaterial` card over a bright day sky.

### 2.3 Reduce Transparency

Handled explicitly on the weather page, which is the only screen where a material carries essential
text over an unpredictable image:

```swift
private func cardBackground() -> some ShapeStyle {
    // Reduce Transparency: fall back to a solid dark surface.
    reduceTransparency
        ? AnyShapeStyle(Color.black.opacity(0.7))
        : AnyShapeStyle(.thinMaterial)
}
```

- [ ] The `.regularMaterial` schedule-loading overlay and the `.glassEffect()` PDF stepper have no
      explicit fallback. They rely on the system's own adaptation, which is usually enough, but the
      PDF stepper sits over a black-on-white table and should be spot-checked with the setting on.

### 2.4 Colour is never the only signal

| Signal | Non-colour channel |
|---|---|
| Accent swatch selected | `circle.fill` → `checkmark.circle.fill` — a **shape** change |
| Substitution plan unavailable | Different text, lower opacity, no chevron, `.disabled` |
| Login failed | Haptic + glyph + a written message in the form footer |
| Login succeeded | Haptic + `checkmark` glyph |
| Precipitation likely | A percentage number, not only a cyan tint |
| Destructive log-out | `role: .destructive` **and** the word „Abmelden" **and** a confirmation dialog |

> **Convey information with more than color alone.** Some people have trouble differentiating
> between certain colors and shades. … Offer visual indicators, like distinct shapes or icons, in
> addition to color.
> — [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

### 2.5 Dark Mode

Both appearances are supported and can be forced per-app. See
[02-color.md](02-color.md) §6, which records the deviation from the HIG's advice against app-level
appearance settings, and the mitigation (the default is „Auto").

---

## 3. VoiceOver

### 3.1 Composed elements

Any row made of a glyph plus two labels is collapsed into one element with one spoken sentence.

```swift
.accessibilityElement(children: .ignore)
.accessibilityLabel(L.f("a11y.subPlan", title, subtitle ?? ""))
.accessibilityAddTraits(canOpen ? .isButton : [])
```

Two composition modes are used deliberately:

| Modifier | Where | Effect |
|---|---|---|
| `children: .ignore` + explicit label | Home cards, weather card, events, hourly columns, daily rows, stat tiles | Full control over the sentence |
| `children: .combine` | News cards, onboarding feature rows, weather hero | Concatenates the child labels |

`.ignore` is used wherever the visible text is abbreviated („H: 26° T: 14°", „14 Sep") and a spoken
version needs to be different from the printed one. `.combine` is used where the visible text
already reads as a sentence.

### 3.2 The accessibility string set

Fifteen dedicated keys exist in [`Localizable.xcstrings`](../App/Localizable.xcstrings), all
prefixed `a11y.`. They are localised into German and English like any other copy.

| Key | German | Purpose |
|---|---|---|
| `a11y.weatherCard` | „Wetter in Karlsruhe: %1$@, %2$lld Grad. Tippen für Details." | The whole home weather card |
| `a11y.subPlan` | „Vertretungsplan %1$@, %2$@" | Substitution row |
| `a11y.event` | „%1$@: %2$@" | Event row — date first, then title |
| `a11y.hour` | „%1$@ Uhr, %2$lld Grad, %3$@" | One hourly column |
| `a11y.day` | „%1$@: %2$@, Höchstwert %3$lld Grad, Tiefstwert %4$lld Grad" | One daily row |
| `a11y.precipitation` | „%lld Prozent Regenwahrscheinlichkeit" | Precipitation |
| `a11y.matchPosition` | „Treffer %1$lld von %2$lld" | PDF match counter |
| `a11y.nextMatch` / `a11y.previousMatch` | „Nächster/Vorheriger Treffer" | Stepper buttons |
| `a11y.search` | „Im PDF suchen" | PDF search toggle |
| `a11y.share` | „PDF teilen" | Share button |
| `a11y.close` | „Schließen" | Close buttons |
| `a11y.retry` | „Erneut laden" | Retry glyph buttons |
| `a11y.openInBrowser` | „Im Browser öffnen" | Safari button |
| `a11y.skyPreview` | „Himmel-Vorschau" | Debug-only sky menu |

This is the part of the app's accessibility work that is genuinely strong. The labels **expand
abbreviations into words**: „Grad" not „°", „Höchstwert" not „H:", „Prozent Regenwahrscheinlichkeit"
not „78 %". A screen reader user gets the meaning, not a transcription of the glyphs.

The weather card label even carries an instruction — „Tippen für Details." — which the HIG warns
about in general, but here the card looks like a status display rather than a control, so naming the
gesture is the more helpful choice. (`accessibilityHint` would be the more idiomatic home for it.)

### 3.3 Traits

| Trait | Applied to |
|---|---|
| `.isButton` | Every `.buttonStyle(.plain)` card, since plain style drops the trait |
| `.isHeader` | Onboarding headlines, login title, article title, „Weitere Neuigkeiten", weather card headers |
| `.updatesFrequently` | Loading overlay, login error footer, PDF feedback toast |

`.updatesFrequently` is the right trait on the transient messages discussed in
[08-motion-and-feedback.md](08-motion-and-feedback.md) — it tells VoiceOver the value will change.

### 3.4 Hidden decoration

`accessibilityHidden(true)` on: the sky view, the onboarding logo, `IconSquare`, `dateTile`, the
fireworks overlay, the „Mehr erfahren →" affordance, and every inert status glyph in an error row.

Nothing decorative reaches the rotor.

### 3.5 Images

Article images carry a real label:

```swift
.accessibilityLabel(image.alt ?? md.title)
```

The `alt` attribute from the school's HTML when present, and the article title as a fallback. That
is the right fallback — a generic "image" would be worse than the article's own name.

---

## 4. Mobility

| Requirement | Status |
|---|---|
| 44×44 pt controls | ✅ `IconSquare`, date tiles, retry buttons, article links, cards — see [04-layout-and-spacing.md](04-layout-and-spacing.md) §4 |
| Whole row tappable | ✅ `.contentShape(Rectangle())` everywhere |
| No custom multi-finger gestures | ✅ Tap, scroll, pull-to-refresh, swipe-to-dismiss — all system |
| Alternatives to gestures | ✅ Every modal has a visible dismiss button as well as a swipe |

> **Offer alternatives to gestures.** Make sure your UI's core functionality is accessible through
> more than one type of physical interaction. … For example, if you use a swipe gesture to dismiss a
> view, also make a button available so people can tap or use an assistive device.
> — [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

**Two gestures need review:**

- [ ] `.contextMenu` on the timetable card is the only way to change class from the home screen
      without clearing it. A long press is not discoverable and is hard for some users. Settings, or
      a visible edit affordance, would be a real improvement.
- [ ] `.onLongPressGesture` on the weather hero opens the sky-preview menu. This is `#if DEBUG` only,
      so it does not ship — but do not promote it to release without a visible control.

---

## 5. Hearing and speech

The app plays no audio and has no video, so captions and transcripts do not apply. Haptics
supplement visual feedback rather than substituting for audio — see
[08-motion-and-feedback.md](08-motion-and-feedback.md) §4.

Keyboard navigation: the login form implements a proper submit chain.

```swift
TextField(...).submitLabel(.next).onSubmit { focus = .password }
SecureField(...).submitLabel(.go).onSubmit { if canLogin { validate() } }
```

> **Ensure that tabbing between multiple fields flows as people expect.** When tabbing between
> fields, move focus in a logical sequence.
> — [Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields)

- [ ] Full Keyboard Access has not been tested. The app is all standard controls, which is the best
      possible starting position, but the claim is unverified.

---

## 6. Cognitive

| Practice | Evidence |
|---|---|
| Few, familiar interactions | Tap a row, pull to refresh, swipe to go back. No custom gestures. |
| Short flows | Onboarding is four screens plus login; settings is six items. |
| Sensible defaults | Accent „blue", theme „system" — a user can skip every choice and be fine. |
| Confirmation before irreversible actions | Log-out uses a confirmation dialog naming the consequence. |
| Errors explain, never blame | „Zugangsdaten sind falsch." not „Ungültige Eingabe". |

> **Keep actions simple and intuitive.** Ensure that people can navigate your interface using
> easy-to-remember and consistent interactions. Prefer system gestures and behaviors people are
> already familiar with over creating custom gestures people must learn and retain.
> — [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

> **Aim to provide default settings that give the best experience to the largest number of people.**
> — [Settings](https://developer.apple.com/design/human-interface-guidelines/settings)

- [ ] **Assistive Access** has not been evaluated. For a school app used by a full age and ability
      range this is worth a pass: identify the core flow (substitution plan → PDF) and check it
      survives the streamlined presentation.

---

## 7. UI test identifiers

The XCUITest screenshot suite navigates by identifier, which doubles as an accessibility audit
surface — an element with a stable identifier is an element the automation, and therefore
assistive technology, can find.

| Identifier | Element |
|---|---|
| `onboarding.continue` | The „Weiter" / „Los geht's!" button on all four onboarding screens |
| `auth.username`, `auth.password`, `auth.login` | Login form |
| `home.news`, `home.sick`, `home.settings` | Home toolbar |
| `home.weather` | Weather card |
| `home.plan.today`, `home.plan.tomorrow` | Substitution rows |
| `settings.close` | Settings sheet close |
| `news.row`, `news.detail` | News list row, article |
| `weather.page` | Weather scroll view |

---

## 8. Verification checklist

Run this list before each release. Nothing here is currently signed off.

- [ ] VoiceOver: traverse home → weather → news → article → PDF → settings. Every element announces
      something meaningful; nothing announces "button" with no name.
- [ ] Dynamic Type at AX5: no clipped text, no overlapping rows, no unreachable button.
- [ ] Increase Contrast, light and dark.
- [ ] Reduce Transparency: weather cards, loading overlay, PDF stepper all readable.
- [ ] Reduce Motion: sky frozen, no particles, no fireworks, information unchanged.
- [x] Contrast measurement of the five accents on both surfaces — done 2026-09-12, see
      [02-color.md](02-color.md) §2.2. The light-mode failure for the four non-blue accents
      is an open design decision, not an unmeasured unknown.
- [ ] Full Keyboard Access through the login form and the home list.
- [ ] Assistive Access on the substitution-plan flow.
- [ ] Accessibility Inspector audit on every screen.

> As you design your app, audit the accessibility of your interface. Use Accessibility Inspector to
> highlight accessibility issues with your interface and to understand how your app represents
> itself to people using system accessibility features.
> — [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

---

## Sources

| Source | Kind | Accessed |
|---|---|---|
| [`App/HomeScreen.swift`](../App/HomeScreen.swift) | App source | 2026-09-12 |
| [`App/WeatherPage.swift`](../App/WeatherPage.swift) | App source | 2026-09-12 |
| [`App/WeatherSky.swift`](../App/WeatherSky.swift) | App source | 2026-09-12 |
| [`App/NewsViews.swift`](../App/NewsViews.swift) | App source | 2026-09-12 |
| [`App/OnboardingViews.swift`](../App/OnboardingViews.swift) | App source | 2026-09-12 |
| [`App/SettingsSheet.swift`](../App/SettingsSheet.swift) | App source | 2026-09-12 |
| [`App/PdfViewerScreen.swift`](../App/PdfViewerScreen.swift) | App source | 2026-09-12 |
| [`App/Theme.swift`](../App/Theme.swift) | App source | 2026-09-12 |
| [`App/Localizable.xcstrings`](../App/Localizable.xcstrings) | App source | 2026-09-12 |
| [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Apple HIG | 2026-09-12 |
| [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) | Apple HIG | 2026-09-12 |
| [Typography](https://developer.apple.com/design/human-interface-guidelines/typography) | Apple HIG | 2026-09-12 |
| [Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields) | Apple HIG | 2026-09-12 |
| [Settings](https://developer.apple.com/design/human-interface-guidelines/settings) | Apple HIG | 2026-09-12 |
