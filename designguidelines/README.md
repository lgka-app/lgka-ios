# LGKA+ iOS — Design Guidelines

| | |
|---|---|
| **Last updated** | 2026-09-12 |
| **Applies to** | LGKA+ iOS 3.0.0 · iOS 26 · Swift 6.3 · Xcode 26.6 |
| **Owner** | Luka Löhr |
| **Status** | Adopted |

The design rules for **LGKA+**, the app for Lessing-Gymnasium Karlsruhe. Every rule here is
traceable to one of two sources: the app's own Swift source, cited by file path, or a chapter of the
Apple Human Interface Guidelines, cited by URL. Nothing is asserted without one.

---

## The app in one grid

<table>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/01_welcome.png" width="150"><br><sub>Welcome</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/02_home.png" width="150"><br><sub>Home</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/03_weather.png" width="150"><br><sub>Weather</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/04_news.png" width="150"><br><sub>News</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/05_news_detail.png" width="150"><br><sub>Article</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/06_plan.png" width="150"><br><sub>Substitution plan</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/07_settings.png" width="150"><br><sub>Settings</sub></td>
    <td align="center"><img src="../app_store_assets/screenshots/de/ios/phone/dark/08_after_login.png" width="150"><br><sub>Home, first run</sub></td>
  </tr>
</table>

<sub>All eight: German, iPhone, dark. Every screen in all eight locale × form-factor × theme
variants is in [13-screens.md](13-screens.md).</sub>

---

## Contents

| # | File | What it covers |
|---|---|---|
| 01 | [Brand identity](01-brand-identity.md) | Name, the layered iOS 26 app icon, tone of voice, what the app is and is not |
| 02 | [Color](02-color.md) | The five accent options, semantic backgrounds, the Metal sky palette, contrast |
| 03 | [Typography](03-typography.md) | System text styles, the two custom sizes, Dynamic Type, truncation |
| 04 | [Layout and spacing](04-layout-and-spacing.md) | Spacing scale, corner radii, hit targets, safe areas, orientation, iPad |
| 05 | [Materials and Liquid Glass](05-materials-and-liquid-glass.md) | The functional layer vs the content layer, and where each material is used |
| 06 | [Components](06-components.md) | Cards, buttons, pickers, lists, fields, sheets, toolbars, empty states |
| 07 | [Navigation and modality](07-navigation-and-modality.md) | The route map, push vs sheet vs cover, the PDF viewer, web views |
| 08 | [Motion and feedback](08-motion-and-feedback.md) | The sky shader, haptic grammar, loading, refresh |
| 09 | [Iconography](09-iconography.md) | The complete SF Symbols inventory and the rules behind it |
| 10 | [Accessibility](10-accessibility.md) | VoiceOver labels, Dynamic Type, contrast, Reduce Motion — and the open items |
| 11 | [Onboarding, login and privacy](11-onboarding-login-and-privacy.md) | The first-run flow, the login gate, Keychain, the privacy manifest |
| 12 | [Writing and localization](12-writing-and-localization.md) | German/English copy rules, tone, format strings, domain vocabulary |
| 13 | [Screens](13-screens.md) | Every screen, with full screenshot grids and design notes |
| 14 | [HIG reference](14-hig-reference.md) | All 34 HIG chapters, cited and summarised, with LGKA+'s answer to each |

---

## How to use this

**Adding a screen or a component.** Read [06-components.md](06-components.md) first — the row
anatomy in §1 is the shape almost everything in this app takes. Then check
[04-layout-and-spacing.md](04-layout-and-spacing.md) for the spacing value and
[09-iconography.md](09-iconography.md) for the symbol.

**Adding a string.** [12-writing-and-localization.md](12-writing-and-localization.md) §11 is a
seven-step recipe.

**Adding a colour.** Don't, unless it is a sixth accent. [02-color.md](02-color.md) §7 says why and
what to measure first.

**Reviewing a pull request.** The do/don't checklist at the end of each file is the review list.
[10-accessibility.md](10-accessibility.md) §8 is the pre-release checklist.

**Arguing about a rule.** [14-hig-reference.md](14-hig-reference.md) has the chapter, the quotation
and the app's position. Ten deviations from the HIG are recorded there deliberately, each with a
reason. If you disagree with one, that is the file to edit.

---

## The five things that define this app's design

1. **Stock iOS, with two exceptions.** Lists, forms, sheets, toolbars and buttons are system
   components, unmodified. The two bespoke pieces are the animated Metal sky and the 44 pt tinted
   `IconSquare`.
2. **Five accent colours and nothing else custom.** Every other colour is semantic and adapts on its
   own. The only hard-coded hexes outside the accent enum live in the sky shader.
3. **Liquid Glass in the functional layer only.** Four explicit glass uses in roughly 3,200 lines of
   view code. Content cards use standard materials or an opaque surface colour.
4. **No permissions, no tracking, no notifications.** The privacy manifest declares zero collected
   data types. Credentials live in the Keychain, device-only.
5. **German first, informal, and honest about failure.** The source language is German, the user is
   addressed as `du`, and every error names a cause and a remedy.

---

## Repository map

| Path | Contents |
|---|---|
| [`App/`](../App) | The SwiftUI app — every file cited in these guidelines |
| [`App/Localizable.xcstrings`](../App/Localizable.xcstrings) | The String Catalog, 164 keys, German source plus English |
| [`App/AppIcon.icon`](../App/AppIcon.icon) | The layered Icon Composer bundle |
| `app_store_assets/screenshots/` | Generated by `UITests/ScreenshotTests.swift` |
| `designguidelines/assets/swatches/` | 14x14 SVG colour swatches used inline in these files |
| [`project.yml`](../project.yml) | The XcodeGen spec — deployment target, orientations, device family |

---

## Maintaining this guide

- Update **Last updated** in the file's metadata table whenever you change it, and here.
- Every claim needs a citation: a repository file path, or a HIG chapter URL.
- Quote the HIG only verbatim. Paraphrase in your own voice outside blockquotes.
- Record deviations rather than hiding them. Ten are recorded today, each with a reason.
- New colours need a swatch. Generate a 14x14 SVG into `assets/swatches/<HEX>.svg` and reference it
  inline as `![#HEX](assets/swatches/HEX.svg)`.

---

## Sources

| Source | Kind | Accessed |
|---|---|---|
| [`App/`](../App) — all Swift sources, the String Catalog, the icon bundle, the privacy manifest | App source | 2026-09-12 |
| [`project.yml`](../project.yml), [`README.md`](../README.md) | App source | 2026-09-12 |
| `app_store_assets/screenshots/**` | Generated captures | 2026-09-12 |
| 34 Apple Human Interface Guidelines chapters — full list with URLs in [14-hig-reference.md](14-hig-reference.md) | Apple HIG | 2026-09-12 |
