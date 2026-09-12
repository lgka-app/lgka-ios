# Motion and Feedback

| | |
|---|---|
| **Last updated** | 2026-09-12 |
| **Applies to** | LGKA+ iOS (iOS 26, Swift 6.3, Xcode 26.6) |
| **Owner** | Luka Löhr |
| **Status** | Adopted |

---

## 1. Motion inventory

There is very little custom motion in LGKA+, and that is on purpose. Four things move that the
system did not move on its own.

| # | Motion | Where | Respects Reduce Motion |
|---|---|---|---|
| 1 | The sky shader — drifting clouds, twinkling stars, pulsing sun | Weather card and page | **Yes** — the timeline pauses |
| 2 | Rain and snow particles | Weather page only | **Yes** — not created at all |
| 3 | Login button colour flash | Login | n/a — a 0.3 s colour crossfade |
| 4 | New Year's fireworks | App-wide overlay, 1 January only | **Yes** — not created at all |

Everything else — push transitions, sheet presentation, list insertion, search bar reveal, glass
morphing — is the system's.

> **In apps, generally avoid adding motion to UI interactions that occur frequently.** The system
> already provides subtle animations for interactions with standard interface elements. For a
> custom element, you generally want to avoid making people spend extra time paying attention to
> unnecessary motion every time they interact with it.
> — [Motion](https://developer.apple.com/design/human-interface-guidelines/motion)

The one explicit `withAnimation` in the app is the login flash reset; the one explicit
`.animation(...)` modifier is on that same button. Two animation calls in ~3,200 lines of view code.

---

## 2. The sky

[`App/WeatherSky.swift`](../App/WeatherSky.swift) drives [`App/Sky.metal`](../App/Sky.metal) from a
`TimelineView`:

```swift
struct MetalSky: View {
    let cloudiness: Double
    let isDay: Bool
    var animated = true
    private let start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { timeline in
            Rectangle().colorEffect(ShaderLibrary.sky(
                .boundingRect,
                .float(Float(timeline.date.timeIntervalSince(start))),
                .float(Float(cloudiness)),
                .float(isDay ? 1 : 0)))
        }
    }
}
```

**30 fps, not 60.** The motion is a slow atmospheric drift — cloud layers advance at `time * 0.020`
and `time * 0.045` in uv space — so doubling the frame rate would cost battery and buy nothing.

> **Make sure your game's motion looks great by default on each platform you support.** In most
> games, maintaining a consistent frame rate of 30 to 60 fps typically results in a smooth,
> visually appealing experience.
> — [Motion](https://developer.apple.com/design/human-interface-guidelines/motion)

Motion sources inside the shader, all time-driven and all slow:

| Element | Rate |
|---|---|
| Cloud layer 1 | `time * 0.020` horizontal |
| Cloud layer 2 | `time * 0.045` horizontal |
| Sun pulse | `0.95 + 0.05 * sin(time * 0.8)` — a 5 % amplitude breath |
| Faint star twinkle | `0.55 + 0.45 * sin(time * (0.4 + h * 1.6) + h * 40.0)` |
| Bright star twinkle | `0.65 + 0.35 * sin(time * (0.5 + h * 2.0) + h * 60.0)` |
| Dither grain | `fract(time)` — re-seeded per frame |

Per-star phase offsets (`h * 40.0`, `h * 60.0`) keep the field from pulsing in unison, which would
read as a flicker rather than as a sky.

### 2.1 Reduce Motion

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
// …
MetalSky(cloudiness: cloudiness, isDay: isDay, animated: !reduceMotion)
if particles && !reduceMotion { /* VortexView(.rain) / .snow */ }
```

With Reduce Motion on, the timeline pauses — the sky becomes a still image with the correct colour,
cloud shape and star field for the conditions — and the particle emitters are never constructed. The
information is unchanged; only the movement is gone. That is the standard the HIG asks for.

> **Be cautious with fast-moving and blinking animations.** … People who are prone to these effects
> can turn on the Reduce Motion accessibility setting. When this setting is active, ensure your app
> or game responds by reducing automatic and repetitive animations, including zooming, scaling, and
> peripheral motion.
> — [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

The `.id("\(code)-\(isDay)")` on the sky view forces a clean rebuild when conditions change, rather
than animating between two unrelated skies.

---

## 3. Fireworks

[`App/SettingsSheet.swift`](../App/SettingsSheet.swift) carries `FireworksOverlay`, installed
app-wide in `LGKAApp`:

```swift
static func isNewYearsDay() -> Bool {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
    let comps = cal.dateComponents([.month, .day], from: Date())
    return comps.month == 1 && comps.day == 1
}
```

A `CAEmitterLayer` with five `systemColor` cells, additive blending, `birthRate: 1.2`,
`lifetime: 2.2`, positioned at 30 % of the view height. It is `allowsHitTesting(false)` and
`accessibilityHidden(true)`, so it can never intercept a tap or reach VoiceOver, and it is gated on
`!reduceMotion`. The date is re-checked every 60 seconds so the app crosses midnight correctly.

This is the app's one piece of pure delight. It is scoped to a single day of the year, it blocks
nothing, and it is switchable off by a system setting — which is precisely the shape a gratuitous
animation has to have to be acceptable.

---

## 4. Haptics

One enum, five functions, [`App/Theme.swift`](../App/Theme.swift):

```swift
@MainActor
enum Haptics {
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func intense() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
```

### 4.1 The intensity grammar

| Intensity | Meaning | Call sites |
|---|---|---|
| `light()` | Acknowledgement — a panel opens, a preference changes, a state toggles | Every toolbar button; retry buttons; picker `onChange`; onboarding "Weiter" on the welcome screen; opening the class dialog; PDF close, search toggle and match stepping; „Zur Krankmeldung" |
| `medium()` | Commitment — you are leaving for real content | Opening the weather page; opening a substitution PDF; opening a timetable; pull-to-refresh; onboarding "Weiter" on the feature, accent and appearance screens |
| `success()` | The server said yes | Login verified |
| `error()` | The server said no, or the Keychain refused | Login failed |
| `intense()` | *Defined but never called* | — |

The light/medium split is consistent and meaningful: light for "the UI reacted", medium for "you
have committed to a navigation or a network fetch". Keep it.

> **Make sure all feedback is accessible.** When you use multiple ways to provide feedback, you
> reach more people and give them the opportunity to receive the feedback in ways that work for
> them. For example, when you provide feedback using color, text, sound, and haptics, people can
> receive it whether they silence their device, look away from the screen, or use VoiceOver.
> — [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback)

> **Use haptics in addition to audio cues.** If your interface conveys information through audio
> cues … consider pairing that sound with matching haptics.
> — [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

Login is the model case: the result arrives as **haptic + colour + glyph + text** simultaneously —
`Haptics.success()`, a green tint, a `checkmark`, and on failure a red message in the form footer.
No single channel carries it alone.

- [ ] `Haptics.intense()` is dead code. Either find the interaction that deserves it or delete it.

---

## 5. The login flash

The only hand-written animation in the app, [`App/OnboardingViews.swift`](../App/OnboardingViews.swift):

| Phase | Tint | Content | Haptic | Duration |
|---|---|---|---|---|
| Idle | accent | „Anmelden" | — | — |
| Loading | accent | `ProgressView().tint(.white)` | — | until the request returns |
| Success | `.green` | `checkmark` | `success()` | 400 ms, then sign in |
| Failure | `.red` | „Anmelden" + red footer message | `error()` | 700 ms, then fade back |

```swift
.animation(.easeInOut(duration: 0.3), value: flash)
```

Both hold durations are short and neither blocks anything — the success hold exists so the checkmark
is perceptible before the screen swaps, and the failure hold clears itself.

> **Minimize use of time-boxed interface elements.** Views and controls that auto-dismiss on a timer
> can be problematic for people who need longer to process information … Prefer dismissing views
> with an explicit action.
> — [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

The mitigation is that the *information* is not time-boxed: the red error text in the form footer
persists after the button flash ends, and is marked `.accessibilityAddTraits(.updatesFrequently)`
so VoiceOver announces it. Only the decoration is timed.

The same pattern governs the PDF feedback toast — it holds for 2 seconds — which is acceptable for
the same reason: the outcome it reports (class changed, no match) is also visible in the title and
in the stepper.

---

## 6. Loading

Three strategies, matched to how much is known about the pending result.

| Strategy | Used when | Component |
|---|---|---|
| **Redacted skeleton** | The shape of the row is known | `skeletonRow` — a 44 pt block, two text lines, `.redacted(reason: .placeholder)`, `.fill(.quaternary)` |
| **Indeterminate spinner** | A whole screen is pending | `ProgressView()` on the news list, article and weather page |
| **Labelled blocking overlay** | A user-initiated fetch must finish before a screen can open | `ProgressView(L.s("loadingSchedule"))` on `.regularMaterial`, radius 16 |

```swift
ProgressView(L.s("loadingSchedule"))
    .padding(24)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .accessibilityAddTraits(.updatesFrequently)
```

> **Show something as soon as possible.** If you make people wait for loading to complete before
> displaying anything, they can interpret the lack of content as a problem with your app or game.
> Instead, consider showing placeholder text, graphics, or animations as content loads, replacing
> these elements as content becomes available.
> — [Loading](https://developer.apple.com/design/human-interface-guidelines/loading)

> **Clearly communicate that content is loading and how long it might take to complete.** … you use
> a *determinate* progress indicator when you know how long loading will take, and you use an
> *indeterminate* progress indicator when you don't.
> — [Loading](https://developer.apple.com/design/human-interface-guidelines/loading)

All progress in LGKA+ is indeterminate, which is correct: these are network fetches of unknown
duration behind HTTP basic auth.

The event section shows **four** skeleton rows while loading, matching the four it will show when
loaded, so the list does not jump.

### 6.1 Cache-first, so loading is rare

The real loading strategy is not a spinner at all. `HomeModel.bootstrap()`
([`App/HomeModel.swift`](../App/HomeModel.swift)) runs two passes:

```swift
Cache.evictStale()
await loadAll(mode: .cacheAny)     // phase 1: show anything cached, instantly
await loadAll(mode: .cacheFirst)   // phase 2: refresh per TTL
bootstrapFinished = true
await prefetchArticles()           // then warm the article cache
```

Then `prefetchArticles()` pulls up to 20 article bodies into the disk cache in a task group, so
opening a news article is usually instant and never shows the spinner at all.

> **Let people do other things in your app or game while they wait for content to load.** Loading
> content in the background helps give people access to other actions.
> — [Loading](https://developer.apple.com/design/human-interface-guidelines/loading)

> **Restore the previous state when your app restarts so people can continue where they left off.**
> — [Launching](https://developer.apple.com/design/human-interface-guidelines/launching)

The disk cache is what makes cold launch feel instant. See [`App/Cache.swift`](../App/Cache.swift):
entries are keyed by a stable FNV-1a hash of the URL — deliberately not `String.hashValue`, which is
seeded per launch — and evicted after 14 days.

---

## 7. Refresh

| Trigger | Scope | Haptic |
|---|---|---|
| Pull to refresh on home | `model.loadAll(mode: .refresh)` | `medium()` |
| Pull to refresh on news | `loadNews(.refresh)` | — |
| Pull to refresh on weather | `loadWeather(.refresh)` | — |
| Scene becomes active | substitution + weather only | — |
| 60-second timer while active | `loadAll()` per TTL | — |

The foreground refresh is debounced against the launch case, which would otherwise fire twice:

```swift
func refreshOnForeground() async {
    guard bootstrapFinished,
          Date().timeIntervalSince(lastForegroundRefresh) > 10 else { return }
    // …
}
```

The 60-second timer is bound to `.task(id: scenePhase)` and guarded by
`guard scenePhase == .active`, so it cannot run in the background.

---

## 8. Symbol animation

LGKA+ uses **no** `SymbolEffect`. Symbols are static everywhere, including the retry glyph, where a
`.rotate` effect would be an obvious candidate.

> **Apply symbol animations judiciously.** While there's no limit to how many animations you can
> add to a view, too many animations can overwhelm an interface and distract people.
> — [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)

Not using them is a defensible position for an app this restrained. If one is ever added, the retry
`arrow.clockwise` during an in-flight refresh is the single best candidate, and it should be the
only one.

---

## 9. Do / don't

- [x] Gate every custom animation on `accessibilityReduceMotion`.
- [x] Pair every state change that matters with at least two channels — haptic, colour, glyph, text.
- [x] `light()` for acknowledgement, `medium()` for commitment. Nothing else.
- [x] Show a redacted skeleton when the row shape is known; a spinner only when it is not.
- [x] Keep timed UI to decoration. Never time out the only copy of a message.
- [ ] Don't animate a frequent interaction. The system already does.
- [ ] Don't run a `TimelineView` above 30 fps for ambient motion.
- [ ] Don't add a haptic to scrolling, to appearing content, or to anything the user did not initiate.

---

## Sources

| Source | Kind | Accessed |
|---|---|---|
| [`App/WeatherSky.swift`](../App/WeatherSky.swift) | App source | 2026-09-12 |
| [`App/Sky.metal`](../App/Sky.metal) | App source | 2026-09-12 |
| [`App/Theme.swift`](../App/Theme.swift) | App source | 2026-09-12 |
| [`App/HomeScreen.swift`](../App/HomeScreen.swift) | App source | 2026-09-12 |
| [`App/HomeModel.swift`](../App/HomeModel.swift) | App source | 2026-09-12 |
| [`App/Cache.swift`](../App/Cache.swift) | App source | 2026-09-12 |
| [`App/OnboardingViews.swift`](../App/OnboardingViews.swift) | App source | 2026-09-12 |
| [`App/SettingsSheet.swift`](../App/SettingsSheet.swift) | App source | 2026-09-12 |
| [`App/PdfViewerScreen.swift`](../App/PdfViewerScreen.swift) | App source | 2026-09-12 |
| [`App/LGKAApp.swift`](../App/LGKAApp.swift) | App source | 2026-09-12 |
| [Motion](https://developer.apple.com/design/human-interface-guidelines/motion) | Apple HIG | 2026-09-12 |
| [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback) | Apple HIG | 2026-09-12 |
| [Loading](https://developer.apple.com/design/human-interface-guidelines/loading) | Apple HIG | 2026-09-12 |
| [Launching](https://developer.apple.com/design/human-interface-guidelines/launching) | Apple HIG | 2026-09-12 |
| [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Apple HIG | 2026-09-12 |
| [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) | Apple HIG | 2026-09-12 |
