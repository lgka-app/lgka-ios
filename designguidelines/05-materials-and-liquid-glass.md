# Materials and Liquid Glass

| | |
|---|---|
| **Last updated** | 2026-09-12 |
| **Applies to** | LGKA+ iOS (iOS 26, Swift 6.3, Xcode 26.6) |
| **Owner** | Luka Löhr |
| **Status** | Adopted |

---

## 1. The two layers

iOS 26 splits the interface in two. LGKA+ takes the split seriously enough that it is written
into a source comment at the top of [`App/WeatherPage.swift`](../App/WeatherPage.swift):

```swift
/// Weather — Apple-Weather-style: full-bleed animated sky, big hero
/// typography, standard-material cards scrolling over the scene. The cards
/// are content, so they use standard materials, not Liquid Glass (HIG:
/// "Don't use Liquid Glass in the content layer").
```

> Liquid Glass forms a distinct functional layer for controls and navigation elements — like tab
> bars and sidebars — that floats above the content layer, establishing a clear visual hierarchy
> between functional elements and content.
> — [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)

> **Don't use Liquid Glass in the content layer.** Liquid Glass works best when it provides a
> clear distinction between interactive elements and content, and including it in the content
> layer can result in unnecessary complexity and a confusing visual hierarchy. Instead, use
> Standard materials for elements in the content layer, such as app backgrounds.
> — [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)

---

## 2. Where Liquid Glass appears

| # | Element | API | Layer | Source |
|---|---|---|---|---|
| 1 | Navigation bars on every screen | implicit — `NavigationStack` + `.toolbar` | functional | all screens |
| 2 | The home toolbar trio: news, sick note, settings | implicit — `ToolbarItemGroup` | functional | [`App/HomeScreen.swift`](../App/HomeScreen.swift) |
| 3 | The settings sheet | implicit — `.sheet` + `.presentationDetents` | functional | [`App/SettingsSheet.swift`](../App/SettingsSheet.swift) |
| 4 | Onboarding and login primary buttons | `.buttonStyle(.glassProminent)` | functional | [`App/OnboardingViews.swift`](../App/OnboardingViews.swift) |
| 5 | Krankmeldung "Zur Krankmeldung" button | `.buttonStyle(.glassProminent)` | functional | [`App/WebViews.swift`](../App/WebViews.swift) |
| 6 | PDF search match stepper (prev/next + counter) | `.buttonStyle(.glass)` + `.glassEffect()` | functional | [`App/PdfViewerScreen.swift`](../App/PdfViewerScreen.swift) |
| 7 | PDF transient feedback toast | `.glassEffect()` | functional | [`App/PdfViewerScreen.swift`](../App/PdfViewerScreen.swift) |

Items 1–3 are free: standard components adopt the material on their own.

> **Use Liquid Glass effects sparingly.** Standard components from system frameworks pick up the
> appearance and behavior of this material automatically. If you apply Liquid Glass effects to a
> custom control, do so sparingly. … Limit these effects to the most important functional elements
> in your app.
> — [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)

Items 4–7 are the only explicit `.glassEffect()` / `.buttonStyle(.glass…)` calls in the whole
source tree. Four uses, each a genuine control floating over content:

```swift
// App/PdfViewerScreen.swift — the one custom glass component
private var matchStepper: some View {
    HStack(spacing: 16) {
        Text("\(matchIndex + 1)/\(matches.count)")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
        Button { step(-1) } label: { Label(L.s("a11y.previousMatch"), systemImage: "chevron.up") }
            .buttonStyle(.glass)
        Button { step(1) } label: { Label(L.s("a11y.nextMatch"), systemImage: "chevron.down") }
            .buttonStyle(.glass)
    }
    .labelStyle(.iconOnly)
    .padding(.horizontal, 16).padding(.vertical, 8)
    .glassEffect()
    .padding(.bottom, 8)
}
```

This is the textbook case: a small, persistent control set floating over a scrolling document,
where the document must stay visible underneath.

### 2.1 Prominent buttons

`.glassProminent` is the app's single call-to-action style. It appears at most **once per
screen**, always as the forward action of a step.

> **In general, use a button that has a prominent visual style for the most likely action in a
> view.** … Keep the number of prominent buttons to one or two per view.
> — [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)

> **To emphasize primary actions, apply color to the background rather than to symbols or text.**
> For example, the system applies the app accent color to the background in prominent buttons …
> Refrain from adding color to the background of multiple controls.
> — [Color](https://developer.apple.com/design/human-interface-guidelines/color)

The login button is the only prominent button that changes colour, and only transiently:
`.tint(buttonTint)` swaps to `.green` for 400 ms on success and `.red` for 700 ms on failure, with
`.animation(.easeInOut(duration: 0.3), value: flash)`. See
[08-motion-and-feedback.md](08-motion-and-feedback.md).

---

## 3. Where standard materials appear

Exactly two places, both in the content layer, both correct.

| Element | Material | Source |
|---|---|---|
| Weather page cards — hourly, 3-day, four stat tiles | `.thinMaterial` | [`App/WeatherPage.swift`](../App/WeatherPage.swift) |
| Schedule-loading overlay | `.regularMaterial` | [`App/HomeScreen.swift`](../App/HomeScreen.swift) |

```swift
// App/WeatherPage.swift
private func cardBackground() -> some ShapeStyle {
    // Reduce Transparency: fall back to a solid dark surface.
    reduceTransparency
        ? AnyShapeStyle(Color.black.opacity(0.7))
        : AnyShapeStyle(.thinMaterial)
}
```

Two things to notice.

1. **`.thinMaterial`, not `.regularMaterial`.** Thin lets the sky stay legible through the card,
   which is the whole point of putting the card on a sky.

   > Thicker materials, which are more opaque, can provide better contrast for text and other
   > elements with fine features. Thinner materials, which are more translucent, can help people
   > retain their context by providing a visible reminder of the content that's in the background.
   > — [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)

2. **The Reduce Transparency fallback is hand-written.** The app reads
   `@Environment(\.accessibilityReduceTransparency)` and substitutes a solid
   `Color.black.opacity(0.7)`. Materials adapt to that setting on their own to a degree, but the
   weather cards carry white text over an unpredictable image, so the app makes the fallback
   explicit and opaque rather than trusting the default.

Each weather card also pins `.environment(\.colorScheme, .dark)`. The cards are always over a sky,
so their internal contrast is always the dark-on-translucent case regardless of the user's
appearance setting. This is scoped to the three card builders — it is not a global override.

The loading overlay uses `.regularMaterial` instead, because it is a modal-ish blocker over
arbitrary list content and needs to be read, not seen through.

---

## 4. What is *not* glass

The rule that keeps the app coherent: **cards are not glass**.

`SurfaceCard` in [`App/Theme.swift`](../App/Theme.swift):

```swift
struct SurfaceCard: ViewModifier {
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content.background(Color.appSurface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
```

An opaque semantic colour. Used by the Krankmeldung info cards, the article action buttons and the
recommended-article cards. None of these float over anything; all of them are content.

Similarly the home screen's own cards are plain list rows on
`secondarySystemGroupedBackground` — the list draws them, the app does not.

- [ ] Don't wrap `SurfaceCard` in `.glassEffect()`. That would put glass in the content layer.
- [ ] Don't give the news list, the home list or the settings form a custom background.
- [ ] Don't tint a toolbar. See the toolbar rule in §5.

---

## 5. Toolbars, colour and content

The home toolbar holds three monochromatic SF Symbols and no tint. That is not an omission.

> **Reduce the use of toolbar backgrounds and tinted controls.** Any custom backgrounds and
> appearances you use might overlay or interfere with background effects that the system provides.
> Instead, use the content layer to inform the color and appearance of the toolbar.
> — [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)

The one toolbar appearance override in the app is on the weather page:

```swift
.toolbarColorScheme(.dark, for: .navigationBar)
```

The navigation bar there sits over a sky that is bright in daytime and near-black at night. Pinning
the bar to the dark scheme keeps the back chevron and the title white in both cases, which is the
legible choice given the app already forces white hero text with a shadow.

> **Be aware of the placement of color in the content layer.** Make sure your interface maintains
> sufficient contrast by avoiding overlap of similar colors in the content layer and controls when
> possible. Although colorful content might intermittently scroll underneath controls, make sure
> its default or resting state — like the top of a screen of scrollable content — maintains clear
> legibility.
> — [Color](https://developer.apple.com/design/human-interface-guidelines/color)

> **Open item.** The weather page's resting state is the hero numeral directly under the
> navigation bar, over a sky that can be a bright sun glow at uv `(0.78, 0.20)` — close to the
> trailing side of the bar. Worth checking on a clear-day capture whether the title clears the
> glow, or whether the sun position should shift down a few percent.

---

## 6. Regular vs clear glass

The app uses the **regular** variant everywhere. `.glassEffect()` with no argument and
`.buttonStyle(.glass)` both yield regular glass.

> The *regular* variant blurs and adjusts the luminosity of background content to maintain
> legibility of text and other foreground elements. … Use the regular variant when background
> content might create legibility issues, or when components have a significant amount of text.
>
> The *clear* variant is highly translucent, which is ideal for prioritizing the visibility of the
> underlying content … Use this variant for components that float above media backgrounds — such
> as photos and videos.
> — [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)

The PDF stepper is regular because it floats over a dense black-on-white table where a clear
control would vanish. The weather page has no glass control at all — its sky is handled with
`.thinMaterial` cards in the content layer instead, so the clear variant never comes up.

If a clear-glass control is ever added over the sky, the dimming rule applies:

> If the underlying content is bright, consider adding a dark dimming layer of 35% opacity.
> — [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)

Note the home weather card already does something in this spirit at 18 %, as a gradient rather
than a flat layer, for its white text.

---

## 7. Do / don't checklist

- [x] Let standard components pick up Liquid Glass by themselves.
- [x] Reserve `.glassEffect()` for controls that float over scrolling content. Four uses today;
      justify a fifth in writing.
- [x] One `.glassProminent` button per screen, maximum.
- [x] Use `.thinMaterial` for cards over imagery, `.regularMaterial` for blockers over list content.
- [x] Provide an explicit opaque fallback whenever `accessibilityReduceTransparency` could make a
      translucent surface unreadable.
- [ ] Don't apply glass to `SurfaceCard`, list rows or any content container.
- [ ] Don't tint a toolbar background or a tab bar.
- [ ] Don't set a global `.environment(\.colorScheme, ...)`. Scope it to the specific view that
      always sits on a known background, as `WeatherPage` does.

---

## 8. Related

- [02-color.md](02-color.md) — the sky palette these materials sit on
- [06-components.md](06-components.md) — the cards and buttons in detail
- [07-navigation-and-modality.md](07-navigation-and-modality.md) — sheets and the PDF cover
- [10-accessibility.md](10-accessibility.md) — Reduce Transparency and Reduce Motion handling

---

## Sources

| Source | Kind | Accessed |
|---|---|---|
| [`App/WeatherPage.swift`](../App/WeatherPage.swift) | App source | 2026-09-12 |
| [`App/PdfViewerScreen.swift`](../App/PdfViewerScreen.swift) | App source | 2026-09-12 |
| [`App/OnboardingViews.swift`](../App/OnboardingViews.swift) | App source | 2026-09-12 |
| [`App/SettingsSheet.swift`](../App/SettingsSheet.swift) | App source | 2026-09-12 |
| [`App/HomeScreen.swift`](../App/HomeScreen.swift) | App source | 2026-09-12 |
| [`App/WebViews.swift`](../App/WebViews.swift) | App source | 2026-09-12 |
| [`App/Theme.swift`](../App/Theme.swift) | App source | 2026-09-12 |
| [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) | Apple HIG | 2026-09-12 |
| [Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios) | Apple HIG | 2026-09-12 |
| [Color](https://developer.apple.com/design/human-interface-guidelines/color) | Apple HIG | 2026-09-12 |
| [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) | Apple HIG | 2026-09-12 |
| [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) | Apple HIG | 2026-09-12 |
