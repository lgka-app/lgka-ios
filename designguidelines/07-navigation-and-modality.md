# Navigation and Modality

| | |
|---|---|
| **Last updated** | 2026-09-12 |
| **Applies to** | LGKA+ iOS (iOS 26, Swift 6.3, Xcode 26.6) |
| **Owner** | Luka Löhr |
| **Status** | Adopted |

---

## 1. No tab bar

LGKA+ has one root screen and pushes everything else onto it. There is no `TabView` anywhere in
the source.

That is the right call for this app. A tab bar is for *peer* sections you switch between; LGKA+ has
one hub — the home screen — and a set of destinations you visit and come back from. Adding tabs
would force news, weather and the sick note into a false peerage with the substitution plan.

> **Use a tab bar to support navigation, not to provide actions.** A tab bar lets people navigate
> among different sections of an app … If you need to provide controls that act on elements in the
> current view, use a Toolbars instead.
> — [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)

> **Use the appropriate number of tabs required to help people navigate your app.** As a
> representation of your app's hierarchy, it's important to weigh the complexity of additional tabs
> against the need for people to frequently access each section.
> — [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)

The three toolbar buttons play the role tabs would have, and they are correctly *toolbar* items:
two of them push, one presents a sheet.

---

## 2. The route map

```
RootView  (App/LGKAApp.swift — gates on Prefs)
│
├─ !onboardingCompleted ────────► OnboardingFlow          NavigationStack, path: [Step]
│                                   Welcome
│                                   └► Features
│                                       └► Accent
│                                           └► Appearance
│                                               └► AuthScreen
│
├─ !isSignedIn ────────────────► AuthScreen               (standalone, bar hidden)
│
└─ else ───────────────────────► HomeScreen               NavigationStack, path: NavigationPath
                                   ├─ push  .weather      ► WeatherPageScreen
                                   ├─ push  .news         ► NewsListScreen
                                   │                        └─ push NewsParser.Metadata ► NewsDetailScreen
                                   ├─ push  .krankmeldungInfo  ► KrankmeldungInfoScreen
                                   │           └─ push .krankmeldungForm ► WebScreen (confined host)
                                   ├─ push  .bugReport    ► BugReportScreen (web view)
                                   ├─ sheet               ► SettingsSheet         [.medium, .large]
                                   └─ fullScreenCover     ► PdfViewerScreen       (own NavigationStack)
```

Gating is declarative and re-evaluates live, so signing out returns to `AuthScreen` without any
imperative dismissal:

```swift
struct RootView: View {
    @Environment(Prefs.self) private var prefs
    var body: some View {
        if !prefs.onboardingCompleted { OnboardingFlow() }
        else if !prefs.isSignedIn { AuthScreen() }
        else { HomeScreen() }
    }
}
```

---

## 3. Path types, and why they differ

| Screen | Path type | Reason |
|---|---|---|
| `OnboardingFlow` | `[Step]` — a typed array | One finite, linear flow; an array is the simplest thing that works |
| `HomeScreen` | `NavigationPath` — type-erased | Must hold both `HomeRoute` cases and `NewsParser.Metadata` values |

The source comment on the home path is explicit:

```swift
/// Type-erased so both HomeRoute pushes and value links (news articles) resolve.
@State private var path = NavigationPath()
```

Article navigation is **value-based**, keyed on the article metadata whose `id` is its URL. The
comment in [`App/NewsViews.swift`](../App/NewsViews.swift) explains the design intent: a background
refresh while a detail screen is open can never invalidate the destination, because the path holds
the article, not an index into a list that just changed.

---

## 4. Push vs sheet vs cover

The decision rule in use:

| Presentation | When | Instances |
|---|---|---|
| **Push** | The destination is part of the content hierarchy and you will come back | Weather, news, article, Krankmeldung info, Krankmeldung form, bug report |
| **Sheet** | A short, self-contained adjustment to the app itself | Settings only |
| **Full-screen cover** | A document you read, which needs the entire display and its own rotation policy | PDF viewer only |
| **Alert / dialog** | One question, one decision | Set class, timetable unavailable, log out |

> **Consider using a full-screen modal style for in-depth content or a complex task.** A modal
> experience that fills a window or the device display minimizes distractions, so it can work well
> for presenting videos, photos, or camera views, or to support a multistep task.
> — [Modality](https://developer.apple.com/design/human-interface-guidelines/modality)

> **Present content modally only when there's a clear benefit.** A modal experience takes people
> out of their current context and requires an action to dismiss, so it's important to use modality
> only when it helps people focus or make choices that affect their content or device.
> — [Modality](https://developer.apple.com/design/human-interface-guidelines/modality)

Two modals in the entire app. That is a restrained count, and each earns its place: settings changes
the app's own configuration, and a substitution PDF is a dense landscape table that needs every pixel.

---

## 5. Dismissal

Every modal has an obvious, visible way out, in the position the platform puts it.

| Modal | Dismiss affordance | Placement |
|---|---|---|
| Settings sheet | `xmark` button, `a11y.close` label, id `settings.close` | `.topBarTrailing` |
| Settings sheet | Swipe down (free from `.sheet`) | — |
| PDF viewer | `xmark` button, `a11y.close` label | `.topBarLeading` |
| Alerts | „Abbrechen" with `role: .cancel` | System |
| Log-out dialog | „Abbrechen" with `role: .cancel` | System |

> **Always give people an obvious way to dismiss a modal view.** In general, it works well to
> follow the platform conventions people already know. For example, in iOS, iPadOS, and watchOS
> apps, people typically expect to find a button in the top toolbar or swipe down.
> — [Modality](https://developer.apple.com/design/human-interface-guidelines/modality)

> **Note — a deliberate asymmetry.**
> Settings closes from the **trailing** edge; the PDF closes from the **leading** edge. The HIG
> puts Cancel on the leading edge and Done on the trailing edge of a sheet
> ([Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)). Settings has no
> Done — changes are applied instantly — so its single button reads as "finish", which is trailing.
> The PDF is a full-screen cover rather than a sheet, and its leading `xmark` sits exactly where a
> back chevron would be in a pushed view, which is where the thumb expects it. Both are defensible;
> keep them as they are rather than making them uniform.

No modal in the app can present another modal. The settings → bug report handoff dismisses the
sheet before pushing:

```swift
SettingsSheet(onBugReport: {
    showSettings = false
    path.append(HomeRoute.bugReport)
})
```

> **Let people dismiss a modal view before presenting another one.** Allowing multiple modal views
> to be visible at the same time tends to create visual clutter and can make your app seem
> scattered and disorganized.
> — [Modality](https://developer.apple.com/design/human-interface-guidelines/modality)

---

## 6. The PDF viewer

The most complex destination, [`App/PdfViewerScreen.swift`](../App/PdfViewerScreen.swift). It hosts
`PDFKit` through a `UIViewRepresentable` and wraps it in its own `NavigationStack`.

### 6.1 Chrome

| Placement | Item | Symbol |
|---|---|---|
| `.topBarLeading` | Close | `xmark` |
| `.topBarTrailing` | Toggle search | `magnifyingglass` |
| `.topBarTrailing` | Share | `square.and.arrow.up` via `ShareLink` |
| Title | Weekday, or „Klasse 7b – 1. Halbjahr" | inline |
| `.safeAreaInset(.bottom)` | Match stepper or feedback toast | glass |

`.searchable(text:isPresented:prompt:)` with `prompt: „Im PDF suchen"` and
`.onSubmit(of: .search, runSearch)`. The search field is revealed by the toolbar toggle rather than
always occupying the bar, because reading is the primary task and searching is occasional.

> **Clearly display the current scope of a search.** Use a descriptive placeholder text, a Scope
> bars and tokens, or a title to help reinforce what someone is currently searching.
> — [Searching](https://developer.apple.com/design/human-interface-guidelines/searching)

„Im PDF suchen" names the scope precisely: this searches the open document, not the app.

### 6.2 Cross-PDF class switching

The cleverest interaction in the app. If the open document is a *timetable* and the query looks like
a class — `/j1[12]|\d{1,2}[a-e]/` — then searching does three things instead of one:

1. Persists the class to `prefs.selectedScheduleClass`.
2. If that class lives in the other grade-level group, loads the other PDF, swaps the document,
   retitles the screen, regenerates the share URL and jumps to the class's page.
3. Reports the switch: „Deine Klasse wurde auf Klasse 9b geändert." for two seconds, then clears.

If the class does not exist at all: „Klasse 9Z existiert nicht." This is the HIG's rule that an
error should say what happened, not scold.

> **Write clear error messages.** … display it as close to the problem as possible, avoid blame,
> and be clear about what someone can do to fix it.
> — [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

The feedback appears in the same bottom inset as the match stepper — next to the search, not in an
alert.

### 6.3 Rotation

`OrientationLock.shared.allowAll()` in `onAppear`, `restorePortrait()` in `onDisappear`. See
[04-layout-and-spacing.md](04-layout-and-spacing.md) §6.1.

### 6.4 The page-number contract

`targetPage` is a **display** page. The stored index maps display page = zero-based index + 2, and
both call sites convert the same way:

```swift
if let targetPage { goToPage = max(0, targetPage - 2) }
```

Worth knowing before touching anything that jumps to a page.

---

## 7. Web views

Two, both `WKWebView` via `WebContainer` ([`App/WebViews.swift`](../App/WebViews.swift)).

| Screen | URL | Host confinement |
|---|---|---|
| Krankmeldung form | `drkrankmeldung.lgka-online.de` | `confineToHost: "lgka-online.de"` |
| Bug report | Google Forms | none |

Confinement is a suffix match that is careful about lookalikes:

```swift
/// Host suffix match: "lgka-online.de" confines to that domain and its
/// subdomains, never to unrelated hosts that merely contain the string.
static func isConfined(_ host: String?, to confined: String) -> Bool {
    guard let host else { return false }
    return host == confined || host.hasSuffix("." + confined)
}
```

A `linkActivated` navigation outside the confined host is cancelled and handed to
`UIApplication.shared.open`, so external links leave the app rather than turning the web view into
a browser.

> **Avoid using a web view to build a web browser.** Using a web view to let people briefly access
> a website without leaving the context of your app is fine, but Safari is the primary way people
> browse the web.
> — [Web views](https://developer.apple.com/design/human-interface-guidelines/web-views)

There are no forward/back controls, which matches the HIG's "when appropriate" framing: both
destinations are single-form pages.

Both use `.nonPersistent()` website data stores, which the comment calls "incognito parity".
See [11-onboarding-login-and-privacy.md](11-onboarding-login-and-privacy.md).

---

## 8. Navigation titles

| Screen | Title | Mode |
|---|---|---|
| Home | „LGKA+" | `.inline` |
| Weather | „Wetter Karlsruhe" | `.inline` |
| News list | „Neuigkeiten" | `.inline` |
| Article | *(none)* | `.inline` |
| Krankmeldung info | „Hinweis zur Krankmeldung" | `.inline` |
| Krankmeldung form | „Krankmeldung" | `.inline` |
| Bug report | „Bug Report" | `.inline` |
| Settings sheet | „Einstellungen" | `.inline` |
| PDF | Weekday, or class + semester | `.inline` |
| Onboarding features | „Alle Funktionen im Überblick" | default |
| Welcome, accent, appearance, login | bar hidden or back-only | — |

**Every title is `.inline`.** The app never uses a large title. That is a coherent decision for a
dense, card-based hub, but it does forgo the HIG's orientation aid:

> **Use a large title to help people stay oriented as they navigate and scroll.** By default, a
> large title transitions to a standard title as people begin scrolling the content, and
> transitions back to large when people scroll to the top, reminding them of their current location.
> — [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)

The article screen sets no title at all, letting the `title2.bold` heading in the content carry the
name. That is the Notes pattern the HIG describes and is appropriate here, since article titles are
long and would truncate badly in a bar.

> **Write a concise title.** Aim for a word or short phrase that distills the purpose of the window
> or view, and keep the title under 15 characters long.
> — [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)

„Hinweis zur Krankmeldung" (24) and „Alle Funktionen im Überblick" (27) exceed that. German makes
15 characters an unrealistic target; both render without truncation on iPhone at default type. Flag
them if either ever clips.

---

## 9. Do / don't

- [x] Push for content, sheet for app configuration, cover for a document.
- [x] Navigate news by value, not by index.
- [x] Dismiss the current modal before opening the next.
- [x] Give every modal a visible dismiss control, not only a gesture.
- [x] Confine in-app web views to their host and hand external links to Safari.
- [ ] Don't add a tab bar. If a fourth top-level area appears, re-evaluate — but with a written case.
- [ ] Don't present a sheet from a sheet.
- [ ] Don't use an alert to deliver information that could be an inline message.

---

## Sources

| Source | Kind | Accessed |
|---|---|---|
| [`App/LGKAApp.swift`](../App/LGKAApp.swift) | App source | 2026-09-12 |
| [`App/HomeScreen.swift`](../App/HomeScreen.swift) | App source | 2026-09-12 |
| [`App/NewsViews.swift`](../App/NewsViews.swift) | App source | 2026-09-12 |
| [`App/PdfViewerScreen.swift`](../App/PdfViewerScreen.swift) | App source | 2026-09-12 |
| [`App/WebViews.swift`](../App/WebViews.swift) | App source | 2026-09-12 |
| [`App/SettingsSheet.swift`](../App/SettingsSheet.swift) | App source | 2026-09-12 |
| [`App/OnboardingViews.swift`](../App/OnboardingViews.swift) | App source | 2026-09-12 |
| [Modality](https://developer.apple.com/design/human-interface-guidelines/modality) | Apple HIG | 2026-09-12 |
| [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) | Apple HIG | 2026-09-12 |
| [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) | Apple HIG | 2026-09-12 |
| [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars) | Apple HIG | 2026-09-12 |
| [Searching](https://developer.apple.com/design/human-interface-guidelines/searching) | Apple HIG | 2026-09-12 |
| [Web views](https://developer.apple.com/design/human-interface-guidelines/web-views) | Apple HIG | 2026-09-12 |
| [Writing](https://developer.apple.com/design/human-interface-guidelines/writing) | Apple HIG | 2026-09-12 |
