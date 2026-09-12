# Screens

| | |
|---|---|
| **Last updated** | 2026-09-12 |
| **Applies to** | LGKA+ iOS (iOS 26, Swift 6.3, Xcode 26.6) |
| **Owner** | Luka Löhr |
| **Status** | Adopted |

---

## How these screenshots are made

The captures are produced by an XCUITest suite, `UITests/ScreenshotTests.swift`, run on the
simulator — no manual navigation and no coordinates. Every path below is stable:

```
app_store_assets/screenshots/<de|en>/ios/<phone|tablet>/<dark|light>/NN_name.png
```

Phone captures are iPhone 17 Pro Max at 1320x2868; tablet captures are iPad Pro 13-inch at
2064x2752. The status bar is overridden to 09:41. Regenerate with:

```bash
LGKA_LOGIN=user:pass scripts/screenshots.sh               # de/en x phone/tablet x dark/light
LGKA_LOGIN=user:pass scripts/screenshots.sh dark phone    # one theme / form factor
```

> **Note**
> The grids below reference all eight variants of each screen. Variants the suite has not written
> yet render as broken images on GitHub; the paths are correct and fill in on the next run.

Debug builds seed state from launch environment variables so the suite can reach each screen
deterministically: `LGKA_DEBUG_LOGIN`, `LGKA_DEBUG_ACCENT`, `LGKA_DEBUG_THEME`, `LGKA_DEBUG_CLASS`,
`LGKA_DEBUG_RESET` — see `DebugSeed` in [`App/LGKAApp.swift`](../App/LGKAApp.swift).

---

## Contents

1. [Welcome](#1-welcome)
2. [Home](#2-home)
3. [Weather](#3-weather)
4. [News list](#4-news-list)
5. [Article](#5-article)
6. [Substitution plan (PDF)](#6-substitution-plan-pdf)
7. [Settings](#7-settings)
8. [Home, first run](#8-home-first-run)

---

## 1. Welcome

`01_welcome.png`

The first screen of a fresh install. A 160 pt `OnboardingLogo`, „Willkommen!" in `largeTitle.bold`, and a centred `callout` subtitle in `.secondary`. The navigation bar is hidden entirely (`.toolbar(.hidden, for: .navigationBar)`); the only control is a full-width `.glassProminent` button attached with `.safeAreaInset(edge: .bottom)`.

- 32 pt horizontal gutter — the widest in the app, see [04-layout-and-spacing.md](04-layout-and-spacing.md).
- The logo is `accessibilityHidden(true)`; the headline carries `.isHeader`.
- Continue fires `Haptics.light()`.
- Identifier: `onboarding.continue`.

<table>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/01_welcome.png" width="180"><br><sub>de · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/light/01_welcome.png" width="180"><br><sub>de · phone · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/dark/01_welcome.png" width="180"><br><sub>en · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/light/01_welcome.png" width="180"><br><sub>en · phone · light</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/dark/01_welcome.png" width="220"><br><sub>de · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/light/01_welcome.png" width="220"><br><sub>de · tablet · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/dark/01_welcome.png" width="220"><br><sub>en · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/light/01_welcome.png" width="220"><br><sub>en · tablet · light</sub></td>
  </tr>
</table>

---

## 2. Home

`02_home.png`

The hub. An `.insetGrouped` `List` of four sections: an unlabelled weather section, „Vertretungsplan", „Stundenplan", „Bevorstehende Termine". The title „LGKA+" is inline; three toolbar symbols — `newspaper`, `cross.case`, `gearshape` — sit in one `ToolbarItemGroup` and therefore render as a single Liquid Glass capsule.

- The weather card is a `listRowBackground` containing the live Metal sky, clipped to a 10 pt continuous radius with an 18 % black scrim.
- Substitution rows show weekday, date and entry count; each opens a PDF in a full-screen cover.
- The timetable row shows the saved class and semester, with a `.contextMenu` to change it.
- Events are capped at four, each with a 44 pt accent date tile.
- Pull to refresh calls `loadAll(mode: .refresh)` with `Haptics.medium()`.
- Identifiers: `home.weather`, `home.plan.today`, `home.plan.tomorrow`, `home.news`, `home.sick`, `home.settings`.

<table>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/02_home.png" width="180"><br><sub>de · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/light/02_home.png" width="180"><br><sub>de · phone · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/dark/02_home.png" width="180"><br><sub>en · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/light/02_home.png" width="180"><br><sub>en · phone · light</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/dark/02_home.png" width="220"><br><sub>de · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/light/02_home.png" width="220"><br><sub>de · tablet · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/dark/02_home.png" width="220"><br><sub>en · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/light/02_home.png" width="220"><br><sub>en · tablet · light</sub></td>
  </tr>
</table>

---

## 3. Weather

`03_weather.png`

Full-bleed animated sky under a `ScrollView`. The hero is a 96 pt `.thin` rounded numeral with a `radius: 8` shadow, over city name, condition and high/low. Below it, three `.thinMaterial` cards at radius 18: hourly, three-day, and a two-column stat grid.

- The navigation bar is pinned with `.toolbarColorScheme(.dark, for: .navigationBar)` so the chevron stays white over any sky.
- Every card sets `.environment(\.colorScheme, .dark)` and falls back to solid `black.opacity(0.7)` under Reduce Transparency.
- The daily rows carry a cyan→yellow range capsule scaled against the week's min and max.
- Rain and snow particles run here but not on the home card; both stop under Reduce Motion.
- An Open-Meteo attribution `Link` closes the scroll.
- Identifier: `weather.page`.

<table>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/03_weather.png" width="180"><br><sub>de · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/light/03_weather.png" width="180"><br><sub>de · phone · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/dark/03_weather.png" width="180"><br><sub>en · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/light/03_weather.png" width="180"><br><sub>en · phone · light</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/dark/03_weather.png" width="220"><br><sub>de · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/light/03_weather.png" width="220"><br><sub>de · tablet · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/dark/03_weather.png" width="220"><br><sub>en · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/light/03_weather.png" width="220"><br><sub>en · tablet · light</sub></td>
  </tr>
</table>

---

## 4. News list

`04_news.png`

An `.insetGrouped` list of `NewsCard` rows inside a `NavigationLink(value:)`. Each card stacks title, two-line description, a `ViewThatFits` metadata row (author · date · views), up to three accent tag capsules, and a „Mehr erfahren →" affordance that is hidden from VoiceOver.

- Navigation is value-based on the article metadata, so a background refresh cannot invalidate an open detail.
- Empty state: `ContentUnavailableView` with `newspaper`. Failure: `wifi.exclamationmark` plus a `.bordered` retry.
- Identifier: `news.row`.

<table>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/04_news.png" width="180"><br><sub>de · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/light/04_news.png" width="180"><br><sub>de · phone · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/dark/04_news.png" width="180"><br><sub>en · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/light/04_news.png" width="180"><br><sub>en · phone · light</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/dark/04_news.png" width="220"><br><sub>de · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/light/04_news.png" width="220"><br><sub>de · tablet · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/dark/04_news.png" width="220"><br><sub>en · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/light/04_news.png" width="220"><br><sub>en · tablet · light</sub></td>
  </tr>
</table>

---

## 5. Article

`05_news_detail.png`

A `ScrollView` with 20 pt padding and no navigation title — the `title2.bold` heading in the content carries the name. Below it a `caption` metadata row, then the article body as an `AttributedString` with the school's own links made tappable, underlined and accent-coloured, and `.textSelection(.enabled)`.

- Images load with `AsyncImage` behind a `.quaternary` placeholder at 180 pt, clipped to radius 12, labelled with the HTML `alt` or the article title.
- Downloads and standalone links become `SurfaceCard` rows at radius 12, minimum 44 pt tall.
- „Weitere Neuigkeiten" lists up to three other articles as cards.
- The only toolbar item is a `safari` `Link` to the original page.
- Identifier: `news.detail`.

<table>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/05_news_detail.png" width="180"><br><sub>de · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/light/05_news_detail.png" width="180"><br><sub>de · phone · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/dark/05_news_detail.png" width="180"><br><sub>en · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/light/05_news_detail.png" width="180"><br><sub>en · phone · light</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/dark/05_news_detail.png" width="220"><br><sub>de · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/light/05_news_detail.png" width="220"><br><sub>de · tablet · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/dark/05_news_detail.png" width="220"><br><sub>en · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/light/05_news_detail.png" width="220"><br><sub>en · tablet · light</sub></td>
  </tr>
</table>

---

## 6. Substitution plan (PDF)

`06_plan.png`

A `fullScreenCover` hosting `PDFKit` with `autoScales`. Leading `xmark`, trailing `magnifyingglass` and a `ShareLink`. `.searchable` is revealed by the toolbar toggle with the prompt „Im PDF suchen".

- This is the only screen that may rotate; `OrientationLock` opens on appear and restores portrait on disappear.
- Matches are highlighted in `systemYellow`; a glass stepper in the bottom safe-area inset shows `3/17` in monospaced digits with `chevron.up` / `chevron.down`.
- For a timetable PDF, searching a class code persists the class and can switch to the other grade-level document, then reports the change in a glass toast for two seconds.
- The shared file is renamed `LGKA_Vertretungsplan_…` or `LGKA_Stundenplan_…` before the share sheet opens.

<table>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/06_plan.png" width="180"><br><sub>de · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/light/06_plan.png" width="180"><br><sub>de · phone · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/dark/06_plan.png" width="180"><br><sub>en · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/light/06_plan.png" width="180"><br><sub>en · phone · light</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/dark/06_plan.png" width="220"><br><sub>de · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/light/06_plan.png" width="220"><br><sub>de · tablet · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/dark/06_plan.png" width="220"><br><sub>en · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/light/06_plan.png" width="220"><br><sub>en · tablet · light</sub></td>
  </tr>
</table>

---

## 7. Settings

`07_settings.png`

A `.sheet` with `[.medium, .large]` detents, its own `NavigationStack`, an inline title „Einstellungen" and a trailing `xmark`. Two sections.

- **DARSTELLUNG** — „Erscheinungsbild" with the three-segment theme picker, „Akzentfarbe" with the five-swatch palette picker, both in `LabeledContent` capped at 220 pt.
- **MEHR** — „Fehler gefunden?" (`ladybug`), „Datenschutzerklärung" (`hand.raised`), „Impressum" (`info.circle`), and a destructive „Abmelden" (`rectangle.portrait.and.arrow.right`).
- The footer centres `© 2026 Luka Löhr • v3.0.0` with the name in `.tint`.
- Log out opens a `confirmationDialog` that names the consequence.
- The bug-report row dismisses the sheet first, then pushes, so two modals never coexist.
- Identifier: `settings.close`.

<table>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/07_settings.png" width="180"><br><sub>de · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/light/07_settings.png" width="180"><br><sub>de · phone · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/dark/07_settings.png" width="180"><br><sub>en · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/light/07_settings.png" width="180"><br><sub>en · phone · light</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/dark/07_settings.png" width="220"><br><sub>de · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/light/07_settings.png" width="220"><br><sub>de · tablet · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/dark/07_settings.png" width="220"><br><sub>en · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/light/07_settings.png" width="220"><br><sub>en · tablet · light</sub></td>
  </tr>
</table>

---

## 8. Home, first run

`08_after_login.png`

The same home screen immediately after a successful login: the substitution and event data has arrived from cache, but no class has been chosen yet, so the timetable row shows its empty state — a `graduationcap` square, „In welcher Klasse bist du?" and „Tippe, um deine Klasse festzulegen".

Comparing this against `02_home` is the quickest way to review the app's empty-state behaviour: the row keeps its full 44 pt square, its chevron and its tap target, and asks a question instead of showing a blank.

<table>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/08_after_login.png" width="180"><br><sub>de · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/light/08_after_login.png" width="180"><br><sub>de · phone · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/dark/08_after_login.png" width="180"><br><sub>en · phone · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/phone/light/08_after_login.png" width="180"><br><sub>en · phone · light</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/dark/08_after_login.png" width="220"><br><sub>de · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/tablet/light/08_after_login.png" width="220"><br><sub>de · tablet · light</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/dark/08_after_login.png" width="220"><br><sub>en · tablet · dark</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/en/ios/tablet/light/08_after_login.png" width="220"><br><sub>en · tablet · light</sub></td>
  </tr>
</table>

---

## Screens with no capture

Three destinations are not in the screenshot set. They are listed here so the inventory is complete.

| Screen | Source | Why there is no capture |
|---|---|---|
| Onboarding features, accent, appearance | [`App/OnboardingViews.swift`](../App/OnboardingViews.swift) | The suite captures only `01_welcome` from the flow |
| Krankmeldung info and form | [`App/WebViews.swift`](../App/WebViews.swift) | The form is the school's own web page, behind a live host |
| Bug report | [`App/WebViews.swift`](../App/WebViews.swift) | A Google Form, rendered in a web view |

The Krankmeldung info screen is described in
[11-onboarding-login-and-privacy.md](11-onboarding-login-and-privacy.md) §4.4; the web-view chrome
is described in [07-navigation-and-modality.md](07-navigation-and-modality.md) §7.

---

## Sources

| Source | Kind | Accessed |
|---|---|---|
| `app_store_assets/screenshots/**` | Generated by `UITests/ScreenshotTests.swift` | 2026-09-12 |
| [`App/HomeScreen.swift`](../App/HomeScreen.swift) | App source | 2026-09-12 |
| [`App/WeatherPage.swift`](../App/WeatherPage.swift) | App source | 2026-09-12 |
| [`App/NewsViews.swift`](../App/NewsViews.swift) | App source | 2026-09-12 |
| [`App/OnboardingViews.swift`](../App/OnboardingViews.swift) | App source | 2026-09-12 |
| [`App/SettingsSheet.swift`](../App/SettingsSheet.swift) | App source | 2026-09-12 |
| [`App/PdfViewerScreen.swift`](../App/PdfViewerScreen.swift) | App source | 2026-09-12 |
| [`App/WebViews.swift`](../App/WebViews.swift) | App source | 2026-09-12 |
| [`App/LGKAApp.swift`](../App/LGKAApp.swift) | App source | 2026-09-12 |
| [`README.md`](../README.md) | App source | 2026-09-12 |
