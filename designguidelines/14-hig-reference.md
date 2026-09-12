# HIG Reference

| | |
|---|---|
| **Last updated** | 2026-09-12 |
| **Applies to** | LGKA+ iOS (iOS 26, Swift 6.3, Xcode 26.6) |
| **Owner** | Luka Löhr |
| **Status** | Reference |

---

## How to read this file

Thirty-four Apple Human Interface Guidelines chapters were read in full for this guide. Each entry
below gives the chapter URL, a short faithful summary of what it asks for, and how LGKA+ answers —
including where the app deviates and why.

Verbatim quotations are marked as blockquotes. Everything not in a blockquote is a summary in our
own words.

**Legend**

| Mark | Meaning |
|---|---|
| ✅ | Followed |
| ⚠️ | Deviates deliberately — the reason is stated |
| ➖ | Not applicable to this app |
| 🔍 | Followed in intent, unverified in practice |

---

## A. Foundations

### 1. Designing for iOS
`https://developer.apple.com/design/human-interface-guidelines/designing-for-ios`

Sets the frame: iPhone has a medium, high-resolution display; people hold it in one or two hands
for short bursts; interaction is Multi-Touch. Four best practices — limit onscreen controls, adapt
to appearance changes, respect how people hold the device, and integrate platform capabilities with
permission.

> Help people concentrate on primary tasks and content by limiting the number of onscreen controls
> while making secondary details and actions discoverable with minimal interaction.

**LGKA+** ✅ — The home screen carries three toolbar buttons and four content sections. Secondary
actions live in a context menu and a sheet. The app adapts to orientation (portrait, plus landscape
for PDFs), Dark Mode and Dynamic Type. The fourth practice — integrating platform capabilities — is
deliberately skipped; the app requests no permissions at all. See
[11-onboarding-login-and-privacy.md](11-onboarding-login-and-privacy.md).

---

### 2. Layout
`https://developer.apple.com/design/human-interface-guidelines/layout`

Order content by importance; align and group; use progressive disclosure; differentiate controls
from content with Liquid Glass rather than solid bars; adapt by **size class**, never by device
idiom; respect safe areas and layout guides; prepare for text-size changes.

> **Determine layout based on size classes, not device type or orientation.**

**LGKA+** ⚠️ — Reading order, grouping and safe areas are all handled well (see
[04-layout-and-spacing.md](04-layout-and-spacing.md)). Size classes are the gap: the app contains no
size-class branching, so iPad gets only what `.insetGrouped` and `Form` do on their own. It also
does not branch on device idiom, which is the worse mistake, so the deviation is one of ambition
rather than correctness.

---

### 3. Accessibility
`https://developer.apple.com/design/human-interface-guidelines/accessibility`

An accessible interface is intuitive, perceivable and adaptable. Support larger text; meet WCAG AA
contrast (4.5:1 for text up to 17 pt, 3:1 at 18 pt or bold); never rely on colour alone; offer
44x44 pt controls with generous spacing; avoid complex gestures and offer alternatives; minimise
time-boxed UI; honour Reduce Motion; consider Assistive Access.

> **Convey information with more than color alone.**

**LGKA+** 🔍 — Strong VoiceOver labelling (fifteen dedicated `a11y.` strings that expand
abbreviations into words), universal 44 pt targets, Reduce Motion and Reduce Transparency handled,
and no state signalled by colour alone. Unverified: contrast measurement of the five accents,
Dynamic Type at AX5, Full Keyboard Access, Assistive Access. The full open list is in
[10-accessibility.md](10-accessibility.md) §8.

---

### 4. Branding
`https://developer.apple.com/design/human-interface-guidelines/branding`

Express brand through voice, restrained accent colour and familiar components. Do not scatter your
logo. Do not use the launch screen for branding; use an onboarding screen instead.

> **Ensure branding always defers to content.**

**LGKA+** ✅ — The logo appears once, on the welcome screen, exactly where the chapter suggests. The
accent is confined to tinted squares, links, tags and one prominent button per screen. Every other
component is stock. See [01-brand-identity.md](01-brand-identity.md).

---

### 5. Color
`https://developer.apple.com/design/human-interface-guidelines/color`

Use colour consistently; make it work in light, dark and increased-contrast contexts; prefer
semantic system colours and never hard-code their values; do not rely on colour alone; apply colour
to Liquid Glass sparingly and prefer monochromatic bars over colourful content.

> **Avoid hard-coding system color values in your app.**

**LGKA+** ⚠️ — Five custom accents plus the sky shader; everything else is semantic. Bars are
monochromatic and untinted, and the asset-catalog `AccentColor` now matches `Accent.blue` exactly
(`#3770D4`, reconciled 2026-09-12). The open deviation is the chapter's requirement to supply light
and dark variants for custom colours: the `Accent` enum returns one `Color` per case. Measurement on
2026-09-12 shows four of the five accents fall below AA for normal-size text on a light surface —
`mint` 2.61, `rose` 2.94, `peach` 2.97 and `lavender` 3.38 against `#F2F2F7`, versus `blue` at 4.74.
All five clear 4.4:1 in dark mode. Full palette, measurements and the resulting usage rule in
[02-color.md](02-color.md) §§2.1–2.4.

---

### 6. Dark Mode
`https://developer.apple.com/design/human-interface-guidelines/dark-mode`

Both appearances must look good. Use semantic colours that adapt. Prefer system background colours
so base/elevated depth works automatically. Aim for at least 4.5:1, ideally 7:1 for custom colours.
And: avoid offering an app-specific appearance setting.

> **Avoid offering an app-specific appearance setting.** An app-specific appearance mode option
> creates more work for people because they have to adjust more than one setting to get the
> appearance they want.

**LGKA+** ⚠️ — Semantic backgrounds, both appearances first-class, automatic sheet elevation. But
the app does offer its own dark/auto/light control, in onboarding and in settings. The default is
`"system"`, so a user who never touches it gets the HIG behaviour. Recorded as a conscious
trade-off in [02-color.md](02-color.md) §6.

---

### 7. Materials
`https://developer.apple.com/design/human-interface-guidelines/materials`

Liquid Glass is the functional layer; standard materials are the content layer. Do not put glass in
content. Use glass sparingly on custom controls. Regular glass for legibility, clear glass only over
rich media — with a 35 % dimming layer if the media is bright. Choose material thickness by meaning.

> **Don't use Liquid Glass in the content layer.**

**LGKA+** ✅ — Four explicit glass uses in the whole codebase, each a control over scrolling content.
Content cards use `.thinMaterial` or an opaque semantic colour. The source comment in
`WeatherPage.swift` quotes this chapter directly. See
[05-materials-and-liquid-glass.md](05-materials-and-liquid-glass.md).

---

### 8. Typography
`https://developer.apple.com/design/human-interface-guidelines/typography`

Use system text styles so Dynamic Type works; iOS default 17 pt, minimum 11 pt; avoid light weights;
minimise typefaces; scale interface icons with text; keep truncation minimal; adjust layout at large
sizes.

> **In general, avoid light font weights.**

**LGKA+** ⚠️ — One typeface, system text styles throughout, `@ScaledMetric` on both custom sizes,
`ViewThatFits` for large-type reflow. The deviation is `.thin` on the 96 pt weather hero, accepted
because of its size and its shadow. Full scale in [03-typography.md](03-typography.md).

---

### 9. Writing
`https://developer.apple.com/design/human-interface-guidelines/writing`

Determine a voice, match tone to context, be clear, write for everyone. Be action-oriented with
verbs on buttons. Build language patterns. Apply capitalisation consistently. Use possessive
pronouns sparingly and avoid *we*. Write errors that explain rather than blame. Guide empty states.
Show hints in text fields.

> **Write clear error messages.** … avoid blame, and be clear about what someone can do to fix it.

**LGKA+** ✅ — German informal `du`, verbs on every button, „Weiter"×3 then „Los geht's!", no „wir",
no „oops", errors that name a cause and a remedy. See
[12-writing-and-localization.md](12-writing-and-localization.md).

---

## B. Patterns

### 10. Launching
`https://developer.apple.com/design/human-interface-guidelines/launching`

Launch instantly. Provide a launch screen that looks like your first screen, with no text and no
branding. Restore previous state.

> **Downplay the launch experience.** A launch screen isn't part of an onboarding experience or a
> splash screen, and it isn't an opportunity for artistic expression.

**LGKA+** ✅ — `INFOPLIST_KEY_UILaunchScreen_Generation: YES` produces a plain generated screen with
no logo and no text. State restoration is the two-phase cache bootstrap in `HomeModel`, which shows
cached data before any network call returns.

---

### 11. Onboarding
`https://developer.apple.com/design/human-interface-guidelines/onboarding`

Teach through interactivity; consider contextual tips instead of a flow; keep any flow brief; make
tutorials optional; postpone nonessential setup; do not put licensing in onboarding.

> **Postpone nonessential setup flows or customization steps.**

**LGKA+** ⚠️ — Four screens, nothing to memorise, no licence gate, and two of the four are choices
rather than instruction. Two deviations: the flow is not skippable, and it asks about accent colour
and appearance before first use. Both are argued in
[11-onboarding-login-and-privacy.md](11-onboarding-login-and-privacy.md) §1.2.

---

### 12. Loading
`https://developer.apple.com/design/human-interface-guidelines/loading`

Show something immediately — placeholders rather than a blank screen. Let people act while content
loads. Use determinate indicators when duration is known, indeterminate when it is not.

> **Show something as soon as possible.**

**LGKA+** ✅ — Redacted skeleton rows where the shape is known, indeterminate `ProgressView` where it
is not, and a cache-first bootstrap plus article prefetch that makes most loading invisible. See
[08-motion-and-feedback.md](08-motion-and-feedback.md) §6.

---

### 13. Feedback
`https://developer.apple.com/design/human-interface-guidelines/feedback`

Match the delivery to the significance. Make feedback multi-channel — colour, text, sound, haptics —
so it reaches everyone. Integrate status into the interface. Reserve alerts for critical, actionable
information. Confirm significant completions.

> **Make sure all feedback is accessible.**

**LGKA+** ✅ — Login result arrives as haptic + colour + glyph + text simultaneously. Failures appear
inline in the affected section, not in alerts. A structured haptic grammar (light = acknowledge,
medium = commit) runs throughout.

---

### 14. Motion
`https://developer.apple.com/design/human-interface-guidelines/motion`

Add motion purposefully; make it optional; avoid animating frequent interactions; let people cancel
motion; 30–60 fps; use symbol animations judiciously.

> **Add motion purposefully, supporting the experience without overshadowing it.**

**LGKA+** ✅ — Four custom motions, three of them gated on Reduce Motion; the sky runs at 30 fps;
two animation calls in the entire view layer; no `SymbolEffect` at all.

---

### 15. Modality
`https://developer.apple.com/design/human-interface-guidelines/modality`

Use modality only when there is a clear benefit. Keep modal tasks short. Avoid an app-within-an-app.
Full-screen modality suits in-depth content. Always give an obvious dismissal. Never stack modals.

> **Let people dismiss a modal view before presenting another one.**

**LGKA+** ✅ — Two modals total: the settings sheet and the PDF cover. The settings → bug-report
handoff dismisses before pushing. Both modals have a visible dismiss button as well as a gesture.
See [07-navigation-and-modality.md](07-navigation-and-modality.md).

---

### 16. Searching
`https://developer.apple.com/design/human-interface-guidelines/searching`

Give search a primary position if it matters. Prefer one searchable location. Make the scope clear.
Offer suggestions. Be careful with search history. Index content in Spotlight.

> **Clearly display the current scope of a search.**

**LGKA+** ⚠️ — The one search in the app, inside a PDF, states its scope in its prompt: „Im PDF
suchen". There is no suggestion list, no history, and no Spotlight indexing. For a reader of a
handful of server-supplied documents that is a reasonable scope; indexing news articles in Spotlight
would be the natural extension if search ever becomes a priority.

---

### 17. Entering data
`https://developer.apple.com/design/human-interface-guidelines/entering-data`

Gather from the system rather than asking. Be clear what is needed. Use secure fields for sensitive
data. Never prepopulate a password. Prefer choices over typing. Validate dynamically. Gate the
continue action until required data exists.

> **Never prepopulate a password field.**

**LGKA+** ✅ — Three fields in the whole app. Password is a `SecureField`, never prepopulated,
`.textContentType` set for AutoFill. `canLogin` gates the button. Class entry normalises input
(trim + lowercase) rather than rejecting it. Every other setting is a picker, not a field.

---

### 18. Offering help
`https://developer.apple.com/design/human-interface-guidelines/offering-help`

Match help to the task's complexity. Use consistent language and images. Do not explain standard
components. Consider TipKit tips — short, actionable, rule-gated.

> **Avoid bloating your help content by explaining how standard components or patterns work.**

**LGKA+** ➖ / ⚠️ — No help system and no TipKit. The onboarding feature list is the only
explanatory content, and it names features rather than explaining gestures, which is the right
instinct. The one genuinely undiscoverable interaction — the `.contextMenu` for changing class — is
exactly the case a contextual tip is designed for, and is flagged in
[10-accessibility.md](10-accessibility.md) §4.

---

### 19. Managing notifications
`https://developer.apple.com/design/human-interface-guidelines/managing-notifications`

Permission is required. Four interruption levels — passive, active, Time Sensitive, critical.
Represent urgency honestly. Never use Time Sensitive for marketing. Provide in-app notification
settings if you send any.

> **Build trust by accurately representing the urgency of each notification.**

**LGKA+** ➖ — The app sends no notifications and requests no notification permission. Recorded in
[11-onboarding-login-and-privacy.md](11-onboarding-login-and-privacy.md) §4.2, together with the
note that a future substitution-plan alert would be *Active*, not Time Sensitive.

---

### 20. Privacy
`https://developer.apple.com/design/human-interface-guidelines/privacy`

Request only what you need, and only when the feature needs it. Be transparent. Process on device.
Store secrets in the Keychain, never in plain text. Avoid custom authentication schemes. Write
purpose strings in active voice.

> **Store sensitive information in a keychain.**

**LGKA+** ✅ — Zero permission requests, zero collected data types, no tracking, an honest privacy
manifest declaring both required-reason APIs, Keychain storage with
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, and Password AutoFill instead of a custom scheme.
The strongest chapter-to-implementation match in the app.

---

### 21. Settings
`https://developer.apple.com/design/human-interface-guidelines/settings`

Provide good defaults. Minimise the number of settings. Put general, infrequently changed options in
a settings area and task-specific options in context. Do not duplicate system-wide settings.

> **Minimize the number of settings you offer.**

**LGKA+** ⚠️ — Six items, sensible defaults, and the task-specific class choice lives on the home
card rather than in settings, which is exactly right. The one tension is the appearance control,
which mirrors a system-wide setting; see the Dark Mode entry above.

---

## C. Components

### 22. Alerts
`https://developer.apple.com/design/human-interface-guidelines/alerts`

Use alerts sparingly and never merely to inform. Avoid alerts at launch. Write a title that
describes the situation. Avoid "OK" unless purely informational. Use a specific verb. Always pair a
destructive action with Cancel. In iOS, prefer an action sheet for choices about an intentional
action.

> **Avoid using an alert merely to provide information.**

**LGKA+** ⚠️ — Log-out is a `confirmationDialog` with the verb „Abmelden" and a title that states
the consequence, which is the pattern the chapter asks for. The class-entry alert takes input, which
is sanctioned. The deviation is the timetable-unavailable alert, which only informs; the source
comment marks it as Flutter parity. An inline message on the schedule row would be better and is
recommended in [06-components.md](06-components.md) §8.2.

---

### 23. Buttons
`https://developer.apple.com/design/human-interface-guidelines/buttons`

Hit region at least 44x44 pt. Always include a press state. Prominent style for the most likely
action, one or two per view. Distinguish by style, not size. Familiar icons for familiar actions.
Roles — primary, cancel, destructive — carry meaning. Show an activity indicator in the button for
slow actions.

> **In general, use a button that has a prominent visual style for the most likely action in a view.**

**LGKA+** ✅ — One `.glassProminent` per screen, `.bordered` for recovery, `.plain` for cards, and
the login button shows its `ProgressView` in place. All targets meet 44 pt.

---

### 24. Lists and tables
`https://developer.apple.com/design/human-interface-guidelines/lists-and-tables`

Prefer text in rows. Give feedback on selection. Keep row text succinct. Choose a style that suits
the data. Use a disclosure indicator, not an info button, for drilling in.

> **Prefer displaying text in a list or table.**

**LGKA+** ✅ — `.insetGrouped` throughout, every row a title plus subtitle, `chevron.right` for
drill-in, long sections capped (`prefix(4)`, `prefix(3)`).

---

### 25. Pull-down buttons
`https://developer.apple.com/design/human-interface-guidelines/pull-down-buttons`

Use a pull-down for commands related to a button's action. Do not hide a view's primary actions in
one. Three or more items makes the interaction worthwhile. A More button trades space for
discoverability.

> **Avoid putting all of a view's actions in one pull-down button.**

**LGKA+** ➖ — No pull-down buttons and no More menu. The three home toolbar items sit in the bar
directly, which the chapter prefers. The `.contextMenu` on the timetable card is the nearest
relative; it holds a single item, below the three-item threshold the chapter suggests, which is part
of why a visible affordance would serve better.

---

### 26. Segmented controls
`https://developer.apple.com/design/human-interface-guidelines/segmented-controls`

Closely related choices affecting one object or view. No more than five segments on iPhone. Keep
segment size consistent. Prefer text or images, not a mix. Use nouns in title case.

> **Prefer using either text or images — not a mix of both — in a single segmented control.**

**LGKA+** ✅ — One segmented control, three segments, nouns in title case, ordered dark · auto ·
light so the neutral option sits between the extremes. Each segment supplies both a symbol and text
via `Label` and lets the system choose, which is the safe way to honour the mix rule across widths.

---

### 27. Sheets
`https://developer.apple.com/design/human-interface-guidelines/sheets`

Cancel leads, Done trails. Only one sheet at a time. Support the medium detent for progressive
disclosure. Include a grabber on a resizable sheet. Support swipe to dismiss. Always pair Done with
Cancel or Back.

> **Display only one sheet at a time from the main interface.**

**LGKA+** ✅ — One sheet, `[.medium, .large]` detents, a system grabber, swipe to dismiss and a
trailing `xmark`. The bug-report handoff dismisses before pushing. There is no Done button because
settings apply instantly, so the Done/Cancel pairing rule does not bind.

---

### 28. Tab bars
`https://developer.apple.com/design/human-interface-guidelines/tab-bars`

Tabs are for navigation between sections, not for actions. Keep them visible. Avoid overflow. Never
disable a tab. Prefer filled symbols. Use badges only for critical information.

> **Use a tab bar to support navigation, not to provide actions.**

**LGKA+** ➖ — No tab bar, by design. The app has one hub and a set of destinations, not a set of
peer sections. The rationale is written out in
[07-navigation-and-modality.md](07-navigation-and-modality.md) §1.

---

### 29. Text fields
`https://developer.apple.com/design/human-interface-guidelines/text-fields`

Small amounts of information only. Show a hint. Secure fields for private data. Size the field to
the expected content. Logical tab order. Validate when it makes sense. Show the right keyboard type.
Offer a Clear button on iOS.

> **Show a hint in a text field to help communicate its purpose.**

**LGKA+** 🔍 — Hints on all three fields, a `SecureField` for the password, a `next` → `go` submit
chain, and input normalisation on the class field. The app does not configure a custom keyboard type
or an explicit Clear button; both are minor and worth a look, particularly a numeric-friendly
keyboard for class codes.

---

### 30. Toolbars
`https://developer.apple.com/design/human-interface-guidelines/toolbars`

Avoid overcrowding. Reduce toolbar backgrounds and tinted controls. Prefer standard symbols without
borders. Use standard Back and Close. Group logically; at most three groups. Keep text-labelled
actions separate. Titles under 15 characters; never title a window with the app name.

> **Reduce the use of toolbar backgrounds and tinted controls.**

**LGKA+** ⚠️ — One group of three untinted system symbols on home, standard `xmark` for close, no
custom backgrounds. Two deviations. The home title *is* the app name, „LGKA+", against the chapter's
advice — but this is a single-screen hub with no document hierarchy to name instead. And the German
titles „Hinweis zur Krankmeldung" and „Alle Funktionen im Überblick" exceed 15 characters, which
German makes unavoidable.

---

### 31. Web views
`https://developer.apple.com/design/human-interface-guidelines/web-views`

Support forward and back navigation when appropriate. Do not build a browser.

> **Avoid using a web view to build a web browser.**

**LGKA+** ✅ — Two single-purpose web views, no navigation chrome, host-confined with external links
handed to Safari, and `.nonPersistent()` data stores.

---

## D. Icons and imagery

### 32. App icons
`https://developer.apple.com/design/human-interface-guidelines/app-icons`

Use layers for depth; iOS icons take Liquid Glass attributes. Provide unmasked square layers with
clearly defined edges. Embrace simplicity. Avoid text. Prefer illustration to photography. Let the
system apply visual effects. Support default, dark, clear and tinted appearances.

> **Let the system handle blurring and other visual effects.**

**LGKA+** ✅ — Three Icon Composer groups (arch, pillars, lions), each with `glass: true`, all
system effects disabled in the artwork (`specular: false`, `shadow.kind: "none"`), a solid black
background declared for both appearances, no text, original illustration. See
[01-brand-identity.md](01-brand-identity.md) §3.

---

### 33. Icons
`https://developer.apple.com/design/human-interface-guidelines/icons`

Recognisable, highly simplified designs. Consistent size, detail, weight and perspective. Match icon
weight to adjacent text. Optically centre asymmetric glyphs. Use vector formats for custom icons.
Provide alternative text labels. Publishes a table of standard action symbols.

> **In general, match the weights of interface icons and adjacent text.**

**LGKA+** ✅ — No custom interface icons at all, so consistency is structural. `IconSquare` uses
`.body.weight(.medium)` to match its title. Apple's standard symbols are used for cancel, done,
search, share, rename and calendar. Decorative glyphs are hidden from VoiceOver; meaningful ones are
`Label`s. See [09-iconography.md](09-iconography.md).

---

### 34. SF Symbols
`https://developer.apple.com/design/human-interface-guidelines/sf-symbols`

Four rendering modes. Variable colour communicates change, not depth. Nine weights, three scales.
Design variants — outline, fill, slash, enclosed — communicate state. Animations exist but should be
applied judiciously. Symbols may not appear in app icons.

> **Apply symbol animations judiciously.**

**LGKA+** ✅ — Every glyph is an SF Symbol. Outline in toolbars and rows, fill for weather and
status, `.multicolor` for weather conditions only, `.monochrome` forced on the palette swatches. The
`.badge.exclamationmark` suffix distinguishes failure from empty across three symbol families. No
symbol animations, no variable colour, and no symbol in the app icon.

---

## Summary

| Verdict | Count | Chapters |
|---|---|---|
| ✅ Followed | 19 | Designing for iOS, Branding, Materials, Writing, Launching, Loading, Feedback, Motion, Modality, Entering data, Privacy, Buttons, Lists and tables, Segmented controls, Sheets, Web views, App icons, Icons, SF Symbols |
| ⚠️ Deliberate deviation | 10 | Layout, Color, Dark Mode, Typography, Onboarding, Searching, Offering help, Settings, Alerts, Toolbars |
| 🔍 Followed in intent, unverified | 2 | Accessibility, Text fields |
| ➖ Not applicable | 3 | Managing notifications, Pull-down buttons, Tab bars |

Every ⚠️ has a written reason in this file and in the topic chapter it belongs to. Ten are
recorded today; the Color entry moved from ✅ to ⚠️ on 2026-09-12 when contrast measurement showed
the accents lack the light/dark variants the chapter asks for. Every 🔍 has an
open item in [10-accessibility.md](10-accessibility.md) §8. Nothing here is an unexamined gap.

---

## Sources

All thirty-four chapters were read on 2026-09-12.

| Chapter | URL |
|---|---|
| Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility |
| Alerts | https://developer.apple.com/design/human-interface-guidelines/alerts |
| App icons | https://developer.apple.com/design/human-interface-guidelines/app-icons |
| Branding | https://developer.apple.com/design/human-interface-guidelines/branding |
| Buttons | https://developer.apple.com/design/human-interface-guidelines/buttons |
| Color | https://developer.apple.com/design/human-interface-guidelines/color |
| Dark Mode | https://developer.apple.com/design/human-interface-guidelines/dark-mode |
| Designing for iOS | https://developer.apple.com/design/human-interface-guidelines/designing-for-ios |
| Entering data | https://developer.apple.com/design/human-interface-guidelines/entering-data |
| Feedback | https://developer.apple.com/design/human-interface-guidelines/feedback |
| Icons | https://developer.apple.com/design/human-interface-guidelines/icons |
| Launching | https://developer.apple.com/design/human-interface-guidelines/launching |
| Layout | https://developer.apple.com/design/human-interface-guidelines/layout |
| Lists and tables | https://developer.apple.com/design/human-interface-guidelines/lists-and-tables |
| Loading | https://developer.apple.com/design/human-interface-guidelines/loading |
| Managing notifications | https://developer.apple.com/design/human-interface-guidelines/managing-notifications |
| Materials | https://developer.apple.com/design/human-interface-guidelines/materials |
| Modality | https://developer.apple.com/design/human-interface-guidelines/modality |
| Motion | https://developer.apple.com/design/human-interface-guidelines/motion |
| Offering help | https://developer.apple.com/design/human-interface-guidelines/offering-help |
| Onboarding | https://developer.apple.com/design/human-interface-guidelines/onboarding |
| Privacy | https://developer.apple.com/design/human-interface-guidelines/privacy |
| Pull-down buttons | https://developer.apple.com/design/human-interface-guidelines/pull-down-buttons |
| Searching | https://developer.apple.com/design/human-interface-guidelines/searching |
| Segmented controls | https://developer.apple.com/design/human-interface-guidelines/segmented-controls |
| Settings | https://developer.apple.com/design/human-interface-guidelines/settings |
| SF Symbols | https://developer.apple.com/design/human-interface-guidelines/sf-symbols |
| Sheets | https://developer.apple.com/design/human-interface-guidelines/sheets |
| Tab bars | https://developer.apple.com/design/human-interface-guidelines/tab-bars |
| Text fields | https://developer.apple.com/design/human-interface-guidelines/text-fields |
| Toolbars | https://developer.apple.com/design/human-interface-guidelines/toolbars |
| Typography | https://developer.apple.com/design/human-interface-guidelines/typography |
| Web views | https://developer.apple.com/design/human-interface-guidelines/web-views |
| Writing | https://developer.apple.com/design/human-interface-guidelines/writing |

> **Note**
> The chapter markdown used for this pass was captured locally and does not carry an embedded source
> URL. The URLs above follow the canonical HIG path scheme, one slug per chapter, matching the
> filenames of the captured set. They were not re-fetched during authoring.
