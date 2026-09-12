# LGKA+ iOS — Design Guidelines

Retrieved and compiled on 2026-09-12. Part 1 is the LGKA+ brand and how it maps onto iOS 26. Part 2 is a verbatim reference copy of the relevant chapters of Apple's Human Interface Guidelines as published on developer.apple.com on 2026-09-12 (© Apple Inc.; reproduced here for engineering reference only — the live HIG at https://developer.apple.com/design/human-interface-guidelines is authoritative).

---

## Part 1 — LGKA+ brand on iOS

### 1.1 Identity
- App name: **LGKA+** (display name), bundle id `com.lgka` (shared with the shipping Flutter app for App Store continuity).
- Voice: short, friendly, second person singular in German ("Tippe, um deine Klasse festzulegen"). English is a full second localization. German is the source language of `App/Localizable.xcstrings`; keys are stable identifiers, never the German text.
- Iconography: SF Symbols only (`calendar`, `tablecells`, `newspaper`, `cross.case`, `gearshape`, weather symbols in `.multicolor`). No custom glyphs except the app icon and the onboarding logo.

### 1.2 Accent palette (mirrors `ColorProvider` in the Flutter app)
| Key | Hex | Name (de/en) | On-white contrast | Use |
|---|---|---|---|---|
| blue | #3770D4 | Blau / Blue | 4.6:1 | default |
| mint | #45A88A | Mint / Mint | 2.9:1 | tint only, never body text on white |
| lavender | #9B6BDF | Lavendel / Lavender | 3.5:1 | tint only |
| rose | #C47A7A | Rosé / Rose | 3.3:1 | tint only |
| peach | #BF7F46 | Pfirsich / Peach | 3.1:1 | tint only |

The accent is applied through `.tint(prefs.accent)` and the `appAccent` environment value. It colors interactive elements, icon squares (12% alpha fill) and the date tile. It is **never** used as the only carrier of meaning and never for running text: body text stays `.primary` / `.secondary`. Prominent buttons use `.glassProminent`, which renders white text on the accent — that pairing is only WCAG AA for `blue`; for the other four accents the buttons are large (≥ 17 pt semibold), so they meet the 3:1 large-text threshold. Do not introduce small white-on-accent text.

### 1.3 Surfaces and materials
- Backgrounds: `Color.appBackground` = `systemGroupedBackground` (pure black in Dark Mode, #F2F2F7 in Light Mode — identical to the brand's Flutter theme, but system-managed so Liquid Glass bars, sheets and scroll-edge effects blend correctly). Cards: `Color.appSurface` = `secondarySystemGroupedBackground`.
- Liquid Glass is used **only** in the functional layer: navigation bars, toolbars, the search field, the PDF match stepper, `.glassProminent` primary buttons and the `.glass` stepper buttons. Content (lists, cards, the weather forecast cards) uses standard materials (`.thinMaterial`) or opaque surfaces. This follows "Don't use Liquid Glass in the content layer" (HIG → Materials).
- The weather page draws the animated sky behind content; its cards use `.thinMaterial` with white text and `.environment(\.colorScheme, .dark)` for legibility. When Reduce Transparency is on, cards fall back to an opaque 70% black.
- Corner radii: 10 pt (list-row weather card), 12 pt (icon squares, link buttons), 16 pt (surface cards), 18 pt (weather cards); all `.continuous`.

### 1.4 Typography and layout
- Text styles only (`.largeTitle`, `.title2`, `.callout`, `.subheadline`, `.caption`…); the two hero numbers (home weather 40 pt, weather page 96 pt) use `@ScaledMetric` so Dynamic Type scales them. No fixed point sizes elsewhere.
- Minimum tap target 44 × 44 pt: every card is a `Button` whose label carries `.contentShape(Rectangle())`, so the entire card (not only the glyphs) is the hit target. Icon-only toolbar items use `Label`, which SwiftUI renders as icon and exposes as text to VoiceOver.
- Layout follows the system: `List` with `.insetGrouped`, `Form` for settings, `NavigationStack` with value-based destinations, `.safeAreaInset` for bottom primary actions in onboarding.

### 1.5 Accessibility contract
- Every interactive element has a VoiceOver label (`a11y.*` keys). Decorative images and the sky are `.accessibilityHidden(true)`. Cards combine their children into one element with a descriptive label.
- Reduce Motion pauses the Metal sky and disables particles and fireworks. Reduce Transparency swaps materials for opaque surfaces.
- Loading states are `.redacted(reason: .placeholder)` skeletons labelled "Lädt…", not spinners in the middle of the list.
- Dynamic Type: meta rows use `ViewThatFits` to wrap at larger sizes; nothing clips.

### 1.6 Motion and feedback
- Haptics mirror the Flutter `HapticService`: light on toolbar taps, medium on opening a plan, success/error on login.
- Pull-to-refresh on every list. Errors are inline (`ContentUnavailableView` or a row with a retry button), never modal, and always keep the last good data on screen.

### 1.7 Privacy
- No tracking, no analytics, no third-party SDKs besides SwiftSoup (HTML parsing) and Vortex (particles). `App/PrivacyInfo.xcprivacy` declares the two required-reason APIs in use (UserDefaults CA92.1, file timestamps C617.1).
- The school website credentials are entered by the user, verified against the server and stored in the Keychain (`Credentials.swift`); they never appear in source and are sent only to `lessing-gymnasium-karlsruhe.de`.

---

## Part 2 — Apple Human Interface Guidelines (reference copy, retrieved 2026-09-12)

Source: https://developer.apple.com/design/human-interface-guidelines/ — each chapter below is the guidance text of the corresponding page as served by Apple's documentation API on 2026-09-12. Figures, videos and platform sections that do not apply to iOS were omitted.

---

## HIG: Designing for iOS

Source: https://developer.apple.com/design/human-interface-guidelines/designing-for-ios

As you begin designing your app or game for iOS, start by understanding the following fundamental device characteristics and patterns that distinguish the iOS experience. Using these characteristics and patterns to inform your design decisions can help you provide an app or game that iPhone users appreciate.

**Display.** iPhone has a medium-size, high-resolution display.

**Ergonomics.** People generally hold their iPhone in one or both hands as they interact with it, switching between landscape and portrait orientations as needed. While people are interacting with the device, their viewing distance tends to be no more than a foot or two.

**Inputs.** Multi-Touch gestures, virtual keyboards, and voice control let people perform actions and accomplish meaningful tasks while they’re on the go. In addition, people often want apps to use their personal data and input from the device’s gyroscope and accelerometer, and they may also want to participate in spatial interactions.

**App interactions.** Sometimes, people spend just a minute or two checking on event or social media updates, tracking data, or sending messages. At other times, people can spend an hour or more browsing the web, playing games, or enjoying media. People typically have multiple apps open at the same time, and they appreciate switching frequently among them.

**System features.** iOS provides several features that help people interact with the system and their apps in familiar, consistent ways.

- Widgets

- Home Screen quick actions

- Spotlight

- Shortcuts

- Activity views

#### Best practices

Great iPhone experiences integrate the platform and device capabilities that people value most. To help your design feel at home in iOS, prioritize the following ways to incorporate these features and capabilities.

- Help people concentrate on primary tasks and content by limiting the number of onscreen controls while making secondary details and actions discoverable with minimal interaction.

- Adapt seamlessly to appearance changes — like device orientation, Dark Mode, and Dynamic Type — letting people choose the configurations that work best for them.

- Support interactions that accommodate the way people usually hold their device. For example, it tends to be easier and more comfortable for people to reach a control when it’s located in the middle or bottom area of the display, so it’s especially important let people swipe to navigate back or initiate actions in a list row.

- With people’s permission, integrate information available through platform capabilities in ways that enhance the experience without asking people to enter data. For example, you might accept payments, provide security through biometric authentication, or offer features that use the device’s location.

#### Resources

##### Related

Apple Design Resources

##### Developer documentation

iOS Pathway

##### Videos

---

## HIG: Materials

Source: https://developer.apple.com/design/human-interface-guidelines/materials

Materials help visually separate foreground elements, such as text and controls, from background elements, such as content and solid colors. By allowing color to pass through from background to foreground, a material establishes visual hierarchy to help people more easily retain a sense of place.

Apple platforms feature two types of materials: Liquid Glass, and standard materials. Liquid Glass is a dynamic material that unifies the design language across Apple platforms, allowing you to present controls and navigation without obscuring underlying content. In contrast to Liquid Glass, the Standard materials help with visual differentiation within the content layer.

#### Liquid Glass

Liquid Glass forms a distinct functional layer for controls and navigation elements — like tab bars and sidebars — that floats above the content layer, establishing a clear visual hierarchy between functional elements and content. Liquid Glass allows content to scroll and peek through from beneath these elements to give the interface a sense of dynamism and depth, all while maintaining legibility for controls and navigation.

**Don’t use Liquid Glass in the content layer.** Liquid Glass works best when it provides a clear distinction between interactive elements and content, and including it in the content layer can result in unnecessary complexity and a confusing visual hierarchy. Instead, use Standard materials for elements in the content layer, such as app backgrounds. An exception to this is for controls in the content layer with a transient interactive element like Sliders and Toggles; in these cases, the element takes on a Liquid Glass appearance to emphasize its interactivity when a person activates it.

**Use Liquid Glass effects sparingly.** Standard components from system frameworks pick up the appearance and behavior of this material automatically. If you apply Liquid Glass effects to a custom control, do so sparingly. Liquid Glass seeks to bring attention to the underlying content, and overusing this material in multiple custom controls can provide a subpar user experience by distracting from that content. Limit these effects to the most important functional elements in your app. For developer guidance, see Applying Liquid Glass to custom views.

**Only use clear Liquid Glass for components that appear over visually rich backgrounds.** Liquid Glass provides two variants — regular and clear — that you can choose when building custom components or styling some system components. The appearance of these variants can differ in response to certain system settings, like if people choose a preferred look for Liquid Glass in their device’s settings, or turn on accessibility settings that reduce transparency or increase contrast in the interface.

The *regular* variant blurs and adjusts the luminosity of background content to maintain legibility of text and other foreground elements. Scroll edge effects further enhance legibility by blurring and reducing the opacity of background content. Most system components use this variant. Use the regular variant when background content might create legibility issues, or when components have a significant amount of text, such as alerts, sidebars, or popovers.

The *clear* variant is highly translucent, which is ideal for prioritizing the visibility of the underlying content and ensuring visually rich background elements remain prominent. Use this variant for components that float above media backgrounds — such as photos and videos — to create a more immersive content experience.

For optimal contrast and legibility, determine whether to add a dimming layer behind components with clear Liquid Glass:

- If the underlying content is bright, consider adding a dark dimming layer of 35% opacity. For developer guidance, see clear.

- If the underlying content is sufficiently dark, or if you use standard media playback controls from AVKit that provide their own dimming layer, you don’t need to apply a dimming layer.

For guidance about the use of color, see Liquid Glass color.

#### Standard materials

Use standard materials and effects — such as UIBlurEffect, UIVibrancyEffect, and NSVisualEffectView.BlendingMode — to convey a sense of structure in the content beneath Liquid Glass.

**Choose materials and effects based on semantic meaning and recommended usage.** Avoid selecting a material or effect based on the apparent color it imparts to your interface, because system settings can change its appearance and behavior. Instead, match the material or vibrancy style to your specific use case.

**Help ensure legibility by using vibrant colors on top of materials.** When you use system-defined vibrant colors, you don’t need to worry about colors seeming too dark, bright, saturated, or low contrast in different contexts. Regardless of the material you choose, use vibrant colors on top of it. For guidance, see System colors.

**Consider contrast and visual separation when choosing a material to combine with blur and vibrancy effects.** For example, consider that:

- Thicker materials, which are more opaque, can provide better contrast for text and other elements with fine features.

- Thinner materials, which are more translucent, can help people retain their context by providing a visible reminder of the content that’s in the background.

For developer guidance, see Material.

#### Platform considerations

#### iOS, iPadOS

In addition to Liquid Glass, iOS and iPadOS continue to provide four standard materials — ultra-thin, thin, regular (default), and thick — which you can use in the content layer to help create visual distinction.

iOS and iPadOS also define vibrant colors for labels, fills, and separators that are specifically designed to work with each material. Labels and fills both have several levels of vibrancy; separators have one level. The name of a level indicates the relative amount of contrast between an element and the background: The default level has the highest contrast, whereas quaternary (when it exists) has the lowest contrast.

Except for quaternary, you can use the following vibrancy values for labels on any material. In general, avoid using quaternary on top of the thin and ultraThin materials, because the contrast is too low.

- UIVibrancyEffectStyle.label (default)

- UIVibrancyEffectStyle.secondaryLabel

- UIVibrancyEffectStyle.tertiaryLabel

- UIVibrancyEffectStyle.quaternaryLabel

You can use the following vibrancy values for fills on all materials.

- UIVibrancyEffectStyle.fill (default)

- UIVibrancyEffectStyle.secondaryFill

- UIVibrancyEffectStyle.tertiaryFill

The system provides a single, default vibrancy value for a UIVibrancyEffectStyle.separator, which works well on all materials.

#### macOS

macOS provides several standard materials with designated purposes, and vibrant versions of all Specifications. For developer guidance, see NSVisualEffectView.Material.

**Choose when to allow vibrancy in custom views and controls.** Depending on configuration and system settings, system views and controls use vibrancy to make foreground content stand out against any background. Test your interface in a variety of contexts to discover when vibrancy enhances the appearance and improves communication.

**Choose a background blending mode that complements your interface design.** macOS defines two modes that blend background content: behind window and within window. For developer guidance, see NSVisualEffectView.BlendingMode.

#### tvOS

In tvOS, Liquid Glass appears throughout navigation elements and system experiences such as Top Shelf and Control Center. Certain interface elements, like image views and buttons, adopt Liquid Glass when they gain focus.

In addition to Liquid Glass, tvOS continues to provide standard materials, which you can use to help define structure in the content layer. The thickness of a standard material affects how prominently the underlying content shows through. For example, consider using standard materials in the following ways:

| 
Material
 | 
Recommended for
 | 
| 
ultraThin
 | 
Full-screen views that require a light color scheme
 | 
| 
thin
 | 
Overlay views that partially obscure onscreen content and require a light color scheme
 | 
| 
regular
 | 
Overlay views that partially obscure onscreen content
 | 
| 
thick
 | 
Overlay views that partially obscure onscreen content and require a dark color scheme
 | 

#### visionOS

In visionOS, windows generally use an unmodifiable system-defined material called *glass* that helps people stay grounded by letting light, the current Environment, virtual content, and objects in people’s surroundings show through. Glass is an adaptive material that limits the range of background color information so a window can continue to provide contrast for app content while becoming brighter or darker depending on people’s physical surroundings and other virtual content.

> 
visionOS doesn’t have a distinct Dark Mode setting. Instead, glass automatically adapts to the luminance of the objects and colors behind it.

**Prefer translucency to opaque colors in windows.** Areas of opacity can block people’s view, making them feel constricted and reducing their awareness of the virtual and physical objects around them.

**If necessary, choose materials that help you create visual separations or indicate interactivity in your app.** If you need to create a custom component, you may need to specify a system material for it. Use the following examples for guidance.

- The thin material brings attention to interactive elements like buttons and selected items.

- The regular material can help you visually separate sections of your app, like a sidebar or a grouped table view.

- The thick material lets you create a dark element that remains visually distinct when it’s on top of an area that uses a `regular` background.

To ensure foreground content remains legible when it displays on top of a material, visionOS applies vibrancy to text, symbols, and fills. Vibrancy enhances the sense of depth by pulling light and color forward from both virtual and physical surroundings.

visionOS defines three vibrancy values that help you communicate a hierarchy of text, symbols, and fills.

- Use UIVibrancyEffectStyle.label for standard text.

- Use UIVibrancyEffectStyle.secondaryLabel for descriptive text like footnotes and subtitles.

- Use UIVibrancyEffectStyle.tertiaryLabel for inactive elements, and only when text doesn’t need high legibility.

#### watchOS

**Use materials to provide context in a full-screen modal view.** Because full-screen modal views are common in watchOS, the contrast provided by material layers can help orient people in your app and distinguish controls and system elements from other content. Avoid removing or replacing material backgrounds for modal sheets when they’re provided by default.

#### Resources

##### Related

Color

Accessibility

Dark Mode

##### Developer documentation

Adopting Liquid Glass

glassEffect(_:in:) — SwiftUI

Material — SwiftUI

UIVisualEffectView — UIKit

NSVisualEffectView — AppKit

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
September 9, 2025
 | 
Updated guidance for Liquid Glass.
 | 
| 
June 9, 2025
 | 
Added guidance for Liquid Glass.
 | 
| 
August 6, 2024
 | 
Added platform-specific art.
 | 
| 
December 5, 2023
 | 
Updated descriptions of the various material types, and clarified terms related to vibrancy and material thickness.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 
| 
June 5, 2023
 | 
Added guidance on using materials to provide context and orientation in watchOS apps.
 | 

---

## HIG: Layout

Source: https://developer.apple.com/design/human-interface-guidelines/layout

Your layout provides the structure for people to understand your content from the moment they open your app. Familiar relationships between controls and content let people use and discover features right away, and make your design feel at home on every platform.

Apple provides templates and layout guides that can help you integrate Apple technologies and design your apps and games to run on all Apple platforms. See Apple Design Resources.

#### Visual hierarchy

**Order content by relative importance.** People often start by viewing content in reading order — that is, from top to bottom and from the leading to trailing side — so place the most important items near the top and leading side of the window or display. To support right-to-left languages, prefer standard system components that can automatically adapt UI elements to better reflect each language’s natural reading order. For guidance, see Right to left.

**Align elements to make them easier to scan, and use indentation to convey hierarchy.** Alignment makes an app look neat and organized, and can help people track content while scrolling or moving their eyes. People assume that aligned items are related to each other, and conversely, they perceive indented items as subordinate to the item they follow. Because of this, using alignment and indentation deliberately can help people understand your information hierarchy.

**Group related items to clearly express related information or functions.** For example, you might use negative space, container shapes, or separator lines to show which elements are related and which are unrelated.

**Use progressive disclosure to make layouts cleaner and easier to interact with.** An interface with too much content and too many choices makes it harder to find information quickly, and harder to understand the choices that are available. Use disclosure triangles, menus, or nested views to reduce how much content to initially display; or use scrollable sections to showcase additional content, which is particularly useful for media-focused apps like those for video, music, or books.

**Differentiate controls from content.** Take advantage of the Liquid Glass material on all platforms that support it to provide a distinct appearance for your controls. Instead of applying a solid or semi-opaque background color beneath controls, use a scroll edge effect to visually elevate controls above content. For guidance, see Scroll views. For full-screen background content, be sure to extend it underneath sidebars, toolbars, and tab bars to fit the entire screen or window.

If scaling a background image to the full window edge results in components like sidebars or inspectors covering important parts of the image, you can use a background extension effect to flip and blur the image, mirroring it beneath adjacent components and providing the appearance that the background image extends beneath them. For developer guidance, see backgroundExtensionEffect() and UIBackgroundExtensionView.

#### Adaptability

Apps and games need to adapt to different display sizes, orientation changes, window sizes, and multitasking states. In iOS, iPadOS, tvOS, and visionOS, the system defines characteristics of the device environment that can affect the way your app or game looks. Use SwiftUI or Auto Layout to ensure that your interface adapts to them.

Here are some of the most common device and system characteristics that apps need to handle:

- Regular and compact horizontal and vertical Size classes

- Different device screen sizes

- Different device orientations and aspect ratios

- System features like the Dynamic Island

- External display support, Display Zoom, and resizable windows on iPad and Mac

- Text-size changes

- Locale-based internationalization features like left-to-right/right-to-left layout direction, date/time/number formatting, font variation, and text length

**Design a layout that adapts gracefully and consistently.** People expect your experience to remain familiar when they rotate their device, resize a window, add another display, or switch to a different device. You can help ensure an adaptable interface by respecting system-defined safe areas, margins, and guides (where available) and specifying layout modifiers to fine-tune the placement of views in your interface.

Even if your app is locked to a certain orientation, such as a landscape-only game, it’s still important to ensure your interface resizes well to provide the best experience across devices and window sizes.

**Be prepared for text-size changes.** People use Supporting Dynamic Type to increase text size to be more readable, which occurs at the system level. Apps that don’t respond to this setting can be difficult or impossible to use for people who rely on this feature. Support Dynamic Type by adjusting your layout to accommodate text at larger sizes. For example, horizontally adjacent views may need to stack vertically to provide more space for text; table rows or other containers may need to grow in height so that text isn’t cropped or doesn’t overlap other content; and table rows with a single line of text by default might need to grow vertically to accommodate multiple lines of text.

To support Dynamic Type in your Unity-based game, use Apple’s accessibility plug-in (for developer guidance, see Apple – Accessibility). For guidance on displaying text in your app, see Typography.

**Preview your app on multiple devices, using different size classes, localizations, and text sizes.** You can streamline the testing process by first testing versions of your experience that use the largest and the smallest layouts. You can test on a simulated device in Device Hub to check for clipping and other layout issues. For example, you can use Device Hub to make sure your layout looks great when your app is resized on iPad or in iPhone Mirroring on Mac.

**When necessary, scale background artwork in response to display changes.** Viewing your app or game in a different context — such as on a screen with a different aspect ratio — might make your artwork appear cropped, letterboxed, or pillarboxed. If this happens, don’t change the aspect ratio of the artwork; instead, scale it so that it fills the screen completely. Note that since windows can be very wide and short or tall and narrow, background artwork may often need to extend beyond what is typically visible in a more standard display aspect ratio.

#### Size classes

In iOS and iPadOS, size classes are an indication of how much horizontal and vertical space is available to an app’s interface.

Each dimension — horizontal and vertical — is represented by one of two size classes: *compact* or *regular*. The horizontal size class determines whether an app is narrow (compact) or wide (regular), while the vertical size class determines whether it is short (compact) or tall (regular).

The system sets size classes based on the device type, Windows configuration, and Multitasking state; for example, whether an app is full screen, in Slide Over, or mirrored from an iPhone to a Mac. Depending on their environment, iOS and iPadOS apps can exist in every combination of size classes.

For developer guidance, see UITraitChangeObservable and UserInterfaceSizeClass.

**Determine layout based on size classes, not device type or orientation.** Size classes describe the actual space available, regardless of whether an app is in portrait or landscape. Conversely, a device’s orientation and type (also called its *idiom*) aren’t useful for making layout decisions because they don’t provide your app with information about how much space is available.

Size classes also let your app’s interface adapt to a wide range of window sizes. For example, when a person runs your app in macOS with iPhone Mirroring, they can freely resize its width and height; or they can resize an iPad app when multitasking in iPadOS or when running it in macOS.

**Consider all possible combinations of size classes.** Your app can appear in a variety of size classes in both portrait and landscape aspect ratios, and it’s important to consider all of them to provide a good experience. A layout solely designed for landscape on iPhone with regular width and compact height might not take advantage of the vertical space available on iPad in landscape when someone resizes the window to regular height. Conversely, designing exclusively for compact portrait could leave extra space when someone resizes the app window to a regular width on iPad.

**Keep functionality the same as size classes change, and keep layout changes recognizable and familiar to the platform.** Don’t change your app’s functionality based on the space it occupies. However, you can change the amount of functionality that’s visible onscreen as the amount of space changes. Consider taking advantage of larger spaces to switch from a Tab bars to a Sidebars or expose functionality that might otherwise be grouped into an overflow menu.

Similarly, while an app’s size classes might change when someone resizes it, its idiom — the device type it’s made for — remains the same: keep the layout recognizable and familiar to the platform even when resizing.

#### Guides and safe areas

A *layout guide* defines a rectangular region that helps you position, align, and space your content on the screen. The system includes predefined layout guides that make it easy to apply standard margins around content and restrict the width of text for optimal readability. You can also define custom layout guides. For developer guidance, see UILayoutGuide and NSLayoutGuide.

A *safe area* defines the area within a window that isn’t covered on the edge by a hardware feature or another view within the window, like a toolbar, tab bar, or status bar. Respecting the safe area is essential to make sure system UI and hardware features like the Dynamic Island don’t obstruct content and controls. For developer guidance, see SafeAreaRegions and Positioning content relative to the safe area.

#### Platform considerations

*No additional considerations for iOS or iPadOS.*

#### macOS

**Avoid placing controls or critical information at the bottom of a window.** People often move windows so that the bottom edge is below the bottom of the screen.

**Avoid displaying content behind the camera housing at the top edge of the window.** For developer guidance, see NSPrefersDisplaySafeAreaCompatibilityMode.

#### tvOS

**Adhere to the screen’s safe area.** Inset primary content 60 points from the top and bottom of the screen, and 80 points from the sides. Providing these margins ensures your content is visible regardless of TV compatibility settings or overscan cropping.

**Include appropriate padding between focusable elements.** When you use UIKit and the focus APIs, an element gets bigger when it comes into focus. Consider how elements look when they’re focused, and make sure you don’t let them overlap important information. For developer guidance, see About focus interactions for Apple TV.

##### Grids

The following grid layouts provide an optimal viewing experience. Be sure to use appropriate spacing between unfocused rows and columns to prevent overlap when an item comes into focus.

If you use the UIKit collection view flow element, the number of columns in a grid is automatically determined based on the width and spacing of your content. For developer guidance, see UICollectionViewFlowLayout.

**Include additional vertical spacing for titled rows.** If a row has a title, provide enough spacing between the bottom of the previous unfocused row and the center of the title to avoid crowding. Also provide spacing between the bottom of the title and the top of the unfocused items in the row.

**Use consistent spacing.** When content isn’t consistently spaced, it no longer looks like a grid and it’s harder for people to scan.

**Make partially hidden content look symmetrical.** To help direct attention to the fully visible content, keep partially hidden offscreen content the same width on each side of the screen.

#### visionOS

In visionOS, you can lay out content within a window, a bounded 3D volume, or an immersive space. The guidance below focuses on laying out content in a window or volume; for guidance on displaying content spatially and best practices for using depth, scale, and positioning, see Spatial layout. To learn more about windows and volumes in visionOS, see visionOS.

**In general, support resizing.** The ability to resize windows and volumes is standard behavior in visionOS, just as in macOS and iPadOS. When you allow resizing, make sure your layout adapts well as it changes size, and prefer to keep content horizontally centered at very large sizes so people can easily view and interact with it.

You can also choose to set a minimum and maximum size for windows, volumes, and attached UI elements like ornaments. Use these settings to keep elements from overlapping at small sizes, and to keep large layouts from becoming too unwieldy; but don’t use minimum and maximum sizes as a way to prevent resizing. For example, in Safari, people can resize browser windows, but the custom navigation bar ornament has a fixed maximum size so that controls remain easy to access. For developer guidance, see Positioning and sizing windows.

**Use 3D content sparingly in windows.** While windows in visionOS can display 3D content at a fixed depth, reserve this for meaningful moments alongside 2D content. For example, an educational app might display an inline 3D model of a rocket next to information about the model. When displaying 3D content inline, place it inset in the window to avoid it colliding with other content or controls, or appearing unpredictably outside the window edge.

To display larger models or views that primarily consist of 3D content, consider using a volume or placing content in an immersive space.

**Display supplemental content in an adjacent window, not in an ornament.** While Ornaments are flexible enough to act as custom components, they are best for app-specific interactive controls like toolbars and video playback controls, not supplemental content. To display a supplemental content view, open a new window next to the current one using defaultWindowPlacement(_:) instead of placing the content in an ornament. For developer guidance, see Positioning and sizing windows.

**Include enough space around controls for them to be easy to interact with.** Put enough space around controls to make them clearly identifiable, and to prevent the system-provided hover effect from obscuring other content. For example, place buttons so their centers are at least 60 points apart. For guidance, see Eyes, Spatial layout, and visionOS.

#### watchOS

**Avoid placing more than two or three controls side by side in your interface.** As a general rule, display no more than three buttons that contain glyphs — or two buttons that contain text — in a row. Although it’s usually better to let text buttons span the full width of the screen, two side-by-side buttons with short text labels can also work well, as long as the screen doesn’t scroll.

**Support autorotation in views people might want to show others.** When people flip their wrist away, apps typically respond to the motion by sleeping the display, but in some cases it makes sense to autorotate the content. For example, a wearer might want to show an image to a friend or display a QR code to a reader. For developer guidance, see isAutorotating.

#### Resources

##### Related

Right to left

Spatial layout

Layout and organization

##### Developer documentation

Composing custom layouts with SwiftUI — SwiftUI

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
September 9, 2026
 | 
Updated guidance to reflect current best practices.
 | 
| 
September 9, 2025
 | 
Added specifications for iPhone 17, iPhone Air, iPhone 17 Pro, iPhone 17 Pro Max, Apple Watch SE 3, Apple Watch Series 11, and Apple Watch Ultra 3.
 | 
| 
June 9, 2025
 | 
Added guidance for Liquid Glass.
 | 
| 
March 7, 2025
 | 
Added specifications for iPhone 16e, iPad 11-inch, iPad Air 11-inch, and iPad Air 13-inch.
 | 
| 
September 9, 2024
 | 
Added specifications for iPhone 16, iPhone 16 Plus, iPhone 16 Pro, iPhone 16 Pro Max, and Apple Watch Series 10.
 | 
| 
June 10, 2024
 | 
Made minor corrections and organizational updates.
 | 
| 
February 2, 2024
 | 
Enhanced guidance for avoiding system controls in iPadOS app layouts, and added specifications for 10.9-inch iPad Air and 8.3-inch iPad mini.
 | 
| 
December 5, 2023
 | 
Clarified guidance on centering content in a visionOS window.
 | 
| 
September 15, 2023
 | 
Added specifications for iPhone 15 Pro Max, iPhone 15 Pro, iPhone 15 Plus, iPhone 15, Apple Watch Ultra 2, and Apple Watch SE.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 
| 
September 14, 2022
 | 
Added specifications for iPhone 14 Pro Max, iPhone 14 Pro, iPhone 14 Plus, iPhone 14, and Apple Watch Ultra.
 | 

---

## HIG: Typography

Source: https://developer.apple.com/design/human-interface-guidelines/typography

#### Ensuring legibility

**Use font sizes that most people can read easily.** People need to be able to read your content at various viewing distances and under a variety of conditions. Follow the recommended default and minimum text sizes for each platform — for both custom and system fonts — to ensure your text is legible on all devices. Keep in mind that font weight can also impact how easy text is to read. If you use a custom font with a thin weight, aim for larger than the recommended sizes to increase legibility.

| 
Platform
 | 
Default size
 | 
Minimum size
 | 
| 
iOS, iPadOS
 | 
17 pt
 | 
11 pt
 | 
| 
macOS
 | 
13 pt
 | 
10 pt
 | 
| 
tvOS
 | 
29 pt
 | 
23 pt
 | 
| 
visionOS
 | 
17 pt
 | 
12 pt
 | 
| 
watchOS
 | 
16 pt
 | 
12 pt
 | 

**Test legibility in different contexts.** For example, you need to test game text for legibility on each platform on which your game runs. If testing shows that some of your text is difficult to read, consider using a larger type size, increasing contrast by modifying the text or background colors, or using typefaces designed for optimized legibility, like the system fonts.

**In general, avoid light font weights.** For example, if you’re using system-provided fonts, prefer Regular, Medium, Semibold, or Bold font weights, and avoid Ultralight, Thin, and Light font weights, which can be difficult to see, especially when text is small.

#### Conveying hierarchy

**Adjust font weight, size, and color as needed to emphasize important information and help people visualize hierarchy.** Be sure to maintain the relative hierarchy and visual distinction of text elements when people adjust text sizes.

**Minimize the number of typefaces you use, even in a highly customized interface.** Mixing too many different typefaces can obscure your information hierarchy and hinder readability, in addition to making an interface feel internally inconsistent or poorly designed.

**Prioritize important content when responding to text-size changes.** Not all content is equally important. When someone chooses a larger text size, they typically want to make the content they care about easier to read; they don’t always want to increase the size of every word on the screen. For example, when people increase text size to read the content in a tabbed window, they don’t expect the tab titles to increase in size. Similarly, in a game, people are often more interested in a character’s dialog than in transient hit-damage values.

#### Using system fonts

Apple provides two typeface families that support an extensive range of weights, sizes, styles, and languages.

**San Francisco (SF)** is a sans serif typeface family that includes the SF Pro, SF Compact, SF Arabic, SF Armenian, SF Georgian, SF Hebrew, and SF Mono variants.

The system also offers SF Pro, SF Compact, SF Arabic, SF Armenian, SF Georgian, and SF Hebrew in rounded variants you can use to coordinate text with the appearance of soft or rounded UI elements, or to provide an alternative typographic voice.

**New York (NY)** is a serif typeface family designed to work well by itself and alongside the SF fonts.

You can download the San Francisco and New York fonts here.

The system provides the SF and NY fonts in the *variable* font format, which combines different font styles together in one file, and supports interpolation between styles to create intermediate ones.

> 
Variable fonts support *optical sizing*, which refers to the adjustment of different typographic designs to fit different sizes. On all platforms, the system fonts support *dynamic optical sizes*, which merge discrete optical sizes (like Text and Display) and weights into a single, continuous design, letting the system interpolate each glyph or letterform to produce a structure that’s precisely adapted to the point size. With dynamic optical sizes, you don’t need to use discrete optical sizes unless you’re working with a design tool that doesn’t support all the features of the variable font format.

To help you define visual hierarchies and create clear and legible designs in many different sizes and contexts, the system fonts are available in a variety of weights, ranging from Ultralight to Black, and — in the case of SF — several widths, including Condensed and Expanded. Because SF Symbols use equivalent weights, you can achieve precise weight matching between symbols and adjacent text, regardless of the size or style you choose.

> 
SF Symbols provides a comprehensive library of symbols that integrate seamlessly with the San Francisco system font, automatically aligning with text in all weights and sizes. Consider using symbols when you need to convey a concept or depict an object, especially within text.

The system defines a set of typographic attributes — called text styles — that work with both typeface families. A *text style* specifies a combination of font weight, point size, and leading values for each text size. For example, the *body* text style uses values that support a comfortable reading experience over multiple lines of text, while the *headline* style assigns a font size and weight that help distinguish a heading from surrounding content. Taken together, the text styles form a typographic hierarchy you can use to express the different levels of importance in your content. Text styles also allow text to scale proportionately when people change the system’s text size or make accessibility adjustments, like turning on Larger Text in Accessibility settings.

**Consider using the built-in text styles.** The system-defined text styles give you a convenient and consistent way to convey your information hierarchy through font size and weight. Using text styles with the system fonts also ensures support for Dynamic Type and larger accessibility type sizes (where available), which let people choose the text size that works for them. For guidance, see Supporting Dynamic Type.

**Modify the built-in text styles if necessary.** System APIs define font adjustments — called *symbolic traits* — that let you modify some aspects of a text style. For example, the bold trait adds weight to text, letting you create another level of hierarchy. You can also use symbolic traits to adjust leading if you need to improve readability or conserve space. For example, when you display text in wide columns or long passages, more space between lines (*loose leading*) can make it easier for people to keep their place while moving from one line to the next. Conversely, if you need to display multiple lines of text in an area where height is constrained — for example, in a list row — decreasing the space between lines (*tight leading*) can help the text fit well. If you need to display three or more lines of text, avoid tight leading even in areas where height is limited. For developer guidance, see leading(_:).

> 
You can use the constants defined in Font.Design to access all system fonts — don’t embed system fonts in your app or game. For example, use Font.Design.default to get the system font on all platforms; use Font.Design.serif to get the New York font.

**If necessary, adjust tracking in interface mockups.** In a running app, the system font dynamically adjusts tracking at every point size. To produce an accurate interface mockup of an interface that uses the variable system fonts, you don’t have to choose a discrete optical size at certain point sizes, but you might need to adjust the tracking. For guidance, see Tracking values.

#### Using custom fonts

**Make sure custom fonts are legible.** People need to be able to read your custom font easily at various viewing distances and under a variety of conditions. While using a custom font, be guided by the recommended minimum font sizes for various styles and weights in Specifications.

**Implement accessibility features for custom fonts.** System fonts automatically support Dynamic Type (where available) and respond when people turn on accessibility features, such as Bold Text. If you use a custom font, make sure it implements the same behaviors. For developer guidance, see Applying custom fonts to text. In a Unity-based game, you can use Apple’s Unity plug-ins to support Dynamic Type. If the plug-in isn’t appropriate for your game, be sure to let players adjust text size in other ways.

#### Supporting Dynamic Type

Dynamic Type is a system-level feature in iOS, iPadOS, tvOS, visionOS, and watchOS that lets people adjust the size of visible text on their device to ensure readability and comfort. For related guidance, see Accessibility.

For a list of available Dynamic Type sizes, see Specifications. You can also download Dynamic Type size tables in the Apple Design Resources for each platform.

For developer guidance, see Text input and output. To support Dynamic Type in Unity-based games, use Apple’s Unity plug-ins.

**Make sure your app’s layout adapts to all font sizes.** Verify that your design scales, and that text and glyphs are legible at all font sizes. On iPhone or iPad, turn on Larger Accessibility Text Sizes in Settings > Accessibility > Display & Text Size > Larger Text, and confirm that your app remains comfortably readable.

**Increase the size of meaningful interface icons as font size increases.** If you use interface icons to communicate important information, make sure they’re easy to view at larger font sizes too. When you use SF Symbols, you get icons that scale automatically with Dynamic Type size changes.

**Keep text truncation to a minimum as font size increases.** In general, aim to display as much useful text at the largest accessibility font size as you do at the largest standard font size. Avoid truncating text in scrollable regions unless people can open a separate view to read the rest of the content. You can prevent text truncation in a label by configuring it to use as many lines as needed to display a useful amount of text. For developer guidance, see numberOfLines.

**Consider adjusting your layout at large font sizes.** When font size increases in a horizontally constrained context, inline items (like glyphs and timestamps) and container boundaries can crowd text and cause truncation or overlapping. To improve readability, consider using a stacked layout where text appears above secondary items. Multicolumn text can also be less readable at large sizes due to horizontal space constraints. Reduce the number of columns when the font size increases to avoid truncation and enhance readability. For developer guidance, see isAccessibilityCategory.

**Maintain a consistent information hierarchy regardless of the current font size.** For example, keep primary elements toward the top of a view even when the font size is very large, so that people don’t lose track of these elements.

#### Platform considerations

#### iOS, iPadOS

SF Pro is the system font in iOS and iPadOS. iOS and iPadOS apps can also use NY.

#### macOS

SF Pro is the system font in macOS. NY is available for Mac apps built with Mac Catalyst. macOS doesn’t support Dynamic Type.

**When necessary, use dynamic system font variants to match the text in standard controls.** Dynamic system font variants give your text the same look and feel of the text that appears in system-provided controls. Use the variants listed below to achieve a look that’s consistent with other apps on the platform.

| 
Dynamic font variant
 | 
API
 | 
| 
Control content
 | 
controlContentFont(ofSize:)
 | 
| 
Label
 | 
labelFont(ofSize:)
 | 
| 
Menu
 | 
menuFont(ofSize:)
 | 
| 
Menu bar
 | 
menuBarFont(ofSize:)
 | 
| 
Message
 | 
messageFont(ofSize:)
 | 
| 
Palette
 | 
paletteFont(ofSize:)
 | 
| 
Title
 | 
titleBarFont(ofSize:)
 | 
| 
Tool tips
 | 
toolTipsFont(ofSize:)
 | 
| 
Document text (user)
 | 
userFont(ofSize:)
 | 
| 
Monospaced document text (user fixed pitch)
 | 
userFixedPitchFont(ofSize:)
 | 
| 
Bold system font
 | 
boldSystemFont(ofSize:)
 | 
| 
System font
 | 
systemFont(ofSize:)
 | 

#### tvOS

SF Pro is the system font in tvOS, and apps can also use NY.

#### visionOS

SF Pro is the system font in visionOS. If you use NY, you need to specify the type styles you want.

visionOS uses bolder versions of the Dynamic Type body and title styles and it introduces Extra Large Title 1 and Extra Large Title 2 for wide, editorial-style layouts. For guidance using vibrancy to indicate hierarchy in text and symbols, see visionOS.

**In general, prefer 2D text.** The more visual depth text characters have, the more difficult they can be to read. Although a small amount of 3D text can provide a fun visual element that draws people’s attention, if you’re going to display content that people need to read and understand, prefer using text that has little or no visual depth.

**Make sure text looks good and remains legible when people scale it.** Use a text style that makes the text look good at full scale, then test it for legibility at different scales.

**Maximize the contrast between text and the background of its container.** By default, the system displays text in white, because this color tends to provide a strong contrast with the default system background material, making text easier to read. If you want to use a different text color, be sure to test it in a variety of contexts.

**If you need to display text that’s not on a background, consider making it bold to improve legibility.** In this situation, you generally want to avoid adding shadows to increase text contrast. The current space might not include a visual surface on which to cast an accurate shadow, and you can’t predict the size and density of shadow that would work well with a person’s current Environment.

**Keep text facing people as much as possible.** If you display text that’s associated with a point in space, such as a label for a 3D object, you generally want to use *billboarding* — that is, you want the text to face the wearer regardless of how they or the object move. If you don’t rotate text to remain facing the wearer, the text can become impossible to read because people may view it from the side or a highly oblique angle. For example, imagine a virtual lamp that appears to be on a physical desk with a label anchored directly above it. For the text to remain readable, the label needs to rotate around the y-axis as people move around the desk; in other words, the baseline of the text needs to remain perpendicular to the person’s line of sight.

#### watchOS

SF Compact is the system font in watchOS, and apps can also use NY. In complications, watchOS uses SF Compact Rounded.

#### Specifications

You can display emphasized variants of system text styles using symbolic traits. In SwiftUI, use the bold() modifier; in UIKit, use traitBold in the UIFontDescriptor API. The emphasized weights can be medium, semibold, bold, or heavy. The following specifications include the emphasized weight for each text style.

#### iOS, iPadOS Dynamic Type sizes

#### iOS, iPadOS larger accessibility type sizes

#### macOS built-in text styles

| 
Text style
 | 
Weight
 | 
Size (points)
 | 
Line height (points)
 | 
Emphasized weight
 | 
| 
Large Title
 | 
Regular
 | 
26
 | 
32
 | 
Bold
 | 
| 
Title 1
 | 
Regular
 | 
22
 | 
26
 | 
Bold
 | 
| 
Title 2
 | 
Regular
 | 
17
 | 
22
 | 
Bold
 | 
| 
Title 3
 | 
Regular
 | 
15
 | 
20
 | 
Semibold
 | 
| 
Headline
 | 
Bold
 | 
13
 | 
16
 | 
Heavy
 | 
| 
Body
 | 
Regular
 | 
13
 | 
16
 | 
Semibold
 | 
| 
Callout
 | 
Regular
 | 
12
 | 
15
 | 
Semibold
 | 
| 
Subheadline
 | 
Regular
 | 
11
 | 
14
 | 
Semibold
 | 
| 
Footnote
 | 
Regular
 | 
10
 | 
13
 | 
Semibold
 | 
| 
Caption 1
 | 
Regular
 | 
10
 | 
13
 | 
Medium
 | 
| 
Caption 2
 | 
Medium
 | 
10
 | 
13
 | 
Semibold
 | 
Point size based on image resolution of 144 ppi for @2x designs.

#### tvOS built-in text styles

| 
Text style
 | 
Weight
 | 
Size (points)
 | 
Leading (points)
 | 
Emphasized weight
 | 
| 
Title 1
 | 
Medium
 | 
76
 | 
96
 | 
Bold
 | 
| 
Title 2
 | 
Medium
 | 
57
 | 
66
 | 
Bold
 | 
| 
Title 3
 | 
Medium
 | 
48
 | 
56
 | 
Bold
 | 
| 
Headline
 | 
Medium
 | 
38
 | 
46
 | 
Bold
 | 
| 
Subtitle 1
 | 
Regular
 | 
38
 | 
46
 | 
Medium
 | 
| 
Callout
 | 
Medium
 | 
31
 | 
38
 | 
Bold
 | 
| 
Body
 | 
Medium
 | 
29
 | 
36
 | 
Bold
 | 
| 
Caption 1
 | 
Medium
 | 
25
 | 
32
 | 
Bold
 | 
| 
Caption 2
 | 
Medium
 | 
23
 | 
30
 | 
Bold
 | 
Point size based on image resolution of 72 ppi for @1x and 144 ppi for @2x designs.

#### watchOS Dynamic Type sizes

#### watchOS larger accessibility type sizes

#### Tracking values

##### iOS, iPadOS, visionOS tracking values

##### macOS tracking values

| 
Size (points)
 | 
Tracking (1/1000 em)
 | 
Tracking (points)
 | 
| 
6
 | 
+41
 | 
+0.24
 | 
| 
7
 | 
+34
 | 
+0.23
 | 
| 
8
 | 
+26
 | 
+0.21
 | 
| 
9
 | 
+19
 | 
+0.17
 | 
| 
10
 | 
+12
 | 
+0.12
 | 
| 
11
 | 
+6
 | 
+0.06
 | 
| 
12
 | 
0
 | 
0.0
 | 
| 
13
 | 
-6
 | 
-0.08
 | 
| 
14
 | 
-11
 | 
-0.15
 | 
| 
15
 | 
-16
 | 
-0.23
 | 
| 
16
 | 
-20
 | 
-0.31
 | 
| 
17
 | 
-26
 | 
-0.43
 | 
| 
18
 | 
-25
 | 
-0.44
 | 
| 
19
 | 
-24
 | 
-0.45
 | 
| 
20
 | 
-23
 | 
-0.45
 | 
| 
21
 | 
-18
 | 
-0.36
 | 
| 
22
 | 
-12
 | 
-0.26
 | 
| 
23
 | 
-4
 | 
-0.10
 | 
| 
24
 | 
+3
 | 
+0.07
 | 
| 
25
 | 
+6
 | 
+0.15
 | 
| 
26
 | 
+8
 | 
+0.22
 | 
| 
27
 | 
+11
 | 
+0.29
 | 
| 
28
 | 
+14
 | 
+0.38
 | 
| 
29
 | 
+14
 | 
+0.40
 | 
| 
30
 | 
+14
 | 
+0.40
 | 
| 
31
 | 
+13
 | 
+0.39
 | 
| 
32
 | 
+13
 | 
+0.41
 | 
| 
33
 | 
+12
 | 
+0.40
 | 
| 
34
 | 
+12
 | 
+0.40
 | 
| 
35
 | 
+11
 | 
+0.38
 | 
| 
36
 | 
+10
 | 
+0.37
 | 
| 
37
 | 
+10
 | 
+0.36
 | 
| 
38
 | 
+10
 | 
+0.37
 | 
| 
39
 | 
+10
 | 
+0.38
 | 
| 
40
 | 
+10
 | 
+0.37
 | 
| 
41
 | 
+9
 | 
+0.36
 | 
| 
42
 | 
+9
 | 
+0.37
 | 
| 
43
 | 
+9
 | 
+0.38
 | 
| 
44
 | 
+8
 | 
+0.37
 | 
| 
45
 | 
+8
 | 
+0.35
 | 
| 
46
 | 
+8
 | 
+0.36
 | 
| 
47
 | 
+8
 | 
+0.37
 | 
| 
48
 | 
+8
 | 
+0.35
 | 
| 
49
 | 
+7
 | 
+0.33
 | 
| 
50
 | 
+7
 | 
+0.34
 | 
| 
51
 | 
+7
 | 
+0.35
 | 
| 
52
 | 
+6
 | 
+0.31
 | 
| 
53
 | 
+6
 | 
+0.33
 | 
| 
54
 | 
+6
 | 
+0.32
 | 
| 
56
 | 
+6
 | 
+0.30
 | 
| 
58
 | 
+5
 | 
+0.28
 | 
| 
60
 | 
+4
 | 
+0.26
 | 
| 
62
 | 
+4
 | 
+0.24
 | 
| 
64
 | 
+4
 | 
+0.22
 | 
| 
66
 | 
+3
 | 
+0.19
 | 
| 
68
 | 
+2
 | 
+0.17
 | 
| 
70
 | 
+2
 | 
+0.14
 | 
| 
72
 | 
+2
 | 
+0.14
 | 
| 
76
 | 
+1
 | 
+0.07
 | 
| 
80
 | 
0
 | 
0
 | 
| 
84
 | 
0
 | 
0
 | 
| 
88
 | 
0
 | 
0
 | 
| 
92
 | 
0
 | 
0
 | 
| 
96
 | 
0
 | 
0
 | 
Not all apps express tracking values as 1/1000 em. Point size based on image resolution of 144 ppi for @2x and 216 ppi for @3x designs.

##### tvOS tracking values

| 
Size (points)
 | 
Tracking (1/1000 em)
 | 
Tracking (points)
 | 
| 
6
 | 
+41
 | 
+0.24
 | 
| 
7
 | 
+34
 | 
+0.23
 | 
| 
8
 | 
+26
 | 
+0.21
 | 
| 
9
 | 
+19
 | 
+0.17
 | 
| 
10
 | 
+12
 | 
+0.12
 | 
| 
11
 | 
+6
 | 
+0.06
 | 
| 
12
 | 
0
 | 
0.0
 | 
| 
13
 | 
-6
 | 
-0.08
 | 
| 
14
 | 
-11
 | 
-0.15
 | 
| 
15
 | 
-16
 | 
-0.23
 | 
| 
16
 | 
-20
 | 
-0.31
 | 
| 
17
 | 
-26
 | 
-0.43
 | 
| 
18
 | 
-25
 | 
-0.44
 | 
| 
19
 | 
-24
 | 
-0.45
 | 
| 
20
 | 
-23
 | 
-0.45
 | 
| 
21
 | 
-18
 | 
-0.36
 | 
| 
22
 | 
-12
 | 
-0.26
 | 
| 
23
 | 
-4
 | 
-0.10
 | 
| 
24
 | 
+3
 | 
+0.07
 | 
| 
25
 | 
+6
 | 
+0.15
 | 
| 
26
 | 
+8
 | 
+0.22
 | 
| 
27
 | 
+11
 | 
+0.29
 | 
| 
28
 | 
+14
 | 
+0.38
 | 
| 
29
 | 
+14
 | 
+0.40
 | 
| 
30
 | 
+14
 | 
+0.40
 | 
| 
31
 | 
+13
 | 
+0.39
 | 
| 
32
 | 
+13
 | 
+0.41
 | 
| 
33
 | 
+12
 | 
+0.40
 | 
| 
34
 | 
+12
 | 
+0.40
 | 
| 
35
 | 
+11
 | 
+0.38
 | 
| 
36
 | 
+10
 | 
+0.37
 | 
| 
37
 | 
+10
 | 
+0.36
 | 
| 
38
 | 
+10
 | 
+0.37
 | 
| 
39
 | 
+10
 | 
+0.38
 | 
| 
40
 | 
+10
 | 
+0.37
 | 
| 
41
 | 
+9
 | 
+0.36
 | 
| 
42
 | 
+9
 | 
+0.37
 | 
| 
43
 | 
+9
 | 
+0.38
 | 
| 
44
 | 
+8
 | 
+0.37
 | 
| 
45
 | 
+8
 | 
+0.35
 | 
| 
46
 | 
+8
 | 
+0.36
 | 
| 
47
 | 
+8
 | 
+0.37
 | 
| 
48
 | 
+8
 | 
+0.35
 | 
| 
49
 | 
+7
 | 
+0.33
 | 
| 
50
 | 
+7
 | 
+0.34
 | 
| 
51
 | 
+7
 | 
+0.35
 | 
| 
52
 | 
+6
 | 
+0.31
 | 
| 
53
 | 
+6
 | 
+0.33
 | 
| 
54
 | 
+6
 | 
+0.32
 | 
| 
56
 | 
+6
 | 
+0.30
 | 
| 
58
 | 
+5
 | 
+0.28
 | 
| 
60
 | 
+4
 | 
+0.26
 | 
| 
62
 | 
+4
 | 
+0.24
 | 
| 
64
 | 
+4
 | 
+0.22
 | 
| 
66
 | 
+3
 | 
+0.19
 | 
| 
68
 | 
+2
 | 
+0.17
 | 
| 
70
 | 
+2
 | 
+0.14
 | 
| 
72
 | 
+2
 | 
+0.14
 | 
| 
76
 | 
+1
 | 
+0.07
 | 
| 
80
 | 
0
 | 
0
 | 
| 
84
 | 
0
 | 
0
 | 
| 
88
 | 
0
 | 
0
 | 
| 
92
 | 
0
 | 
0
 | 
| 
96
 | 
0
 | 
0
 | 
Not all apps express tracking values as 1/1000 em. Point size based on image resolution of 144 ppi for @2x and 216 ppi for @3x designs.

##### watchOS tracking values

#### Resources

##### Related

here

SF Symbols

##### Developer documentation

Text input and output — SwiftUI

Text display and fonts — UIKit

Fonts — AppKit

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
December 16, 2025
 | 
Added emphasized weights to the Dynamic Type style specifications for each platform.
 | 
| 
March 7, 2025
 | 
Expanded guidance for Dynamic Type.
 | 
| 
June 10, 2024
 | 
Added guidance for using Apple’s Unity plug-ins to support Dynamic Type in a Unity-based game and enhanced guidance on billboarding in a visionOS app or game.
 | 
| 
September 12, 2023
 | 
Added artwork illustrating system font weights, and clarified tvOS specification table descriptions.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 

---

## HIG: Color

Source: https://developer.apple.com/design/human-interface-guidelines/color

The system defines colors that look good on various backgrounds and appearance modes, and can automatically adapt to vibrancy and accessibility settings. Using system colors is a convenient way to make your experience feel at home on the device.

You may also want to use custom colors to enhance the visual experience of your app or game and express its unique personality. The following guidelines can help you use color in ways that people appreciate, regardless of whether you use system-defined or custom colors.

#### Best practices

**Avoid using the same color to mean different things.** Use color consistently throughout your interface, especially when you use it to help communicate information like status or interactivity. For example, if you use your brand color to indicate that a borderless button is interactive, using the same or similar color to stylize noninteractive text is confusing.

**Make sure all your app’s colors work well in light, dark, and increased contrast contexts.** iOS, iPadOS, macOS, and tvOS offer both light and Dark Mode appearance settings. System colors vary subtly depending on the system appearance, adjusting to ensure proper color differentiation and contrast for text, symbols, and other elements. With the Increase Contrast setting turned on, the color differences become far more apparent. When possible, use system colors, which already define variants for all these contexts. If you define a custom color, make sure to supply light and dark variants, and an increased contrast option for each variant that provides a significantly higher amount of visual differentiation. Even if your app ships in a single appearance mode, provide both light and dark colors to support Liquid Glass adaptivity in these contexts.

**Test your app’s color scheme under a variety of lighting conditions.** Colors can look different when you view your app outside on a sunny day or in dim light. In bright surroundings, colors look darker and more muted. In dark environments, colors appear bright and saturated. In visionOS, colors can look different depending on the colors of a wall or object in a person’s physical surroundings and how it reflects light. Adjust app colors to provide an optimal viewing experience in the majority of use cases.

**Test your app on different devices.** For example, the True Tone display — available on certain iPhone, iPad, and Mac models — uses ambient light sensors to automatically adjust the white point of the display to adapt to the lighting conditions of the current environment. Apps that primarily support reading, photos, video, and gaming can strengthen or weaken this effect by specifying a white point adaptivity style (for developer guidance, see UIWhitePointAdaptivityStyle). Test tvOS apps on multiple brands of HD and 4K TVs, and with different display settings. You can also test the appearance of your app using different color profiles on a Mac — such as P3 and Standard RGB (sRGB) — by choosing a profile in System Settings > Displays. For guidance, see Color management.

**Consider how artwork and translucency affect nearby colors.** Variations in artwork sometimes warrant changes to nearby colors to maintain visual continuity and prevent interface elements from becoming overpowering or underwhelming. Maps, for example, displays a light color scheme when in map mode but switches to a dark color scheme when in satellite mode. Colors can also appear different when placed behind or applied to a translucent element like a toolbar.

**If your app lets people choose colors, prefer system-provided color controls where available.** Using built-in color pickers provides a consistent user experience, in addition to letting people save a set of colors they can access from any app. For developer guidance, see ColorPicker.

#### Inclusive color

**Avoid relying solely on color to differentiate between objects, indicate interactivity, or communicate essential information.** When you use color to convey information, be sure to provide the same information in alternative ways so people with color blindness or other visual disabilities can understand it. For example, you can use text labels or glyph shapes to identify objects or states.

**Avoid using colors that make it hard to perceive content in your app.** For example,  insufficient contrast can cause icons and text to blend with the background and make content hard to read, and people who are color blind might not be able to distinguish some color combinations. For guidance, see Accessibility.

**Consider how the colors you use might be perceived in other countries and cultures.** For example, red communicates danger in some cultures, but has positive connotations in other cultures. Make sure the colors in your app send the message you intend.

#### System colors

**Avoid hard-coding system color values in your app.** Documented color values are for your reference during the app design process. The actual color values may fluctuate from release to release, based on a variety of environmental variables. Use APIs like Color to apply system colors.

iOS, iPadOS, macOS, and visionOS also define sets of *dynamic system colors* that match the color schemes of standard UI components and automatically adapt to both light and dark contexts. Each dynamic color is semantically defined by its purpose, rather than its appearance or color values. For example, some colors represent view backgrounds at different levels of hierarchy and other colors represent foreground content, such as labels, links, and separators.

**Avoid redefining the semantic meanings of dynamic system colors.** To ensure a consistent experience and ensure your interface looks great when the appearance of the platform changes, use dynamic system colors as intended. For example, don’t use the separator color as a text color, or secondary text label color as a background color.

#### Liquid Glass color

By default, Liquid Glass has no inherent color, and instead takes on colors from the content directly behind it. You can apply color to some Liquid Glass elements, giving them the appearance of colored or stained glass. This is useful for drawing emphasis to a specific control, like a primary call to action, and is the approach the system uses for prominent button styling. Symbols or text labels on Liquid Glass controls can also have color.

For smaller elements like toolbars and tab bars, the system can adapt Liquid Glass between a light and dark appearance in response to the underlying content. By default, symbols and text on these elements follow a monochromatic color scheme, becoming darker when the underlying content is light, and lighter when it’s dark. Liquid Glass appears more opaque in larger elements like sidebars to preserve legibility over complex backgrounds and accommodate richer content on the material’s surface.

**Apply color sparingly to the Liquid Glass material, and to symbols or text on the material.** If you apply color, reserve it for elements that truly benefit from emphasis, such as status indicators or primary actions. To emphasize primary actions, apply color to the background rather than to symbols or text. For example, the system applies the app accent color to the background in prominent buttons — such as the Done button — to draw attention and elevate their visual prominence. Refrain from adding color to the background of multiple controls.

**Avoid using similar colors in control labels if your app has a colorful background.** While color can make apps more visually appealing, playful, or reflective of your brand, too much color can be overwhelming and make control labels more difficult to read. If your app features colorful backgrounds or visually rich content, prefer a monochromatic appearance for toolbars and tab bars, or choose an accent color with sufficient visual differentiation. By contrast, in apps with primarily monochromatic content or backgrounds, choosing your brand color as the app accent color can be an effective way to tailor your app experience and reflect your company’s identity.

**Be aware of the placement of color in the content layer.** Make sure your interface maintains sufficient contrast by avoiding overlap of similar colors in the content layer and controls when possible. Although colorful content might intermittently scroll underneath controls, make sure its default or resting state — like the top of a screen of scrollable content — maintains clear legibility.

#### Color management

A *color space* represents the colors in a *color model* like RGB or CMYK. Common color spaces — sometimes called *gamuts* — are sRGB and Display P3.

A *color profile* describes the colors in a color space using, for example, mathematical formulas or tables of data that map colors to numerical representations. An image embeds its color profile so that a device can interpret the image’s colors correctly and reproduce them on a display.

**Apply color profiles to your images.** Color profiles help ensure that your app’s colors appear as intended on different displays. The sRGB color space produces accurate colors on most displays.

**Use wide color to enhance the visual experience on compatible displays.** Wide color displays support a P3 color space, which can produce richer, more saturated colors than sRGB. As a result, photos and videos that use wide color are more lifelike, and visual data and status indicators that use wide color can be more meaningful. When appropriate, use the Display P3 color profile at 16 bits per pixel (per channel) and export images in PNG format. Note that you need to use a wide color display to design wide color images and select P3 colors.

**Provide color space–specific image and color variations if necessary.** In general, P3 colors and images appear fine on sRGB displays. Occasionally, it may be hard to distinguish two very similar P3 colors when viewing them on an sRGB display. Gradients that use P3 colors can also sometimes appear clipped on sRGB displays. To avoid these issues and to ensure visual fidelity on both wide color and sRGB displays, you can use the asset catalog of your Xcode project to provide different versions of images and colors for each color space.

#### Platform considerations

#### iOS, iPadOS

iOS defines two sets of dynamic background colors — *system* and *grouped* — each of which contains primary, secondary, and tertiary variants that help you convey a hierarchy of information. In general, use the grouped background colors (systemGroupedBackground, secondarySystemGroupedBackground, and tertiarySystemGroupedBackground) when you have a grouped table view; otherwise, use the system set of background colors (systemBackground, secondarySystemBackground, and tertiarySystemBackground).

With both sets of background colors, you generally use the variants to indicate hierarchy in the following ways:

- Primary for the overall view

- Secondary for grouping content or elements within the overall view

- Tertiary for grouping content or elements within secondary elements

For foreground content, iOS defines the following dynamic colors:

| 
Color
 | 
Use for…
 | 
UIKit API
 | 
| 
Label
 | 
A text label that contains primary content.
 | 
label
 | 
| 
Secondary label
 | 
A text label that contains secondary content.
 | 
secondaryLabel
 | 
| 
Tertiary label
 | 
A text label that contains tertiary content.
 | 
tertiaryLabel
 | 
| 
Quaternary label
 | 
A text label that contains quaternary content.
 | 
quaternaryLabel
 | 
| 
Placeholder text
 | 
Placeholder text in controls or text views.
 | 
placeholderText
 | 
| 
Separator
 | 
A separator that allows some underlying content to be visible.
 | 
separator
 | 
| 
Opaque separator
 | 
A separator that doesn’t allow any underlying content to be visible.
 | 
opaqueSeparator
 | 
| 
Link
 | 
Text that functions as a link.
 | 
link
 | 

#### macOS

macOS defines the following dynamic system colors (you can also view them in the Developer palette of the standard Color panel):

| 
Color
 | 
Use for…
 | 
AppKit API
 | 
| 
Alternate selected control text color
 | 
The text on a selected surface in a list or table.
 | 
alternateSelectedControlTextColor
 | 
| 
Alternating content background colors
 | 
The backgrounds of alternating rows or columns in a list, table, or collection view.
 | 
alternatingContentBackgroundColors
 | 
| 
Control accent
 | 
The accent color people select in System Settings.
 | 
controlAccentColor
 | 
| 
Control background color
 | 
The background of a large interface element, such as a browser or table.
 | 
controlBackgroundColor
 | 
| 
Control color
 | 
The surface of a control.
 | 
controlColor
 | 
| 
Control text color
 | 
The text of a control that is available.
 | 
controlTextColor
 | 
| 
Current control tint
 | 
The system-defined control tint.
 | 
currentControlTint
 | 
| 
Unavailable control text color
 | 
The text of a control that’s unavailable.
 | 
disabledControlTextColor
 | 
| 
Find highlight color
 | 
The color of a find indicator.
 | 
findHighlightColor
 | 
| 
Grid color
 | 
The gridlines of an interface element, such as a table.
 | 
gridColor
 | 
| 
Header text color
 | 
The text of a header cell in a table.
 | 
headerTextColor
 | 
| 
Highlight color
 | 
The virtual light source onscreen.
 | 
highlightColor
 | 
| 
Keyboard focus indicator color
 | 
The ring that appears around the currently focused control when using the keyboard for interface navigation.
 | 
keyboardFocusIndicatorColor
 | 
| 
Label color
 | 
The text of a label containing primary content.
 | 
labelColor
 | 
| 
Link color
 | 
A link to other content.
 | 
linkColor
 | 
| 
Placeholder text color
 | 
A placeholder string in a control or text view.
 | 
placeholderTextColor
 | 
| 
Quaternary label color
 | 
The text of a label of lesser importance than a tertiary label, such as watermark text.
 | 
quaternaryLabelColor
 | 
| 
Secondary label color
 | 
The text of a label of lesser importance than a primary label, such as a label used to represent a subheading or additional information.
 | 
secondaryLabelColor
 | 
| 
Selected content background color
 | 
The background for selected content in a key window or view.
 | 
selectedContentBackgroundColor
 | 
| 
Selected control color
 | 
The surface of a selected control.
 | 
selectedControlColor
 | 
| 
Selected control text color
 | 
The text of a selected control.
 | 
selectedControlTextColor
 | 
| 
Selected menu item text color
 | 
The text of a selected menu.
 | 
selectedMenuItemTextColor
 | 
| 
Selected text background color
 | 
The background of selected text.
 | 
selectedTextBackgroundColor
 | 
| 
Selected text color
 | 
The color for selected text.
 | 
selectedTextColor
 | 
| 
Separator color
 | 
A separator between different sections of content.
 | 
separatorColor
 | 
| 
Shadow color
 | 
The virtual shadow cast by a raised object onscreen.
 | 
shadowColor
 | 
| 
Tertiary label color
 | 
The text of a label of lesser importance than a secondary label.
 | 
tertiaryLabelColor
 | 
| 
Text background color
 | 
The background color behind text.
 | 
textBackgroundColor
 | 
| 
Text color
 | 
The text in a document.
 | 
textColor
 | 
| 
Under page background color
 | 
The background behind a document’s content.
 | 
underPageBackgroundColor
 | 
| 
Unemphasized selected content background color
 | 
The selected content in a non-key window or view.
 | 
unemphasizedSelectedContentBackgroundColor
 | 
| 
Unemphasized selected text background color
 | 
A background for selected text in a non-key window or view.
 | 
unemphasizedSelectedTextBackgroundColor
 | 
| 
Unemphasized selected text color
 | 
Selected text in a non-key window or view.
 | 
unemphasizedSelectedTextColor
 | 
| 
Window background color
 | 
The background of a window.
 | 
windowBackgroundColor
 | 
| 
Window frame text color
 | 
The text in the window’s title bar area.
 | 
windowFrameTextColor
 | 

##### App accent colors

Beginning in macOS 11, you can specify an *accent color* to customize the appearance of your app’s buttons, selection highlighting, and sidebar icons. The system applies your accent color when the current value in General > Accent color settings is *multicolor*.

If people set their accent color setting to a value other than multicolor, the system applies their chosen color to the relevant items throughout your app, replacing your accent color. The exception is a sidebar icon that uses a fixed color you specify. Because a fixed-color sidebar icon uses a specific color to provide meaning, the system doesn’t override its color when people change the value of accent color settings. For guidance, see Sidebars.

#### tvOS

**Consider choosing a limited color palette that coordinates with your app logo.** Subtle use of color can help you communicate your brand while deferring to the content.

**Avoid using only color to indicate focus.** Subtle scaling and responsive animation are the primary ways to denote interactivity when an element is in focus.

#### visionOS

**Use color sparingly, especially on glass.** Standard visionOS windows typically use the system-defined glass Materials, which lets light and objects from people’s physical surroundings and their space show through. Because the colors in these physical and virtual objects are visible through the glass, they can affect the legibility of colorful app content in the window. Prefer using color in places where it can help call attention to important information or show the relationship between parts of the interface.

**Prefer using color in bold text and large areas.** Color in lightweight text or small areas can make them harder to see and understand.

**In a fully immersive experience, help people maintain visual comfort by keeping brightness levels balanced.** Although using high contrast can help direct people’s attention to important content, it can also cause visual discomfort if people’s eyes have adjusted to low light or darkness. Consider making content fully bright only when the rest of the visual context is also bright. For example, avoid displaying a bright object on a very dark or black background, especially if the object flashes or moves.

#### watchOS

**Use background color to support existing content or supply additional information.** Background color can establish a sense of place and help people recognize key content. For example, in Activity, each infographic view for the Move, Exercise, and Stand Activity rings has a background that matches the color of the ring. Use background color when you have something to communicate, rather than as a solely visual flourish. Avoid using full-screen background color in views that are likely to remain onscreen for long periods of time, such as in a workout or audio-playing app.

**Recognize that people might prefer graphic complications to use tinted mode instead of full color.** The system can use a single color that’s based on the wearer’s selected color in a graphic complication’s images, gauges, and text. For guidance, see Complications.

#### Specifications

#### System colors

| 
Name
 | 
SwiftUI API
 | 
Default (light)
 | 
Default (dark)
 | 
Increased contrast (light)
 | 
Increased contrast (dark)
 | 
| 
Red
 | 
red
 | 

 | 

 | 

 | 

 | 
| 
Orange
 | 
orange
 | 

 | 

 | 

 | 

 | 
| 
Yellow
 | 
yellow
 | 

 | 

 | 

 | 

 | 
| 
Green
 | 
green
 | 

 | 

 | 

 | 

 | 
| 
Mint
 | 
mint
 | 

 | 

 | 

 | 

 | 
| 
Teal
 | 
teal
 | 

 | 

 | 

 | 

 | 
| 
Cyan
 | 
cyan
 | 

 | 

 | 

 | 

 | 
| 
Blue
 | 
blue
 | 

 | 

 | 

 | 

 | 
| 
Indigo
 | 
indigo
 | 

 | 

 | 

 | 

 | 
| 
Purple
 | 
purple
 | 

 | 

 | 

 | 

 | 
| 
Pink
 | 
pink
 | 

 | 

 | 

 | 

 | 
| 
Brown
 | 
brown
 | 

 | 

 | 

 | 

 | 

visionOS system colors use the default dark color values.

#### iOS, iPadOS system gray colors

| 
Name
 | 
UIKit API
 | 
Default (light)
 | 
Default (dark)
 | 
Increased contrast (light)
 | 
Increased contrast (dark)
 | 
| 
Gray
 | 
systemGray
 | 

 | 

 | 

 | 

 | 
| 
Gray (2)
 | 
systemGray2
 | 

 | 

 | 

 | 

 | 
| 
Gray (3)
 | 
systemGray3
 | 

 | 

 | 

 | 

 | 
| 
Gray (4)
 | 
systemGray4
 | 

 | 

 | 

 | 

 | 
| 
Gray (5)
 | 
systemGray5
 | 

 | 

 | 

 | 

 | 
| 
Gray (6)
 | 
systemGray6
 | 

 | 

 | 

 | 

 | 

In SwiftUI, the equivalent of `systemGray` is gray.

#### Resources

##### Related

Dark Mode

Accessibility

Materials

Apple Design Resources

##### Developer documentation

Color — SwiftUI

UIColor — UIKit

Color — AppKit

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
December 16, 2025
 | 
Updated guidance for Liquid Glass.
 | 
| 
June 9, 2025
 | 
Updated system color values, and added guidance for Liquid Glass.
 | 
| 
February 2, 2024
 | 
Distinguished UIKit and SwiftUI gray colors in iOS and iPadOS, and added guidance for balancing brightness levels in visionOS apps.
 | 
| 
September 12, 2023
 | 
Enhanced guidance for using background color in watchOS views, and added color swatches for tvOS.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 
| 
June 5, 2023
 | 
Updated guidance for using background color in watchOS.
 | 
| 
December 19, 2022
 | 
Corrected RGB values for system mint color (Dark Mode) in iOS and iPadOS.
 | 

---

## HIG: Dark Mode

Source: https://developer.apple.com/design/human-interface-guidelines/dark-mode

In iOS, iPadOS, macOS, and tvOS, people often choose Dark Mode as their default interface style, and they generally expect all apps and games to respect their preference. In Dark Mode, the system uses a dark color palette for all screens, views, menus, and controls, and may also use greater perceptual contrast to make foreground content stand out against the darker backgrounds.

#### Best practices

**Avoid offering an app-specific appearance setting.** An app-specific appearance mode option creates more work for people because they have to adjust more than one setting to get the appearance they want. Worse, they may think your app is broken because it doesn’t respond to their systemwide appearance choice.

**Ensure that your app looks good in both appearance modes.** In addition to using one mode or the other, people can choose the Auto appearance setting, which switches between the light and dark appearances as conditions change throughout the day, potentially while your app is running.

**Test your content to make sure that it remains comfortably legible in both appearance modes.** For example, in Dark Mode with Increase Contrast and Reduce Transparency turned on (both separately and together), you may find places where dark text is less legible when it’s on a dark background. You might also find that turning on Increase Contrast in Dark Mode can result in reduced visual contrast between dark text and a dark background. Although people with strong vision might still be able to read lower contrast text, such text could be illegible for many. For guidance, see Accessibility.

**In rare cases, consider using only a dark appearance in the interface.** For example, it can make sense for an app that supports immersive media viewing to use a permanently dark appearance that lets the UI recede and helps people focus on the media.

#### Dark Mode colors

The color palette in Dark Mode includes dimmer background colors and brighter foreground colors. It’s important to realize that these colors aren’t necessarily inversions of their light counterparts: while many colors are inverted, some are not. For more information, see Specifications.

**Embrace colors that adapt to the current appearance.** Semantic colors (like labelColor and controlColor in macOS or separator in iOS and iPadOS) automatically adapt to the current appearance. When you need a custom color, add a Color Set asset to your app’s asset catalog in Xcode, and specify the bright and dim variants of the color. Avoid using hard-coded color values or colors that don’t adapt.

**Aim for sufficient color contrast in all appearances.** Using system-defined colors can help you achieve a good contrast ratio between your foreground and background content. At a minimum, make sure the contrast ratio between colors is no lower than 4.5:1. For custom foreground and background colors, strive for a contrast ratio of 7:1, especially in small text. This ratio ensures that your foreground content stands out from the background, and helps your content meet recommended accessibility guidelines.

**Soften the color of white backgrounds.** If you display a content image that includes a white background, consider slightly darkening the image to prevent the background from glowing in the surrounding Dark Mode context.

#### Icons and images

The system uses SF Symbols (which automatically adapt to Dark Mode) and full-color images that are optimized for both the light and dark appearances.

**Use SF Symbols wherever possible.** Symbols work well in both appearance modes when you use dynamic colors to tint them or when you add vibrancy. For guidance, see Color.

**Design separate interface icons for the light and dark appearances if necessary.** For example, an icon that depicts a full moon might need a subtle dark outline to contrast well with a light background, but need no outline when it displays on a dark background. Similarly, an icon that represents a drop of oil might need a slight border to make the edge visible against a dark background.

**Make sure full-color images and icons look good in both appearances.** Use the same asset if it looks good in both the light and dark appearances. If an asset looks good in only one mode, modify the asset or create separate light and dark assets. Use asset catalogs to combine your assets into a single named image.

#### Text

The system uses vibrancy and increased contrast to maintain the legibility of text on darker backgrounds.

**Use the system-provided label colors for labels.** The primary, secondary, tertiary, and quaternary label colors adapt automatically to the light and dark appearances.

**Use system views to draw text fields and text views.** System views and controls make your app’s text look good on all backgrounds, adjusting automatically for the presence or absence of vibrancy. When possible, use a system-provided view to display text instead of drawing the text yourself.

#### Platform considerations

*No additional considerations for tvOS. Dark Mode isn’t supported in visionOS or watchOS.*

#### iOS, iPadOS

In Dark Mode, the system uses two sets of background colors — called *base* and *elevated* — to enhance the perception of depth when one dark interface is layered above another. The base colors are dimmer, making background interfaces appear to recede, and the elevated colors are brighter, making foreground interfaces appear to advance.

**Prefer the system background colors.** Dark Mode is dynamic, which means that the background color automatically changes from base to elevated when an interface is in the foreground, such as a popover or modal sheet. The system also uses the elevated background color to provide visual separation between apps in a multitasking environment and between windows in a multiple-window context. Using a custom background color can make it harder for people to perceive these system-provided visual distinctions.

#### macOS

When people choose the graphite accent color in General settings, macOS causes window backgrounds to pick up color from the current desktop picture. The result — called *desktop tinting* — is a subtle effect that helps windows blend more harmoniously with their surrounding content.

**Include some transparency in custom component backgrounds when appropriate.** Transparency lets your components pick up color from the window background when desktop tinting is active, creating a visual harmony that can persist even when the desktop picture changes. To help achieve this harmony, add transparency only to a custom component that has a visible background or bezel, and only when the component is in a neutral state, such as state that doesn’t use color. You don’t want to add transparency when the component is in a state that uses color, because doing so can cause the component’s color to fluctuate when the window background adjusts to a different location on the desktop or when the desktop picture changes.

#### Resources

##### Related

Color

Materials

Typography

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
August 6, 2024
 | 
Added art contrasting the light and dark appearances.
 | 

---

## HIG: Icons

Source: https://developer.apple.com/design/human-interface-guidelines/icons

Apps and games use a variety of simple icons to help people understand the items, actions, and modes they can choose. Unlike App icons, which can use rich visual details like shading, texturing, and highlighting to evoke the app’s personality, an *interface icon* typically uses streamlined shapes and touches of color to communicate a straightforward idea.

You can design interface icons — also called *glyphs* — or you can choose symbols from the SF Symbols app, using them as-is or customizing them to suit your needs. Both interface icons and symbols use black and clear colors to define their shapes; the system can apply other colors to the black areas in each image. For guidance, see SF Symbols.

#### Best practices

**Create a recognizable, highly simplified design.** Too many details can make an interface icon confusing or unreadable. Strive for a simple, universal design that most people will recognize quickly. In general, icons work best when they use familiar visual metaphors that are directly related to the actions they initiate or content they represent.

**Maintain visual consistency across all interface icons in your app.** Whether you use only custom icons or mix custom and system-provided ones, all interface icons in your app need to use a consistent size, level of detail, stroke thickness (or weight), and perspective. Depending on the visual weight of an icon, you may need to adjust its dimensions to ensure that it appears visually consistent with other icons.

**In general, match the weights of interface icons and adjacent text.** Unless you want to emphasize either the icons or the text, using the same weight for both gives your content a consistent appearance and level of emphasis.

**If necessary, add padding to a custom interface icon to achieve optical alignment.** Some icons — especially asymmetric ones — can look unbalanced when you center them geometrically instead of optically. For example, the download icon shown below has more visual weight on the bottom than on the top, which can make it look too low if it’s geometrically centered.

In such cases, you can slightly adjust the position of the icon until it’s optically centered. When you create an asset that includes your adjustments as padding around an interface icon (as shown below on the right), you can optically center the icon by geometrically centering the asset.

Adjustments for optical centering are typically very small, but they can have a big impact on your app’s appearance.

**Provide a selected-state version of an interface icon only if necessary.** You don’t need to provide selected and unselected appearances for an icon that’s used in standard system components such as toolbars, tab bars, and buttons. The system updates the visual appearance of the selected state automatically.

**Use inclusive images.** Consider how your icons can be understandable and welcoming to everyone. Prefer depicting gender-neutral human figures and avoid images that might be hard to recognize across different cultures or languages. For guidance, see Inclusion.

**Include text in your design only when it’s essential for conveying meaning.** For example, using a character in an interface icon that represents text formatting can be the most direct way to communicate the concept. If you need to display individual characters in your icon, be sure to localize them. If you need to suggest a passage of text, design an abstract representation of it, and include a flipped version of the icon to use when the context is right-to-left. For guidance, see Right to left.

**If you create a custom interface icon, use a vector format like PDF or SVG.** The system automatically scales a vector-based interface icon for high-resolution displays, so you don’t need to provide high-resolution versions of it. In contrast, PNG — used for app icons and other images that include effects like shading, textures, and highlighting — doesn’t support scaling, so you have to supply multiple versions for each PNG-based interface icon. Alternatively, you can create a custom SF Symbol and specify a scale that ensures the symbol’s emphasis matches adjacent text. For guidance, see SF Symbols.

**Provide alternative text labels for custom interface icons.** Alternative text labels — or accessibility descriptions — aren’t visible, but they let VoiceOver audibly describe what’s onscreen, simplifying navigation for people with visual disabilities. For guidance, see VoiceOver.

**Avoid using replicas of Apple hardware products.** Hardware designs tend to change frequently and can make your interface icons and other content appear dated. If you must display Apple hardware, use only the images available in Apple Design Resources or the SF Symbols that represent various Apple products.

#### Standard icons

For icons to represent common actions in Menus, Toolbars, Buttons, and other places in interfaces across Apple platforms, you can use these SF Symbols.

#### Editing

| 
Action
 | 
Icon
 | 
Symbol name
 | 
| 
Cut
 | 

 | 
`scissors`
 | 
| 
Copy
 | 

 | 
`document.on.document`
 | 
| 
Paste
 | 

 | 
`document.on.clipboard`
 | 
| 
Done
 | 

 | 
`checkmark `
 | 
| 
Save
 | 

 | 

 | 
| 
Cancel
 | 

 | 
`xmark`
 | 
| 
Close
 | 

 | 

 | 
| 
Delete
 | 

 | 
`trash`
 | 
| 
Undo
 | 

 | 
`arrow.uturn.backward`
 | 
| 
Redo
 | 

 | 
`arrow.uturn.forward`
 | 
| 
Compose
 | 

 | 
`square.and.pencil`
 | 
| 
Duplicate
 | 

 | 
`plus.square.on.square`
 | 
| 
Rename
 | 

 | 
`pencil`
 | 
| 
Move to
 | 

 | 
`folder`
 | 
| 
Folder
 | 

 | 

 | 
| 
Attach
 | 

 | 
`paperclip`
 | 
| 
Add
 | 

 | 
`plus`
 | 
| 
More
 | 

 | 
`ellipsis`
 | 

#### Selection

| 
Action
 | 
Icon
 | 
Symbol name
 | 
| 
Select
 | 

 | 
`checkmark.circle`
 | 
| 
Deselect
 | 

 | 
`xmark`
 | 
| 
Close
 | 

 | 

 | 
| 
Delete
 | 

 | 
`trash`
 | 

#### Text formatting

| 
Action
 | 
Icon
 | 
Symbol name
 | 
| 
Superscript
 | 

 | 
`textformat.superscript`
 | 
| 
Subscript
 | 

 | 
`textformat.subscript`
 | 
| 
Bold
 | 

 | 
`bold`
 | 
| 
Italic
 | 

 | 
`italic`
 | 
| 
Underline
 | 

 | 
`underline`
 | 
| 
​​Align Left
 | 

 | 
`text.alignleft`
 | 
| 
Center
 | 

 | 
`text.aligncenter`
 | 
| 
Justified
 | 

 | 
`text.justify`
 | 
| 
Align Right
 | 

 | 
`text.alignright`
 | 

#### Search

| 
Action
 | 
Icon
 | 
Symbol name
 | 
| 
Search
 | 

 | 
`magnifyingglass`
 | 
| 
Find
 | 

 | 
`text.page.badge.magnifyingglass`
 | 
| 
Find and Replace
 | 

 | 

 | 
| 
Find Next
 | 

 | 

 | 
| 
Find Previous
 | 

 | 

 | 
| 
Use Selection for Find
 | 

 | 

 | 
| 
Filter
 | 

 | 
`line.3.horizontal.decrease`
 | 

#### Sharing and exporting

| 
Action
 | 
Icon
 | 
Symbol name
 | 
| 
Share
 | 

 | 
`square.and.arrow.up`
 | 
| 
Export
 | 

 | 

 | 
| 
Print
 | 

 | 
`printer`
 | 

#### Users and accounts

| 
Action
 | 
Icon
 | 
Symbol name
 | 
| 
Account
 | 

 | 
`person.crop.circle`
 | 
| 
User
 | 

 | 

 | 
| 
Profile
 | 

 | 

 | 

#### Ratings

| 
Action
 | 
Icon
 | 
Symbol name
 | 
| 
Dislike
 | 

 | 
`hand.thumbsdown`
 | 
| 
Like
 | 

 | 
`hand.thumbsup`
 | 

#### Layer ordering

| 
Action
 | 
Icon
 | 
Symbol name
 | 
| 
Bring to Front
 | 

 | 
`square.3.layers.3d.top.filled`
 | 
| 
Send to Back
 | 

 | 
`square.3.layers.3d.bottom.filled`
 | 
| 
Bring Forward
 | 

 | 
`square.2.layers.3d.top.filled`
 | 
| 
Send Backward
 | 

 | 
`square.2.layers.3d.bottom.filled`
 | 

#### Other

| 
Action
 | 
Icon
 | 
Symbol name
 | 
| 
Alarm
 | 

 | 
`alarm`
 | 
| 
Archive
 | 

 | 
`archivebox`
 | 
| 
Calendar
 | 

 | 
`calendar`
 | 

#### Platform considerations

*No additional considerations for iOS, iPadOS, tvOS, visionOS, or watchOS.*

#### macOS

##### Document icons

If your macOS app can use a custom document type, you can create a document icon to represent it. Traditionally, a document icon looks like a piece of paper with its top-right corner folded down. This distinctive appearance helps people distinguish documents from apps and other content, even when icon sizes are small.

If you don’t supply a document icon for a file type you support, macOS creates one for you by compositing your app icon and the file’s extension onto the canvas. For example, Preview uses a system-generated document icon to represent JPG files.

In some cases, it can make sense to create a set of document icons to represent a range of file types your app handles. For example, Xcode uses custom document icons to help people distinguish projects, AR objects, and Swift code files.

To create a custom document icon, you can supply any combination of background fill, center image, and text. The system layers, positions, and masks these elements as needed and composites them onto the familiar folded-corner icon shape.

Apple Design Resources provides a template you can use to create a custom background fill and center image for a document icon. As you use this template, follow the guidelines below.

**Design simple images that clearly communicate the document type.** Whether you use a background fill, a center image, or both, prefer uncomplicated shapes and a reduced palette of distinct colors. Your document icon can display as small as 16x16 px, so you want to create designs that remain recognizable at every size.

**Designing a single, expressive image for the background fill can be a great way to help people understand and recognize a document type.** For example, Xcode and TextEdit both use rich background images that don’t include a center image.

**Consider reducing complexity in the small versions of your document icon.** Icon details that are clear in large versions can look blurry and be hard to recognize in small versions. For example, to ensure that the grid lines in the custom heart document icon remain clear in intermediate sizes, you might use fewer lines and thicken them by aligning them to the reduced pixel grid. In the 16x16 px size, you might remove the lines altogether.

**Avoid placing important content in the top-right corner of your background fill.** The system automatically masks your image to fit the document icon shape and draws the white folded corner on top of the fill. Create a set of background images in the sizes listed below.

- 512x512 px @1x, 1024x1024 px @2x

- 256x256 px @1x, 512x512 px @2x

- 128x128 px @1x, 256x256 px @2x

- 32x32 px @1x, 64x64 px @2x

- 16x16 px @1x, 32x32 px @2x

**If a familiar object can convey a document’s type or its connection with your app, consider creating a center image that depicts it.** Design a simple, unambiguous image that’s clear and recognizable at every size. The center image measures half the size of the overall document icon canvas. For example, to create a center image for a 32x32 px document icon, use an image canvas that measures 16x16 px. You can provide center images in the following sizes:

- 256x256 px @1x, 512x512 px @2x

- 128x128 px @1x, 256x256 px @2x

- 32x32 px @1x, 64x64 px @2x

- 16x16 px @1x, 32x32 px @2x

**Define a margin that measures about 10% of the image canvas and keep most of the image within it.** Although parts of the image can extend into this margin for optical alignment, it’s best when the image occupies about 80% of the image canvas. For example, most of the center image in a 256x256 px canvas would fit in an area that measures 205x205 px.

**Specify a succinct term if it helps people understand your document type.** By default, the system displays a document’s extension at the bottom edge of the document icon, but if the extension is unfamiliar you can supply a more descriptive term. For example, the document icon for a SceneKit scene file uses the term *scene* instead of the file extension *scn*. The system automatically scales the extension text to fit in the document icon, so be sure to use a term that’s short enough to be legible at small sizes. By default, the system capitalizes every letter in the text.

#### Resources

##### Related

App icons

SF Symbols

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
June 9, 2025
 | 
Added a table of SF Symbols that represent common actions.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 

---

## HIG: SF Symbols

Source: https://developer.apple.com/design/human-interface-guidelines/sf-symbols

You can use a symbol to convey an object or concept wherever interface icons can appear, such as in toolbars, tab bars, context menus, and within text.

Availability of individual symbols and features varies based on the version of the system you’re targeting. Symbols and symbol features introduced in a given year aren’t available in earlier operating systems.

Visit SF Symbols to download the app and browse the full set of symbols. Be sure to understand the terms and conditions for using SF Symbols, including the prohibition against using symbols — or images that are confusingly similar — in app icons, logos, or any other trademarked use. For developer guidance, see Configuring and displaying symbol images in your UI.

#### Rendering modes

SF Symbols provides four rendering modes — monochrome, hierarchical, palette, and multicolor — that give you multiple options when applying color to symbols. For example, you might want to use multiple opacities of your app’s accent color to give symbols depth and emphasis, or specify a palette of contrasting colors to display symbols that coordinate with various color schemes.

To support the rendering modes, SF Symbols organizes a symbol’s paths into distinct layers. For example, the `cloud.sun.rain.fill` symbol consists of three layers: the primary layer contains the cloud paths, the secondary layer contains the paths that define the sun and its rays, and the tertiary layer contains the raindrop paths.

Depending on the rendering mode you choose, a symbol can produce various appearances. For example, Hierarchical rendering mode assigns a different opacity of a single color to each layer, creating a visual hierarchy that gives depth to the symbol.

To learn more about supporting rendering modes in custom symbols, see Custom symbols.

SF Symbols supports the following rendering modes.

**Monochrome** — Applies one color to all layers in a symbol. Within a symbol, paths render in the color you specify or as a transparent shape within a color-filled path.

**Hierarchical** — Applies one color to all layers in a symbol, varying the color’s opacity according to each layer’s hierarchical level.

**Palette** — Applies two or more colors to a symbol, using one color per layer. Specifying only two colors for a symbol that defines three levels of hierarchy means the secondary and tertiary layers use the same color.

**Multicolor** — Applies intrinsic colors to some symbols to enhance meaning. For example, the `leaf` symbol uses green to reflect the appearance of leaves in the physical world, whereas the `trash.slash` symbol uses red to signal data loss. Some multicolor symbols include layers that can receive other colors.

Regardless of rendering mode, using system-provided colors ensures that symbols automatically adapt to accessibility accommodations and appearance modes like vibrancy and Dark Mode. For developer guidance, see renderingMode(_:).

**Confirm that a symbol’s rendering mode works well in every context.** Depending on factors like the size of a symbol and its contrast with the current background color, different rendering modes can affect how well people can discern the symbol’s details. You can use the automatic setting to get a symbol’s preferred rendering mode, but it’s still a good idea to check the results for places where a different rendering mode might improve a symbol’s legibility.

#### Gradients

In SF Symbols 7 and later, gradient rendering generates a smooth linear gradient from a single source color. You can use gradients across all rendering modes for both system and custom colors and for custom symbols. Gradients render for symbols of any size, but look best at larger sizes.

#### Variable color

With variable color, you can represent a characteristic that can change over time — like capacity or strength — regardless of rendering mode. To visually communicate such a change, variable color applies color to different layers of a symbol as a value reaches different thresholds between zero and 100 percent.

For example, you could use variable color with the `speaker.wave.3` symbol to communicate three different ranges of sound — plus the state where there’s no sound — by mapping the layers that represent the curved wave paths to different ranges of decibel values. In the case of no sound, no wave layers get color. In all other cases, a wave layer receives color when the sound reaches a threshold the system defines based on the  number of nonzero states you want to represent.

Sometimes, it can make sense for some of a symbol’s layers to opt out of variable color. For example, in the `speaker.wave.3` symbol shown above, the layer that contains the speaker path doesn’t receive variable color because a speaker doesn’t change as the sound level changes. A symbol can support variable color in any number of layers.

**Use variable color to communicate change — don’t use it to communicate depth.** To convey depth and visual hierarchy, use Hierarchical rendering mode to elevate certain layers and distinguish foreground and background elements in a symbol.

#### Weights and scales

SF Symbols provides symbols in a wide range of weights and scales to help you create adaptable designs.

Each of the nine symbol weights — from ultralight to black — corresponds to a weight of the San Francisco system font, helping you achieve precise weight matching between symbols and adjacent text, while supporting flexibility for different sizes and contexts.

Each symbol is also available in three scales: small, medium (the default), and large. The scales are defined relative to the cap height of the San Francisco system font.

Specifying a scale lets you adjust a symbol’s emphasis compared to adjacent text, without disrupting the weight matching with text that uses the same point size. For developer guidance, see imageScale(_:) (SwiftUI), UIImage.SymbolScale (UIKit), and NSImage.SymbolConfiguration (AppKit).

#### Design variants

SF Symbols defines several design variants — such as fill, slash, and enclosed — that can help you communicate precise states and actions while maintaining visual consistency and simplicity in your UI. For example, you could use the slash variant of a symbol to show that an item or action is unavailable, or use the fill variant to indicate selection.

Outline is the most common variant in SF Symbols. An outlined symbol has no solid areas, resembling the appearance of text. Most symbols are also available in a fill variant, in which the areas within some shapes are solid.

In addition to outline and fill, SF Symbols also defines variants that include a slash or enclose a symbol within a shape like a circle, square, or rectangle. In many cases, enclosed and slash variants can combine with outline or fill variants.

SF Symbols provides many variants for specific languages and writing systems, including Latin, Arabic, Hebrew, Hindi, Thai, Chinese, Japanese, Korean, Cyrillic, Devanagari, and several Indic numeral systems. Language- and script-specific variants adapt automatically when the device language changes. For guidance, see Images.

Symbol variants support a range of design goals. For example:

- The outline variant works well in toolbars, lists, and other places where you display a symbol alongside text.

- Symbols that use an enclosing shape — like a square or circle — can improve legibility at small sizes.

- The solid areas in a fill variant tend to give a symbol more visual emphasis, making it a good choice for iOS tab bars and swipe actions and places where you use an accent color to communicate selection.

In many cases, the view that displays a symbol determines whether to use outline or fill, so you don’t have to specify a variant. For example, an iOS tab bar prefers the fill variant, whereas a toolbar takes the outline variant.

#### Animations

SF Symbols provides a collection of expressive, configurable animations that enhance your interface and add vitality to your app. Symbol animations help communicate ideas, provide feedback in response to people’s actions, and signal changes in status or ongoing activities.

Animations work on all SF Symbols in the library, in all rendering modes, weights, and scales, and on custom symbols. For considerations when animating custom symbols, see Custom symbols. You can control the playback of an animation, whether you want the animation to run from start to finish, or run indefinitely, repeating its effect until a condition is met. You can customize behaviors, like changing the playback speed of an animation or determining whether to reverse an animation before repeating it. For developer guidance, see Symbols and SymbolEffect.

**Appear** — Causes a symbol to gradually emerge into view.

**Disappear** — Causes a symbol to gradually recede out of view.

**Bounce** — Briefly scales a symbol with an elastic-like movement that goes either up or down and then returns to the symbol’s initial state. The bounce animation plays once by default and can help communicate that an action occurred or needs to take place.

**Scale** — Changes the size of a symbol, increasing or decreasing its scale. Unlike the bounce animation, which returns the symbol to its original state, the scale animation persists until you set a new scale or remove the effect. You might use the scale animation to draw people’s attention to a selected item or as feedback when people choose a symbol.

**Pulse** — Varies the opacity of a symbol over time. This animation automatically pulses only the layers within a symbol that are annotated to pulse, and optionally can pulse all layers within a symbol. You might use the pulse animation to communicate ongoing activity, playing it continuously until a condition is met.

**Variable color** — Incrementally varies the opacity of layers within a symbol. This animation can be cumulative or iterative. When cumulative, color changes persist for each layer until the animation cycle is complete. When iterative, color changes occur one layer at a time. You might use variable color to communicate progress or ongoing activity, such as playback, connecting, or broadcasting. You can customize the animation to autoreverse — meaning reverse the animation to the starting point and replay the sequence — as well as hide inactive layers rather than reduce their opacity.

The arrangement of layers within a symbol determines how variable color behaves during a repeating animation. Symbols with layers that are arranged linearly where the start and end points don’t meet are annotated as *open loop*. Symbols with layers that follow a complete shape where the start and end points do meet, like in a circular progress indicator, are annotated as *closed loop*. Variable color animations for symbols with closed loop designs feature seamless, continuous playback.

**Replace** — Replaces one symbol with another. The replace animation works between arbitrary symbols and across all weights and rendering modes. This animation features three configurations:

- Down-up, where the outgoing symbol scales down and the incoming symbol scales up, communicating a change in state.

- Up-up, where both the outgoing and incoming symbols scale up. This configuration communicates a change in state that includes a sense of forward progression.

- Off-up, where the outgoing symbol hides immediately and the incoming symbol scales up. This configuration communicates a state change that emphasizes the next available state or action.

**Magic Replace** — Performs a smart transition between two symbols with related shapes. For example, slashes can draw on and off, and badges can appear or disappear, or you can replace them independently of the base symbol. Magic Replace is the new default replace animation, but doesn’t occur between unrelated symbols; the default down-up animation occurs instead. You can choose a custom direction for the fallback animation in these situations if you prefer one other than the default.

**Wiggle** — Moves the symbol back and forth along a directional axis. You might use the wiggle animation to highlight a change or a call to action that a person might overlook. Wiggle can also add a dynamic emphasis to an interaction or reinforce what the symbol is representing, such as when an arrow points in a specific direction.

**Breathe** — Smoothly increases and decreases the presence of a symbol, giving it a living quality. You might use the breathe animation to convey status changes, or signal that an activity is taking place, like an ongoing recording session. Breathe is similar to pulse; however pulse animates by changing opacity alone, while breathe changes both opacity and size to convey ongoing activity.

**Rotate** — Rotates the symbol to act as a visual indicator or imitate an object’s behavior in the real world. For example, when a task is in progress, rotation confirms that it’s working as expected. The rotate animation causes some symbols to rotate entirely, while in others only certain parts of the symbol rotate. Symbols like the desk fan, for example, use the By Layer rotation option to spin only the fan blades.

**Draw On / Draw Off** — In SF Symbols 7 and later, draws the symbol along a path through a set of guide points, either from offscreen to onscreen (Draw On) or from onscreen to offscreen (Draw Off). You can draw all layers at once, stagger them, or draw each layer one at a time. You might use the draw animation to convey progress, as with a download, or to reinforce the meaning of a symbol, like a directional arrow.

**Apply symbol animations judiciously.** While there’s no limit to how many animations you can add to a view, too many animations can overwhelm an interface and distract people.

**Make sure that animations serve a clear purpose in communicating a symbol’s intent.** Each type of animation has a discrete movement that communicates a certain type of action or elicits a certain response. Consider how people might interpret an animated symbol and whether the animation, or combination of animations, might be confusing.

**Use symbol animations to communicate information more efficiently.** Animations provide visual feedback, reinforcing that something happened in your interface. You can use animations to present complex information in a simple way and without taking up a lot of visual space.

**Consider your app’s tone when adding animations.** When animating a symbol, think about what the animation can convey and how that might align with your brand identity and your app’s overall style and tone. For guidance, see Branding.

#### Custom symbols

If you need a symbol that SF Symbols doesn’t provide, you can create your own. To create a custom symbol, first export the template for a symbol that’s similar to the design you want, then use a vector-editing tool to modify it. For developer guidance, see Creating custom symbol images for your app.

> 
SF Symbols includes copyrighted symbols that depict Apple products and features. You can display these symbols in your app, but you can’t customize them. To help you identify a noncustomizable symbol, the SF Symbols app badges it with an Info icon; to help you use the symbol correctly, the inspector pane describes its usage restrictions.

Using a process called *annotating*, you can assign a specific color — or a specific hierarchical level, such as primary, secondary, or tertiary — to each layer in a custom symbol. Depending on the rendering modes you support, you can use a different mode in each instance of the symbol in your app.

**Use the template as a guide.** Create a custom symbol that’s consistent with the ones the system provides in level of detail, optical weight, alignment, position, and perspective. Strive to design a symbol that is:

- Simple

- Recognizable

- Inclusive

- Directly related to the action or content it represents

For guidance, see Icons.

**Assign negative side margins to your custom symbol if necessary.** SF Symbols supports negative side margins to aid optical horizontal alignment when a symbol contains a badge or other elements that increase its width. For example, negative side margins can help you horizontally align a stack of folder symbols, some of which include a badge. The name of each margin includes the relevant configuration  — such as “left-margin-Regular-M” — so be sure to use this naming pattern if you add margins to your custom symbols.

**Optimize layers to use animations with custom symbols.** If you want to animate your symbol by layer, make sure to annotate the layers in the SF Symbols app. The Z-order determines the order that you want to apply colors to the layers of a variable color symbol, and you can choose whether to animate those changes from front-to-back, or back-to-front. You can also animate by layer groups to have related layers move together.

**Test animations for custom symbols.** It’s important to test your custom symbols with all of the animation presets because the shapes and paths might not appear how you expect when the layers are in motion. To get the most out of this feature, consider drawing your custom symbols with whole shapes. For example, a custom symbol similar to the `person.2.fill` symbol doesn’t need to create a cutout for the shape representing the person on the left. Instead, you can draw the full shape of the person, and in addition to that, draw an offset path of the person on the right to help represent the gap between them. You can later annotate this offset path as an erase layer to render the symbol as you want. This method of drawing helps preserve additional layer information that allows for animations to perform as you expect.

**Avoid making custom symbols that include common variants, such as enclosures or badges.** The SF Symbols app offers a component library for creating variants of your custom symbol. Using the component library allows you to create commonly used variants of your custom symbol while maintaining design consistency with the included SF Symbols.

**Provide alternative text labels for custom symbols.** Alternative text labels — or accessibility descriptions — let VoiceOver describe visible UI and content, making navigation easier for people with visual disabilities. For guidance, see VoiceOver.

**Don’t design replicas of Apple products.** Apple products are copyrighted and you can’t reproduce them in your custom symbols. Also, you can’t customize a symbol that SF Symbols identifies as representing an Apple feature or product.

#### Platform considerations

*No additional considerations for iOS, iPadOS, macOS, tvOS, visionOS, or watchOS.*

#### Resources

##### Related

SF Symbols

Typography

Icons

##### Developer documentation

Symbols — Symbols framework

Configuring and displaying symbol images in your UI — UIKit

Creating custom symbol images for your app — UIKit

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
July 28, 2025
 | 
Updated with guidance for Draw animations and gradient rendering in SF Symbols 7.
 | 
| 
June 10, 2024
 | 
Updated with guidance for new animations and features of SF Symbols 6.
 | 
| 
June 5, 2023
 | 
Added a new section on animations. Included animation guidance for custom symbols.
 | 
| 
September 14, 2022
 | 
Added a new section on variable color. Removed instructions on creating custom symbol paths, exporting templates, and layering paths, deferring to developer articles that cover these topics.
 | 

---

## HIG: Accessibility

Source: https://developer.apple.com/design/human-interface-guidelines/accessibility

When you design for accessibility, you reach a larger audience and create a more inclusive experience. An accessible interface allows people to experience your app or game regardless of their capabilities or how they use their devices. Accessibility makes information and interactions available to everyone. An accessible interface is:

- **Intuitive.** Your interface uses familiar and consistent interactions that make tasks straightforward to perform.

- **Perceivable.** Your interface doesn’t rely on any single method to convey information. People can access and interact with your content, whether they use sight, hearing, speech, or touch.

- **Adaptable.** Your interface adapts to how people want to use their device, whether by supporting system accessibility features or letting people personalize settings.

As you design your app, audit the accessibility of your interface. Use Accessibility Inspector to highlight accessibility issues with your interface and to understand how your app represents itself to people using system accessibility features. You can also communicate how accessible your app is on the App Store using Accessibility Nutrition Labels. To learn more about how to evaluate and indicate accessibility feature support, see Accessibility Nutrition Labels in App Store Connect help.

#### Vision

The people who use your interface may be blind, color blind, or have low vision or light sensitivity. They may also be in situations where lighting conditions and screen brightness affect their ability to interact with your interface.

**Support larger text sizes.** Make sure people can adjust the size of your text or icons to make them more legible, visible, and comfortable to read. Ideally, give people the option to enlarge text by at least 200 percent (or 140 percent in watchOS apps). Your interface can support font size enlargement either through custom UI, or by adopting Dynamic Type. Dynamic Type is a systemwide setting that lets people adjust the size of text for comfort and legibility. For more guidance, see Supporting Dynamic Type.

**Use recommended defaults for custom type sizes.** Each platform has different default and minimum sizes for system-defined type styles to promote readability. If you’re using custom type styles, follow the recommended defaults.

| 
Platform
 | 
Default size
 | 
Minimum size
 | 
| 
iOS, iPadOS
 | 
17 pt
 | 
11 pt
 | 
| 
macOS
 | 
13 pt
 | 
10 pt
 | 
| 
tvOS
 | 
29 pt
 | 
23 pt
 | 
| 
visionOS
 | 
17 pt
 | 
12 pt
 | 
| 
watchOS
 | 
16 pt
 | 
12 pt
 | 

**Bear in mind that font weight can also impact how easy text is to read.** If you’re using a custom font with a thin weight, aim for larger than the recommended sizes to increase legibility. For more guidance, see Typography.

**Strive to meet color contrast minimum standards.** To ensure all information in your app is legible, it’s important that there’s enough contrast between foreground text and icons and background colors. Two popular standards of measure for color contrast are the Web Content Accessibility Guidelines (WCAG) and the Accessible Perceptual Contrast Algorithm (APCA). Use standard contrast calculators to ensure your UI meets acceptable levels. Accessibility Inspector uses the following values from WCAG Level AA as guidance in determining whether your app’s colors have an acceptable contrast.

| 
Text size
 | 
Text weight
 | 
Minimum contrast ratio
 | 
| 
Up to 17 pts
 | 
All
 | 
4.5:1
 | 
| 
18 pts
 | 
All
 | 
3:1
 | 
| 
All
 | 
Bold
 | 
3:1
 | 

If your app doesn’t provide this minimum contrast by default, ensure it at least provides a higher contrast color scheme when the system setting Increase Contrast is turned on. If your app supports Dark Mode, make sure to check the minimum contrast in both light and dark appearances.

**Prefer system-defined colors.** These colors have their own accessible variants that automatically adapt when people adjust their color preferences, such as enabling Increase Contrast or toggling between the light and dark appearances. For guidance, see Color.

**Convey information with more than color alone.** Some people have trouble differentiating between certain colors and shades. For example, people who are color blind may have particular difficulty with pairings such as red-green and blue-orange. Offer visual indicators, like distinct shapes or icons, in addition to color to help people perceive differences in function and changes in state. Consider allowing people to customize color schemes such as chart colors or game characters so they can personalize your interface in a way that’s comfortable for them.

**Describe your app’s interface and content for VoiceOver.** VoiceOver is a screen reader that lets people experience your app’s interface without needing to see the screen. For more guidance, see VoiceOver.

#### Hearing

The people who use your interface may be deaf or hard of hearing. They may also be in noisy or public environments.

**Support text-based ways to enjoy audio and video.** It’s important that dialogue and crucial information about your app or game isn’t communicated through audio alone. Depending on the context, give people different text-based ways to experience their media, and allow people to customize the visual presentation of that text:

- **Captions** give people the textual equivalent of audible information in video or audio-only content. Captions are great for scenarios like game cutscenes and video clips where text synchronizes live with the media.

- **Subtitles** allow people to read live onscreen dialogue in their preferred language. Subtitles are great for TV shows and movies.

- **Audio descriptions** are interspersed between natural pauses in the main audio of a video and supply spoken narration of important information that’s presented only visually.

- **Transcripts** provide a complete textual description of a video, covering both audible and visual information. Transcripts are great for longer-form media like podcasts and audiobooks where people may want to review content as a whole or highlight the transcript as media is playing.

For developer guidance, see Selecting subtitles and alternative audio tracks.

**Use haptics in addition to audio cues.** If your interface conveys information through audio cues — such as a success chime, error sound, or game feedback — consider pairing that sound with matching haptics for people who can’t perceive the audio or have their audio turned off. In iOS and iPadOS, you can also use Music Haptics and Audio graphs to let people experience music and infographics through vibration and texture. For guidance, see Playing haptics.

**Augment audio cues with visual cues.** This is especially important for games and spatial apps where important content might be taking place off screen. When using audio to guide people towards a specific action, also add in visual indicators that point to where you want people to interact.

#### Mobility

Ensure your interface offers a comfortable experience for people with limited dexterity or mobility.

**Offer sufficiently sized controls.** Controls that are too small are hard for many people to interact with and select. Strive to meet the recommended minimum control size for each platform to ensure controls and menus are comfortable for all when tapping and clicking.

| 
Platform
 | 
Default control size
 | 
Minimum control size
 | 
| 
iOS, iPadOS
 | 
44x44 pt
 | 
28x28 pt
 | 
| 
macOS
 | 
28x28 pt
 | 
20x20 pt
 | 
| 
tvOS
 | 
66x66 pt
 | 
56x56 pt
 | 
| 
visionOS
 | 
60x60 pt
 | 
28x28 pt
 | 
| 
watchOS
 | 
44x44 pt
 | 
28x28 pt
 | 

**Consider spacing between controls as important as size.** Include enough padding between elements to reduce the chance that someone taps the wrong control. In general, it works well to add about 12 points of padding around elements that include a bezel. For elements without a bezel, about 24 points of padding works well around the element’s visible edges.

**Support simple gestures for common interactions.** For many people, with or without disabilities, complex gestures can be challenging. For interactions people do frequently in your app or game, use the simplest gesture possible — avoid custom multifinger and multihand gestures — so repetitive actions are both comfortable and easy to remember.

**Offer alternatives to gestures.** Make sure your UI’s core functionality is accessible through more than one type of physical interaction. Gestures can be less comfortable for people who have limited dexterity, so offer onscreen ways to achieve the same outcome. For example, if you use a swipe gesture to dismiss a view, also make a button available so people can tap or use an assistive device.

**Let people use Voice Control to give guidance and enter information verbally.** With Voice Control, people can interact with their devices entirely by speaking commands. They can perform gestures, interact with screen elements, dictate and edit text, and more. To ensure a smooth experience, label interface elements appropriately. For developer guidance, see Voice Control.

**Integrate with Siri and Shortcuts to let people perform tasks using voice alone.** When your app supports Siri and Shortcuts, people can automate the important and repetitive tasks they perform regularly. They can initiate these tasks from Siri, the Action button on their iPhone or Apple Watch, and shortcuts on their Home Screen or in Control Center. For guidance, see Siri.

**Support mobility-related assistive technologies.** Features like VoiceOver, AssistiveTouch, Full Keyboard Access, Pointer Control, and Switch Control offer alternative ways for people with low mobility to interact with their devices. Conduct testing and verify that your app or game supports these technologies, and that your interface elements are appropriately labeled to ensure a great experience. For more information, see Performing accessibility testing for your app.

#### Speech

Apple’s accessibility features help people with speech disabilities and people who prefer text-based interactions to communicate effectively using their devices.

**Let people use the keyboard alone to navigate and interact with your app.** People can turn on Full Keyboard Access to navigate apps using their physical keyboard. The system also defines accessibility keyboard shortcuts and a wide range of other keyboard shortcuts that many people use all the time. Avoid overriding system-defined keyboard shortcuts and evaluate your app to ensure it works well with Full Keyboard Access. For additional guidance, see Keyboards. For developer guidance, see Support Full Keyboard Access in your iOS app.

**Support Switch Control.** Switch Control is an assistive technology that lets people control their devices through separate hardware, game controllers, or sounds such as a click or a pop. People can perform actions like selecting, tapping, typing, and drawing when your app or game supports the ability to navigate using Switch Control. For developer guidance, see Switch Control.

#### Cognitive

When you minimize complexity in your app or game, all people benefit.

**Keep actions simple and intuitive.** Ensure that people can navigate your interface using easy-to-remember and consistent interactions. Prefer system gestures and behaviors people are already familiar with over creating custom gestures people must learn and retain.

**Minimize use of time-boxed interface elements.** Views and controls that auto-dismiss on a timer can be problematic for people who need longer to process information, and for people who use assistive technologies that require more time to traverse the interface. Prefer dismissing views with an explicit action.

**Consider offering difficulty accommodations in games.** Everyone has their own way of playing and enjoying games. To support a variety of cognitive abilities, consider adding the ability to customize the difficulty level of your game, such as offering options for people to reduce the criteria for successfully completing a level, adjust reaction time, or enable control assistance.

**Let people control audio and video playback.** Avoid autoplaying audio and video content without also providing controls to start and stop it. Make sure these controls are discoverable and easy to act upon, and consider global settings that let people opt out of auto-playing all audio and video. For developer guidance, see Animated images and isVideoAutoplayEnabled.

**Allow people to opt out of flashing lights in video playback.** People might want to avoid bright, frequent flashes of light in the media they consume. A Dim Flashing Lights setting allows the system to calculate, mitigate, and inform people about flashing lights in a piece of media. If your app supports video playback, ensure that it responds appropriately to the Dim Flashing Lights setting. For developer guidance, see Flashing lights.

**Be cautious with fast-moving and blinking animations.** When you use these effects in excess, it can be distracting, cause dizziness, and in some cases even result in epileptic episodes. People who are prone to these effects can turn on the Reduce Motion accessibility setting. When this setting is active, ensure your app or game responds by reducing automatic and repetitive animations, including zooming, scaling, and peripheral motion. Other best practices for reducing motion include:

- Tightening animation springs to reduce bounce effects

- Tracking animations directly with people’s gestures

- Avoiding animating depth changes in z-axis layers

- Replacing transitions in x-, y-, and z-axes with fades to avoid motion

- Avoiding animating into and out of blurs

**Optimize your app’s UI for Assistive Access.** Assistive Access is an accessibility feature in iOS and iPadOS that allows people with cognitive disabilities to use a streamlined version of your app. Assistive Access sets a default layout and control presentation for apps that reduces cognitive load, such as the following layout of the Camera app.

To optimize your app for this mode, use the following guidelines when Assistive Access is turned on:

- Identify the core functionality of your app and consider removing noncritical workflows and UI elements.

- Break up multistep workflows so people can focus on a single interaction per screen.

- Always ask for confirmation twice whenever people perform an action that’s difficult to recover from, such a deleting a file.

For developer guidance, see Assistive Access.

#### Platform considerations

*No additional considerations for iOS, iPadOS, macOS, tvOS, or watchOS.*

#### visionOS

visionOS offers a variety of accessibility features people can use to interact with their surroundings in ways that are comfortable and work best for them, including head and hand Pointer Control, and a Zoom feature.

**Prioritize comfort.** The immersive nature of visionOS means that interfaces, animations, and interactions have a greater chance of causing motion sickness, and visual and ergonomic discomfort for people. To ensure the most comfortable experience, consider these tips:

- Keep interface elements within a person’s field of view. Prefer horizontal layouts to vertical ones that might cause neck strain, and avoid demanding the viewer’s attention in different locations in quick succession.

- Reduce the speed and intensity of animated objects, particularly in someone’s peripheral vision.

- Be gentle with camera and video motion, and avoid situations where someone may feel like the world around them is moving without their control.

- Avoid anchoring content to the wearer’s head, which may make them feel stuck and confined, and also prevent them from using assistive technologies like Pointer Control.

- Minimize the need for large and repetitive gestures, as these can become tiresome and may be difficult depending on a person’s surroundings.

For additional guidance, see Create accessible spatial experiences and Design considerations for vision and motion.

#### Resources

##### Related

Inclusion

Typography

VoiceOver

##### Developer documentation

Building accessible apps

Accessibility

Overview of Accessibility Nutrition Labels

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
June 9, 2025
 | 
Added guidance and links for Assistive Access, Switch Control, and Accessibility Nutrition Labels.
 | 
| 
March 7, 2025
 | 
Expanded and refined all guidance. Moved Dynamic Type guidance to the Typography page, and moved VoiceOver guidance to a new VoiceOver page.
 | 
| 
June 10, 2024
 | 
Added a link to Apple’s Unity plug-ins for supporting Dynamic Type.
 | 
| 
December 5, 2023
 | 
Updated visionOS Zoom lens artwork.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 

---

## HIG: Motion

Source: https://developer.apple.com/design/human-interface-guidelines/motion

Many system components automatically include motion, letting you offer familiar and consistent experiences throughout your app or game. System components might also adjust their motion in response to factors like accessibility settings or different input methods. For example, the movement of Liquid Glass responds to direct touch interaction with greater emphasis to reinforce the feeling of a tactile experience, but produces a more subdued effect when a person interacts using a trackpad.

If you design custom motion, follow the guidelines below.

#### Best practices

**Add motion purposefully, supporting the experience without overshadowing it.** Don’t add motion for the sake of adding motion. Gratuitous or excessive animation can distract people and may make them feel disconnected or physically uncomfortable.

**Make motion optional.** Not everyone can or wants to experience the motion in your app or game, so it’s essential to avoid using it as the only way to communicate important information. To help everyone enjoy your app or game, supplement visual feedback by also using alternatives like haptics and audio to communicate.

#### Providing feedback

**Strive for realistic feedback motion that follows people’s gestures and expectations.** In nongame apps, accurate, realistic motion can help people understand how something works, but feedback motion that doesn’t make sense can make them feel disoriented. For example, if someone reveals a view by sliding it down from the top, they don’t expect to dismiss the view by sliding it to the side.

**Aim for brevity and precision in feedback animations.** When animated feedback is brief and precise, it tends to feel lightweight and unobtrusive, and it can often convey information more effectively than prominent animation. For example, when a game displays a succinct animation that’s precisely tied to a successful action, players can instantly get the message without being distracted from their gameplay. Another example is in visionOS: When people tap a panorama in Photos, it quickly and smoothly expands to fill the space in front of them, helping them track the transition without making them wait to enjoy the content.

**In apps, generally avoid adding motion to UI interactions that occur frequently.** The system already provides subtle animations for interactions with standard interface elements. For a custom element, you generally want to avoid making people spend extra time paying attention to unnecessary motion every time they interact with it.

**Let people cancel motion.** As much as possible, don’t make people wait for an animation to complete before they can do anything, especially if they have to experience the animation more than once.

**Consider using animated symbols where it makes sense.** When you use SF Symbols 5 or later, you can apply animations to SF Symbols or custom symbols. For guidance, see Animations.

#### Leveraging platform capabilities

**Make sure your game’s motion looks great by default on each platform you support.** In most games, maintaining a consistent frame rate of 30 to 60 fps typically results in a smooth, visually appealing experience. For each platform you support, use the device’s graphics capabilities to enable default settings that let people enjoy your game without first having to change those settings.

**Let people customize the visual experience of your game to optimize performance or battery life.** For example, consider letting people switch between power modes when the system detects the presence of an external power source.

#### Platform considerations

*No additional considerations for iOS, iPadOS, macOS, or tvOS.*

#### visionOS

In addition to subtly communicating context, drawing attention to information, and enriching immersive experiences, motion in visionOS can combine with Depth to provide essential feedback when people look at interactive elements. Because motion is likely to be a large part of your visionOS experience, it’s crucial to avoid causing distraction, confusion, or discomfort.

**As much as possible, avoid displaying motion at the edges of a person’s field of view.** People can be particularly sensitive to motion that occurs in their peripheral vision: in addition to being distracting, such motion can even cause discomfort because it can make people feel like they or their surroundings are moving. If you need to show an object moving in the periphery during an immersive experience, make sure the object’s brightness level is similar to the rest of the visible content.

**Help people remain comfortable when showing the movement of large virtual objects.** If an object is large enough to fill a lot of the Field of view, occluding most or all of Immersion and passthrough, people can naturally perceive it as being part of their surroundings. To help people perceive the object’s movement without making them think that they or their surroundings are moving, you can increase the object’s translucency, helping people see through it, or lower its contrast to make its motion less noticeable.

> 
People can experience discomfort even when they’re the ones moving a large virtual object, such as a window. Although adjusting translucency and contrast can help in this scenario, consider also keeping a window’s size fairly small.

**Consider using fades when you need to relocate an object.** When an object moves from one location to another, people naturally watch the movement. If such movement doesn’t communicate anything useful to people, you can fade the object out before moving it and fade it back in after it’s in the new location.

**In general, avoid letting people rotate a virtual world.** When a virtual world rotates, the experience typically upsets people’s sense of stability, even when they control the rotation and the movement is subtle. Instead, consider using instantaneous directional changes during a quick fade-out.

**Consider giving people a stationary frame of reference.** It can be easier for people to handle visual movement when it’s contained within an area that doesn’t move. In contrast, if the entire surrounding area appears to move — for example, in a game that automatically moves a player through space — people can feel unwell.

**Avoid showing objects that oscillate in a sustained way.** In particular, you want to avoid showing an oscillation that has a frequency of around 0.2 Hz because people can be very sensitive to this frequency. If you need to show objects oscillating, aim to keep the amplitude low and consider making the content translucent.

#### watchOS

SwiftUI provides a powerful and streamlined way to add motion to your app. If you need to use WatchKit to animate layout and appearance changes — or create animated image sequences — see WKInterfaceImage.

> 
All layout- and appearance-based animations automatically include built-in easing that plays at the start and end of the animation. You can’t turn off or customize easing.

#### Resources

##### Related

Feedback

Accessibility

Spatial layout

Immersive experiences

##### Developer documentation

Animating views and transitions — SwiftUI

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
September 9, 2025
 | 
Added guidance for Liquid Glass.
 | 
| 
June 10, 2024
 | 
Added game-specific examples and enhanced guidance for using motion in games.
 | 
| 
February 2, 2024
 | 
Enhanced guidance for minimizing peripheral motion in visionOS apps.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 

---

## HIG: Buttons

Source: https://developer.apple.com/design/human-interface-guidelines/buttons

Versatile and highly customizable, buttons give people simple, familiar ways to do tasks in your app. In general, a button combines three attributes to clearly communicate its function:

- **Style.** A visual style based on size, color, and shape.

- **Content.** A symbol (or icon), text label, or both that a button displays to convey its purpose.

- **Role.** A system-defined role that identifies a button’s semantic meaning and can affect its appearance.

There are also many button-like components that have distinct appearances and behaviors for specific use cases, like Toggles, Pop-up buttons, and Segmented controls.

#### Best practices

When buttons are instantly recognizable and easy to understand, an app tends to feel intuitive and well designed.

**Make buttons easy for people to use.** It’s essential to include enough space around a button so that people can visually distinguish it from surrounding components and content. Giving a button enough space is also critical for helping people select or activate it, regardless of the method of input they use. As a general rule, a button needs a hit region of at least 44x44 pt — in visionOS, 60x60 pt — to ensure that people can select it easily, whether they use a fingertip, a pointer, their eyes, or a remote.

**Always include a press state for a custom button.** Without a press state, a button can feel unresponsive, making people wonder if it’s accepting their input.

#### Style

System buttons offer a range of styles that support customization while providing built-in interaction states, accessibility support, and appearance adaptation. Different platforms define different styles that help you communicate hierarchies of actions in your app.

**In general, use a button that has a prominent visual style for the most likely action in a view.** To draw people’s attention to a specific button, use a prominent button style so the system can apply an accent color to the button’s background. Buttons that use color tend to be the most visually distinctive, helping people quickly identify the actions they’re most likely to use. Keep the number of prominent buttons to one or two per view. Presenting too many prominent buttons increases cognitive load, requiring people to spend more time considering options before making a choice.

**Use style — not size — to visually distinguish the preferred choice among multiple options.** When you use buttons of the same size to offer two or more options, you signal that the options form a coherent set of choices. By contrast, placing two buttons of different sizes near each other can make the interface look confusing and inconsistent. If you want to highlight the preferred or most likely option in a set, use a more prominent button style for that option and a less prominent style for the remaining ones.

**Avoid applying a similar color to button labels and content layer backgrounds.** If your app already has bright, colorful content in the content layer, prefer using the default monochromatic appearance of button labels. For more guidance, see Liquid Glass color.

#### Content

**Ensure that each button clearly communicates its purpose.** Depending on the platform, a button can contain a symbol (or icon), a text label, or both to help people understand what it does.

> 
In macOS and visionOS, the system displays a tooltip after people hover over a button for a moment. A tooltip displays a brief phrase that explains what a button does; for guidance, see Offering help.

**Try to associate familiar actions with familiar icons.** For example, people can predict that a button containing the `square.and.arrow.up` symbol will help them perform share-related activities. If it makes sense to use an icon in your button, consider using an existing or customized SF Symbols. For a list of symbols that represent common actions, see Standard icons.

**Consider using text when a short label communicates more clearly than an icon.** To use text, write a few words that succinctly describe what the button does. Using title-style capitalization, consider starting the label with a verb to help convey the button’s action — for example, a button that lets people add items to their shopping cart might use the label “Add to Cart.”

#### Role

A system button can have one of the following roles:

- **Normal.** No specific meaning.

- **Primary.** The button is the default button — the button people are most likely to choose.

- **Cancel.** The button cancels the current action.

- **Destructive.** The button performs an action that can result in data destruction.

A button’s role can have additional effects on its appearance. For example, a primary button uses an app’s accent color, whereas a destructive button uses the system red color.

**Assign the primary role to the button people are most likely to choose.** When a primary button responds to the Return key, it makes it easy for people to quickly confirm their choice. In addition, when the button is in a temporary view — like a Sheets, an editable view, or an Alerts — assigning it the primary role means that the view can automatically close when people press Return.

**Don’t assign the primary role to a button that performs a destructive action, even if that action is the most likely choice.** Because of its visual prominence, people sometimes choose a primary button without reading it first. Help people avoid losing content by assigning the primary role to nondestructive buttons.

#### Platform considerations

*No additional considerations for tvOS.*

#### iOS, iPadOS

**Configure a button to display an activity indicator when you need to provide feedback about an action that doesn’t instantly complete.** Displaying an activity indicator within a button can save space in your user interface while clearly communicating the reason for the delay. To help clarify what’s happening, you can also configure the button to display a different label alongside the activity indicator. For example, the label “Checkout” could change to “Checking out…” while the activity indicator is visible. When a delay occurs after people click or tap your configured button, the system displays the activity indicator next to the original or alternative label, hiding the button image, if there is one.

#### macOS

Several specific button types are unique to macOS.

##### Push buttons

The standard button type in macOS is known as a *push button*. You can configure a push button to display text, a symbol, an icon, or an image, or a combination of text and image content. Push buttons can act as the default button in a view and you can tint them.

**Use a flexible-height push button only when you need to display tall or variable height content.** Flexible-height buttons support the same configurations as regular push buttons — and they use the same corner radius and content padding — so they look consistent with other buttons in your interface. If you need to present a button that contains two lines of text or a tall icon, use a flexible-height button; otherwise, use a standard push button. For developer guidance, see NSButton.BezelStyle.flexiblePush.

**Append a trailing ellipsis to the title when a push button opens another window, view, or app.** Throughout the system, an ellipsis in a control title signals that people can provide additional input. For example, the Edit buttons in the AutoFill pane of Safari Settings include ellipses because they open other views that let people modify autofill values.

**Consider supporting spring loading.** On systems with a Magic Trackpad, *spring loading* lets people activate a button by dragging selected items over it and force clicking — that is, pressing harder — without dropping the selected items. After force clicking, people can continue dragging the items, possibly to perform additional actions.

##### Square buttons

A *square button* (also known as a *gradient button*) initiates an action related to a view, like adding or removing rows in a table.

Square buttons contain symbols or icons — not text — and you can configure them to behave like push buttons, toggles, or pop-up buttons. The buttons appear in close proximity to their associated view — usually within or beneath it — so people know which view the buttons affect.

**Use square buttons in a view, not in the window frame.** Square buttons aren’t intended for use in toolbars or status bars. If you need a button in a toolbar, use a toolbar item.

**Prefer using a symbol in a square button.** SF Symbols provides a wide range of symbols that automatically receive appropriate coloring in their default state and in response to user interaction.

**Avoid using labels to introduce square buttons.** Because square buttons are closely connected with a specific view, their purpose is generally clear without the need for descriptive text.

For developer guidance, see NSButton.BezelStyle.smallSquare.

##### Help buttons

A *help button* appears within a view and opens app-specific help documentation.

Help buttons are circular, consistently sized buttons that contain a question mark. For guidance on creating help documentation, see Offering help.

**Use the system-provided help button to display your help documentation.** People are familiar with the appearance of the standard help button and know that choosing it opens help content.

**When possible, open the help topic that’s related to the current context.** For example, the help button in the Rules pane of Mail settings opens the Mail User Guide to a help topic that explains how to change these settings. If no specific help topic applies directly to the current context, open the top level of your app’s help documentation when people choose a help button.

**Include no more than one help button per window.** Multiple help buttons in the same context make it hard for people to predict the result of clicking one.

**Position help buttons where people expect to find them.** Use the following locations for guidance.

| 
View style
 | 
Help button location
 | 
| 
Dialog with dismissal buttons (like OK and Cancel)
 | 
Lower corner, opposite to the dismissal buttons and vertically aligned with them
 | 
| 
Dialog without dismissal buttons
 | 
Lower-left or lower-right corner
 | 
| 
Settings window or pane
 | 
Lower-left or lower-right corner
 | 

**Use a help button within a view, not in the window frame.** For example, avoid placing a help button in a toolbar or status bar.

**Avoid displaying text that introduces a help button.** People know what a help button does, so they don’t need additional descriptive text.

##### Image buttons

An *image button* appears in a view and displays an image, symbol, or icon. You can configure an image button to behave like a push button, toggle, or pop-up button.

**Use an image button in a view, not in the window frame.** For example, avoid placing an image button in a toolbar or status bar. If you need to use an image as a button in a toolbar, use a toolbar item. See Toolbars.

**Include about 10 pixels of padding between the edges of the image and the button edges.** An image button’s edges define its clickable area even when they aren’t visible. Including padding ensures that a click registers correctly even if it’s not precisely within the image. In general, avoid including a system-provided border in an image button; for developer guidance, see isBordered.

**If you need to include a label, position it below the image button.** For related guidance, see Labels.

#### visionOS

A visionOS button typically includes a visible background that can help people see it, and the button plays sound to provide feedback when people interact with it.

There are three standard button shapes in visionOS. Typically, an icon-only button uses a circle shape, a text-only button uses a roundedRectangle or capsule shape, and a button that includes both an icon and text uses the capsule shape.

visionOS buttons use different visual styles to communicate four different interaction states.

> 
In visionOS, buttons don’t support custom hover effects.

In addition to the four states shown above, a button can also reveal a tooltip when people look at it for a brief time. In general, buttons that contain text don’t need to display a tooltip because the button’s descriptive label communicates what it does.

In visionOS, buttons can have the following sizes.

| 
Shape
 | 
Mini (28 pt)
 | 
Small (32 pt)
 | 
Regular (44 pt)
 | 
Large (52 pt)
 | 
Extra large (64 pt)
 | 
| 
Circular
 | 

 | 

 | 

 | 

 | 

 | 
| 
Capsule (text only)
 | 

 | 

 | 

 | 

 | 

 | 
| 
Capsule (text and icon)
 | 

 | 

 | 

 | 

 | 

 | 
| 
Rounded rectangle
 | 

 | 

 | 

 | 

 | 

 | 

**Prefer buttons that have a discernible background shape and fill.** It tends to be easier for people to see a button when it’s enclosed in a shape that uses a contrasting background fill. The exception is a button in a toolbar, context menu, alert, or Ornaments where the shape and material of the larger component make the button comfortably visible. The following guidelines can help you ensure that a button looks good in different contexts:

- When a button appears on top of a glass visionOS, use the thin material as the button’s background.

- When a button appears floating in space, use the visionOS for its background.

**Avoid creating a custom button that uses a white background fill and black text or icons.** The system reserves this visual style to convey the toggled state.

**In general, prefer circular or capsule-shape buttons.** People’s eyes tend to be drawn toward the corners in a shape, making it difficult to keep looking at the shape’s center. The more rounded a button’s shape, the easier it is for people to look steadily at it. When you need to display a button by itself, prefer a capsule-shape button.

**Provide enough space around a button to make it easy for people to look at it.** Aim to place buttons so their centers are always at least 60 pts apart. If your buttons measure 60 pts or larger, add 4 pts of padding around them to keep the hover effect from overlapping. Also, it’s usually best to avoid displaying small or mini buttons in a vertical stack or horizontal row.

**Choose the right shape if you need to display text-labeled buttons in a stack or row.** Specifically, prefer the rounded-rectangle shape in a vertical stack of buttons and prefer the capsule shape in a horizontal row of buttons.

**Use standard controls to take advantage of the audible feedback sounds people already know.** Audible feedback is especially important in visionOS, because the system doesn’t play haptics.

#### watchOS

watchOS displays all inline buttons using the capsule button shape. When you place a button inline with content, it gains a material effect that contrasts with the background to ensure legibility.

**Use a toolbar to place buttons in the corners.** The system automatically moves the time and title to accommodate toolbar buttons. The system also applies the Liquid Glass appearance to toolbar buttons, providing a clear visual distinction from the content beneath them.

**Prefer buttons that span the width of the screen for primary actions in your app.** Full-width buttons look better and are easier for people to tap. If two buttons must share the same horizontal space, use the same height for both, and use images or short text titles for each button’s content.

**Use toolbar buttons to provide either navigation to related areas or contextual actions for the view’s content.** These buttons provide access to additional information or secondary actions for the view’s content.

**Use the same height for vertical stacks of one- and two-line text buttons.** As much as possible, use identical button heights for visual consistency.

#### Resources

##### Related

Pop-up buttons

Pull-down buttons

Toggles

Segmented controls

Location button

##### Developer documentation

Button — SwiftUI

UIButton — UIKit

NSButton — AppKit

#### Change log

| 
Date
 | 
Changes
 | 
| 
December 16, 2025
 | 
Updated guidance for Liquid Glass.
 | 
| 
June 9, 2025
 | 
Updated guidance for button styles and content.
 | 
| 
February 2, 2024
 | 
Noted that visionOS buttons don’t support custom hover effects.
 | 
| 
December 5, 2023
 | 
Clarified some terminology and guidance for buttons in visionOS.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 
| 
June 5, 2023
 | 
Updated guidance for using buttons in watchOS.
 | 

---

## HIG: Toolbars

Source: https://developer.apple.com/design/human-interface-guidelines/toolbars

A toolbar consists of one or more sets of controls arranged horizontally along the top or bottom edge of the view, grouped into logical sections.

Toolbars act on content in the view, facilitate navigation, and help orient people in the app. They include three types of content:

- The title of the current view

- Navigation controls, like back and forward, and Search fields

- Actions, or bar items, like Buttons and Menus

In contrast to a toolbar, a Tab bars is specifically for navigating between areas of an app.

#### Best practices

**Choose items deliberately to avoid overcrowding.** People need to be able to distinguish and activate each item, so you don’t want to put too many items in the toolbar. To accommodate variable view widths, define which items move to the overflow menu as the toolbar becomes narrower.

> 
The system automatically adds an overflow menu in macOS or iPadOS when items no longer fit. Don’t add an overflow menu manually, and avoid layouts that cause toolbar items to overflow by default.

**Add a More menu to contain additional actions.** Prioritize less important actions for inclusion in the More menu. Try to include all actions in the toolbar if possible, and only add this menu if you really need it.

**In iPadOS and macOS apps, consider letting people customize the toolbar to include their most common items.** Toolbar customization is especially useful in apps that provide a lot of items — or that include advanced functionality that not everyone needs — and in apps that people tend to use for long periods of time. For example, it works well to make a range of editing actions available for toolbar customization, because people often use different types of editing commands based on their work style and their current project.

**Reduce the use of toolbar backgrounds and tinted controls.** Any custom backgrounds and appearances you use might overlay or interfere with background effects that the system provides. Instead, use the content layer to inform the color and appearance of the toolbar, and use a ScrollEdgeEffectStyle when necessary to distinguish the toolbar area from the content area. This approach helps your app express its unique personality without distracting from content.

**Avoid applying a similar color to toolbar item labels and content layer backgrounds.** If your app already has bright, colorful content in the content layer, prefer using the default monochromatic appearance of toolbars. For more guidance, see Liquid Glass color.

**Prefer using standard components in a toolbar.** By default, standard buttons, text fields, headers, and footers have corner radii that are concentric with bar corners. If you need to create a custom component, ensure that its corner radius is also concentric with the bar’s corners.

**Consider temporarily hiding toolbars for a distraction-free experience.** Sometimes people appreciate a minimal interface to reduce distractions or reveal more content. If you support this, do so contextually when it makes the most sense, and offer ways to reliably restore hidden interface elements. For guidance, see Going full screen. For guidance specific to visionOS, see Immersive experiences.

#### Titles

**Provide a useful title for each window.** A title helps people confirm their location as they navigate your app, and differentiates between the content of multiple open windows. If titling a toolbar seems redundant, you can leave the title area empty. For example, Notes doesn’t title the current note when a single window is open, because the first line of content typically supplies sufficient context. However, when opening notes in separate windows, the system titles them with the first line of content so people can tell them apart.

**Don’t title windows with your app name.** Your app’s name doesn’t provide useful information about your content hierarchy or any window or area in your app, so it doesn’t work well as a title.

**Write a concise title.** Aim for a word or short phrase that distills the purpose of the window or view, and keep the title under 15 characters long so you leave enough room for other controls.

#### Navigation

A toolbar with navigation controls appears at the top of a window, helping people move through a hierarchy of content. A toolbar also often contains a Search fields for quick navigation between areas or pieces of content. In iOS, a navigation-specific toolbar is sometimes called a navigation bar.

**Use the standard Back and Close buttons.** People know that the standard Back button lets them retrace their steps through a hierarchy of information, and the standard Close button closes a modal view. Prefer the standard symbols for each, and don’t use a text label that says *Back* or *Close*. If you create a custom version of either, make sure it still looks the same, behaves as people expect, and matches the rest of your interface, and ensure you consistently implement it throughout your app or game. For guidance, see Icons.

#### Actions

**Provide actions that support the main tasks people perform.** In general, prioritize the commands that people are most likely to want. These commands are often the ones people use most frequently, but in some apps it might make sense to prioritize commands that map to the highest level or most important objects people work with.

**Make sure the meaning of each control is clear.** Don’t make people guess or experiment to figure out what a toolbar item does. Prefer simple, recognizable symbols for items instead of text, except for actions like *edit* that aren’t well-represented by symbols. For guidance on symbols that represent common actions, see Standard icons.

**Prefer system-provided symbols without borders.** System-provided symbols are familiar, automatically receive appropriate coloring and vibrancy, and respond consistently to user interactions. Borders (like outlined circle symbols) aren’t necessary because the section provides a visible container, and the system defines hover and selection state appearances automatically. For guidance, see SF Symbols.

**Use the `.prominent` style for key actions such as Done or Submit.** This separates and tints the action so there’s a clear focal point. Only specify one primary action, and put it on the trailing side of the toolbar.

#### Item groupings

You can position toolbar items in three locations: the leading edge, center area, and trailing edge of the toolbar. These areas provide familiar homes for navigation controls, window or document titles, common actions, and search.

- **Leading edge.** Elements that let people return to the previous document and show or hide a sidebar appear at the far leading edge, followed by the view title. Next to the title, the toolbar can include a document menu that contains standard and app-specific commands that affect the document as a whole, such as Duplicate, Rename, Move, and Export. To ensure that these items are always available, items on the toolbar’s leading edge aren’t customizable.

- **Center area.** Common, useful controls appear in the center area, and the view title can appear here if it’s not on the leading edge. In macOS and iPadOS, people can add, remove, and rearrange items here if you let them customize the toolbar, and items in this section automatically collapse into the system-managed overflow menu when the window shrinks enough in size.

- **Trailing edge.** The trailing edge contains important items that need to remain available, buttons that open nearby inspectors, an optional search field, and the More menu that contains additional items and supports toolbar customization. It also includes a primary action like Done when one exists. Items on the trailing edge remain visible at all window sizes.

To position items in the groupings you want, pin them to the leading edge, center, or trailing edge, and insert space between buttons or other items where appropriate.

**Group toolbar items logically by function and frequency of use.**  For example, Keynote includes several sections that are based on functionality, including one for presentation-level commands, one for playback commands, and one for object insertion.

**Group navigation controls and critical actions like Done, Close, or Save in dedicated, familiar, and visually distinct sections.** This reflects their importance and helps people discover and understand these actions.

**Keep consistent groupings and placement across platforms.** This helps people develop familiarity with your app and trust that it behaves similarly regardless of where they use it.

**Minimize the number of groups.** Too many groups of controls can make a toolbar feel cluttered and confusing, even with the added space on iPad and Mac. In general, aim for a maximum of three.

**Keep actions with text labels separate.** Placing an action with a text label next to an action with a symbol can create the illusion of a single action with a combined text and symbol, leading to confusion and misinterpretation. If your toolbar includes multiple text-labeled buttons, the text of those buttons may appear to run together, making the buttons indistinguishable. Add separation by inserting fixed space between the buttons. For developer guidance, see UIBarButtonItem.SystemItem.fixedSpace.

#### Platform considerations

*No additional considerations for tvOS.*

#### iOS

**Prioritize only the most important items for inclusion in the main toolbar area.** Because space is so limited, carefully consider which actions are essential to your app and include those first. Create a More menu to include additional items.

**Use a large title to help people stay oriented as they navigate and scroll.** By default, a large title transitions to a standard title as people begin scrolling the content, and transitions back to large when people scroll to the top, reminding them of their current location. For developer guidance, see prefersLargeTitles.

#### iPadOS

**Consider combining a toolbar with a tab bar.** In iPadOS, a toolbar and a Tab bars can coexist in the same horizontal space at the top of the view. This is particularly useful for layouts where you want to navigate between a few main app areas while keeping the full width of the window available for content. For guidance, see Layout and Windows.

#### macOS

In a macOS app, the toolbar resides in the frame at the top of a window, either below or integrated with the title bar. Note that window titles can display inline with controls, and toolbar items don’t include a bezel.

**Make every toolbar item available as a command in the menu bar.** Because people can customize the toolbar or hide it, it can’t be the only place that presents a command. In contrast, it doesn’t make sense to provide a toolbar item for every menu item, because not all menu commands are important enough or used often enough to warrant space in the toolbar.

#### visionOS

In visionOS, the system-provided toolbar appears along the bottom edge of a window, above the window-management controls, and in a parallel plane that’s slightly in front of the window along the z-axis.

To maintain the legibility of toolbar items as content scrolls behind them, visionOS uses a variable blur in the bar background. The variable blur anchors the bar above the scrolling content while letting the view’s glass material remain uniform and undivided.

In visionOS, you can supply either a symbol or a text label for each toolbar item. When people look at a toolbar item that contains a symbol, visionOS reveals the text label, providing additional information.

**Prefer using a system-provided toolbar.** The standard toolbar has a consistent and familiar appearance and is optimized to work well with eye and hand input. In addition, the system automatically places a standard toolbar in the correct position in relation to its window.

**Avoid creating a vertical toolbar.** In visionOS, Tab bars are vertical, so presenting a vertical toolbar could confuse people.

**Try to prevent windows from resizing below the width of the toolbar.** visionOS doesn’t include a menu bar where each app lists all its actions, so it’s important for the toolbar to provide reliable access to essential controls regardless of a window’s size.

**If your app can enter a modal state, consider offering contextually relevant toolbar controls.** For example, a photo-editing app might enter a modal state to help people perform a multistep editing task. In this scenario, the controls in the modal editing view are different from the controls in the main window. Be sure to reinstate the window’s standard toolbar controls when the app exits the modal state.

**Avoid using a pull-down menu in a toolbar.** A pull-down menu lets you offer additional actions related to a toolbar item, but can be difficult for people to discover and may clutter your interface. Because a toolbar is located at the bottom edge of a window in visionOS, a pull-down menu might obscure the standard window controls that appear below the bottom edge. For guidance, see Pull-down buttons.

#### watchOS

A toolbar button lets you offer important app functionality in a view that displays related content. You can place toolbar buttons in the top corners or along the bottom. If you place these buttons above scrolling content, the buttons always remain visible, as the content scrolls under them.

For developer guidance, see topBarLeading, topBarTrailing, or bottomBar.

You can also place a button in the scrolling view. By default, a scrolling toolbar button remains hidden until people reveal it by scrolling up. People frequently scroll to the top of a scrolling view, so discovering a toolbar button is automatic.

For developer guidance, see primaryAction.

**Use a scrolling toolbar button for an important action that isn’t a primary app function.** A toolbar button gives you the flexibility to offer important functionality in a view whose primary purpose is related to that functionality, but may not be the same. For example, Mail provides the essential New Message action in a toolbar button at the top of the Inbox view. The primary purpose of the Inbox is to display a scrollable list of email messages, so it makes sense to offer the closely related compose action in a toolbar button at the top of the view.

#### Resources

##### Related

Sidebars

Tab bars

Layout

Buttons

Search fields

Apple Design Resources

##### Developer documentation

Toolbars — SwiftUI

UIToolbar — UIKit

NSToolbar — AppKit

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
December 16, 2025
 | 
Updated guidance for Liquid Glass.
 | 
| 
June 9, 2025
 | 
Added guidance for grouping bar items, updated guidance for using symbols, and incorporated navigation bar guidance.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 
| 
June 5, 2023
 | 
Updated guidance for using toolbars in watchOS.
 | 

---

## HIG: Lists and tables

Source: https://developer.apple.com/design/human-interface-guidelines/lists-and-tables

A table or list can represent data that’s organized in groups or hierarchies, and it can support user interactions like selecting, adding, deleting, and reordering. Apps and games in all platforms can use tables to present content and options; many apps use lists to express an overall information hierarchy and help people navigate it. For example, iOS Settings uses a hierarchy of lists to help people choose options, and several apps — such as Mail in iPadOS and macOS — use a table within a split view.

Sometimes, people need to work with complex data in a multicolumn table or a spreadsheet. Apps that offer productivity tasks often use a table to represent various characteristics or attributes of the data in separate, sortable columns.

#### Best practices

**Prefer displaying text in a list or table.** A table can include any type of content, but the row-based format is especially well suited to making text easy to scan and read. If you have items that vary widely in size — or you need to display a large number of images — consider using a collection instead.

**Let people edit a table when it makes sense.** People appreciate being able to reorder a list, even if they can’t add or remove items. In iOS and iPadOS, people must enter an edit mode before they can select table items.

**Provide appropriate feedback when people select a list item.** The feedback can vary depending on whether selecting the item reveals a new view or toggles the item’s state. In general, a table that helps people navigate through a hierarchy persistently highlights the selected row to clarify the path people are taking. In contrast, a table that lists options often highlights a row only briefly before adding an image — such as a checkmark — indicating that the item is selected.

#### Content

**Keep item text succinct so row content is comfortable to read.** Short, succinct text can help minimize truncation and wrapping, making text easier to read and scan. If each item consists of a large amount of text, consider alternatives that help you avoid displaying over-large table rows. For example, you could list item titles only, letting people choose an item to reveal its content in a detail view.

**Consider ways to preserve readability of text that might otherwise get clipped or truncated.** When a table is narrow — for example, if people can vary its width — you want content to remain recognizable and easy to read. Sometimes, an ellipsis in the middle of text can make an item easier to distinguish because it preserves both the beginning and the end of the content.

**Use descriptive column headings in a multicolumn table.** Use nouns or short noun phrases with title-style capitalization, and don’t add ending punctuation. If you don’t include a column heading in a single-column table view, use a label or a header to help people understand the context.

#### Style

**Choose a table or list style that coordinates with your data and platform.** Some styles use visual details to help communicate grouping and hierarchy or to provide specific experiences. In iOS and iPadOS, for example, the grouped style uses headers, footers, and additional space to separate groups of data; the elliptical style available in watchOS makes items appear as if they’re rolling off a rounded surface as people scroll; and macOS defines a bordered style that uses alternating row backgrounds to help make large tables easier to use. For developer guidance, see ListStyle.

**Choose a row style that fits the information you need to display.** For example, you might need to display a small image in the leading end of a row, followed by a brief explanatory label. Some platforms provide built-in row styles you can use to arrange content in list rows, such as the UIListContentConfiguration API you can use to lay out content in a list’s rows, headers, and footers in iOS, iPadOS, and tvOS.

#### Platform considerations

#### iOS, iPadOS, visionOS

**Use an info button only to reveal more information about a row’s content.** An info button — called a *detail disclosure button* when it appears in a list row — doesn’t support navigation through a hierarchical table or list. If you need to let people drill into a list or table row’s subviews, use a disclosure indicator accessory control. For developer guidance, see UITableViewCell.AccessoryType.disclosureIndicator.

**Avoid adding an index to a table that displays controls — like disclosure indicators — in the trailing ends of its rows.** An *index* typically consists of the letters in an alphabet, displayed vertically at the trailing side of a list. People can jump to a specific section in the list by choosing the index letter that maps to it. Because both the index and elements like disclosure indicators appear on the trailing side of a list, it can be difficult for people to use one element without activating the other.

#### macOS

**When it provides value, let people click a column heading to sort a table view based on that column**. If people click the heading of a column that’s already sorted, re-sort the data in the opposite direction.

**Let people resize columns.** Data displayed in a table view often varies in width. People appreciate resizing columns to help them concentrate on different areas or reveal clipped data.

**Consider using alternating row colors in a multicolumn table.** Alternating colors can help people track row values across columns, especially in a wide table.

**Use an outline view instead of a table view to present hierarchical data.** An outline view looks like a table view, but includes disclosure triangles for exposing nested levels of data. For example, an outline view might display folders and the items they contain.

#### tvOS

**Confirm that images near a table still look good as each row highlights and slightly increases in size when it becomes focused.** A focused row’s corners can also become rounded, which may affect the appearance of images on either side of it. Account for this effect as you prepare images, and don’t add your own masks to round the corners.

#### watchOS

**When possible, limit the number of rows.** Short lists are easier for people to scan, but sometimes people expect a long list of items. For example, if people subscribe to a large number of podcasts, they might think something’s wrong if they can’t view all their items. You can help make a long list more manageable by listing the most relevant items and providing a way for people to view more.

**Constrain the length of detail views if you want to support vertical page-based navigation.** People use vertical page-based navigation to swipe vertically among the detail items of different list rows. Navigating in this way saves time because people don’t need to return to the list to tap a new detail item, but it works only when detail views are short. If your detail views scroll, people won’t be able to use vertical page-based navigation to swipe among them.

#### Resources

##### Related

Collections

Outline views

Layout

##### Developer documentation

List — SwiftUI

Tables — SwiftUI

UITableView — UIKit

NSTableView — AppKit

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 
| 
June 5, 2023
 | 
Updated guidance to reflect changes in watchOS 10.
 | 

---

## HIG: Sheets

Source: https://developer.apple.com/design/human-interface-guidelines/sheets

A sheet is useful for requesting specific information from people or presenting a simple task that they can complete before returning to the parent view. For example, a sheet might let people supply information needed to complete an action, such as attaching a file or choosing a location to save it.

#### Anatomy

In macOS, tvOS, visionOS, and watchOS, a sheet is always *modal*. A modal sheet presents a targeted experience that prevents people from interacting with the parent view until they dismiss the sheet (for more on modal presentation, see Modality).

In iOS and iPadOS, a sheet can be either modal or *nonmodal*. When a nonmodal sheet is onscreen, people use its functionality to affect the parent view without dismissing the sheet. For example, Notes on iPhone and iPad uses a nonmodal sheet to let people format various text selections as they edit a note.

There are several common buttons that help people navigate through and dismiss sheets.

- The **Cancel** (or Close) button dismisses a sheet without saving any changes. This type of button is common in most sheets.

- The **Done** button dismisses a sheet after completing a task or explicitly saving changes.

- The **Back** button lets people navigate to a previous step in a multi-step flow or to a parent view in a hierarchy. It isn’t intended to dismiss a sheet.

The placement of these buttons varies between platforms; see Platform considerations.

#### Best practices

**For complex or prolonged user flows, consider alternatives to sheets.** For example, iOS and iPadOS offer a full-screen style of modal view that can work well to display content like videos, photos, or camera views or to help people perform multistep tasks like document or photo editing. (For developer guidance, see UIModalPresentationStyle.fullScreen.) In a macOS experience, you might want to open a new window or let people enter full-screen mode instead of using a sheet. For example, a self-contained task like editing a document tends to work well in a separate window, whereas Going full screen can help people view media. In visionOS, you can give people a way to transition your app to a Full Space where they can dive into content or a task; for guidance, see Immersive experiences.

**Display only one sheet at a time from the main interface.** When people close a sheet, they expect to return to the parent view or window. If closing a sheet takes people back to another sheet, they can lose track of where they are in your app. If something people do within a sheet results in another sheet appearing, close the first sheet before displaying the new one. If necessary, you can display the first sheet again after people dismiss the second one.

**Use a nonmodal view when you want to present supplementary items that affect the main task in the parent view.** To give people access to information and actions they need while continuing to interact with the main window, consider using a Split views in visionOS or a Panels in macOS; in iOS and iPadOS, you can use a nonmodal sheet for this workflow. For guidance, see iOS, iPadOS.

**Provide an alternative to the Done button.** If you provide a Done button, always pair it with a Cancel button to give people a clear way to dismiss the sheet without confirming or saving their changes, or a Back button to move to a previous step in the sheet. Relying solely on the Done button implies that completing the task is the only way to exit the sheet, which can feel restrictive or misleading.

Avoid showing all three buttons — Cancel, Done, and Back — together.

#### Platform considerations

*No additional considerations for tvOS.*

#### iOS, iPadOS

In iOS and iPadOS, for sheets with a single view, the Cancel button belongs on the leading edge of the top toolbar. When present, the Done button belongs on the trailing edge.

For sheets with a multi-step flow, the placement of buttons can vary across steps.

A resizable sheet expands when people scroll its contents or drag the *grabber*, which is a small horizontal indicator that can appear at the top edge of a sheet. Sheets resize according to their *detents*, which are particular heights at which a sheet naturally rests. Designed for iPhone, detents specify particular heights at which a sheet naturally rests. The system defines two detents: *large* is the height of a fully expanded sheet and *medium* is about half of the fully expanded height. Sheets can have one or more custom detent values.

Sheets automatically support the large detent. Adding the medium detent allows the sheet to rest at both heights, whereas specifying only medium prevents the sheet from expanding to full height. For developer guidance, see detents.

**In an iPhone app, consider supporting the medium detent to allow progressive disclosure of the sheet’s content.** For example, a share sheet displays the most relevant items within the medium detent, where they’re visible without resizing. To view more items, people can scroll or expand the sheet. In contrast, you might not want to support the medium detent if a sheet’s content is more useful when it displays at full height. For example, the compose sheets in Messages and Mail display only at full height to give people enough room to create content.

**Include a grabber in a resizable sheet.** A grabber shows people that they can drag the sheet to resize it; they can also tap it to cycle through the detents. In addition to providing a visual indicator of resizability, a grabber also works with VoiceOver so people can resize the sheet without seeing the screen. For developer guidance, see prefersGrabberVisible.

**Support swiping to dismiss a sheet.** People expect to swipe vertically to dismiss a sheet instead of tapping a dismiss button. If people have unsaved changes in the sheet when they begin swiping to dismiss it, use an action sheet to let them confirm their action.

**Prefer using the page or form sheet presentation styles in an iPadOS app.** Each style uses a default size for the sheet, centering its content on top of a dimmed background view and providing a consistent experience. For developer guidance, see UIModalPresentationStyle.

#### macOS

In macOS, a sheet is a cardlike view with rounded corners that floats on top of its parent window. The parent window is dimmed while the sheet is onscreen, signaling that people can’t interact with it until they dismiss the sheet. However, people expect to interact with other app windows before dismissing a sheet.

**Present a sheet in a reasonable default size.** People don’t generally expect to resize sheets, so it’s important to use a size that’s appropriate for the content you display. In some cases, however, people appreciate a resizable sheet — such as when they need to expand the contents for a clearer view — so it’s a good idea to support resizing.

**Let people interact with other app windows without first dismissing a sheet.** When a sheet opens, you bring its parent window to the front — if the parent window is a document window, you also bring forward its modeless document-related panels. When people want to interact with other windows in your app, make sure they can bring those windows forward even if they haven’t dismissed the sheet yet.

**Use a panel instead of a sheet if people need to repeatedly provide input and observe results.** A find and replace panel, for example, might let people initiate replacements individually, so they can observe the result of each search for correctness. For guidance, see Panels.

#### visionOS

While a sheet is visible in a visionOS app, it floats in front of its parent window, dimming it, and becoming the target of people’s interactions with the app.

**Avoid displaying a sheet that emerges from the bottom edge of a window.** To help people view the sheet, prefer centering it in their Field of view.

**Present a sheet in a default size that helps people retain their context.** Avoid displaying a sheet that covers most or all of its window, but consider letting people resize the sheet if they want.

#### watchOS

In watchOS, a sheet is a full-screen view that slides over your app’s current content. The sheet is semitransparent to help maintain the current context, but the system applies a material to the background that blurs and desaturates the covered content.

**Use a sheet only when your modal task requires a custom title or custom content presentation.** If you need to give people important information or present a set of choices, consider using an Alerts or Action sheets.

**Keep sheet interactions brief and occasional.** Use a sheet only as a temporary interruption to the current workflow, and only to facilitate an important task. Avoid using a sheet to help people navigate your app’s content.

**If you change the default label, prefer using SF Symbols to represent the action.** Avoid using a label that might mislead people into thinking that the sheet is part of a hierarchical navigation interface. Also, if the text in the top-leading corner looks like a page or app title, people won’t know how to dismiss the sheet. For guidance, see Standard icons.

#### Resources

##### Related

Modality

Action sheets

Popovers

Panels

##### Developer documentation

sheet(item:onDismiss:content:) — SwiftUI

UISheetPresentationController — UIKit

presentAsSheet(_:) — AppKit

#### Change log

| 
Date
 | 
Changes
 | 
| 
March 24, 2026
 | 
Updated guidance for button placement.
 | 
| 
March 29, 2024
 | 
Added guidance to use form or page sheet styles in iPadOS apps.
 | 
| 
December 5, 2023
 | 
Recommended using a split view to offer supplementary items in a visionOS app.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 
| 
June 5, 2023
 | 
Updated guidance for using sheets in watchOS.
 | 

---

## HIG: Alerts

Source: https://developer.apple.com/design/human-interface-guidelines/alerts

For example, an alert can tell people about a problem, warn them when their action might destroy data, and give them an opportunity to confirm a purchase or another important action they initiated.

#### Best practices

**Use alerts sparingly.** Alerts give people important information, but they interrupt the current task to do so. Encourage people to pay attention to your alerts by making certain that each one offers only essential information and useful actions.

**Avoid using an alert merely to provide information.** People don’t appreciate an interruption from an alert that’s informative, but not actionable. If you need to provide only information, prefer finding an alternative way to communicate it within the relevant context. For example, when a server connection is unavailable, Mail displays an indicator that people can choose to learn more.

**Avoid displaying alerts for common, undoable actions, even when they’re destructive.** For example, you don’t need to alert people about data loss every time they delete an email or file because they do so with the intention of discarding data, and they can undo the action. In comparison, when people take an uncommon destructive action that they can’t undo, it’s important to display an alert in case they initiated the action accidentally.

**Avoid showing an alert when your app starts.** If you need to inform people about new or important information the moment they open your app, design a way to make the information easily discoverable. If your app detects a problem at startup, like no network connection, consider alternative ways to let people know. For example, you could show cached or placeholder data and a nonintrusive label that describes the problem.

#### Anatomy

An alert is a modal view that can look different in different platforms and devices.

#### Content

In all platforms, alerts display a title, optional informative text, and up to three buttons. On some platforms, alerts can include additional elements.

- In iOS, iPadOS, macOS, and visionOS, an alert can include a text field.

- Alerts in macOS and visionOS can include an icon and an accessory view.

- macOS alerts can add a suppression Checkboxes and a Help buttons.

**In all alert copy, be direct, and use a neutral, approachable tone.** Alerts often describe problems and serious situations, so avoid being oblique or accusatory, or masking the severity of the issue.

**Write a title that clearly and succinctly describes the situation.** You need to help people quickly understand the situation, so be complete and specific, without being verbose. As much as possible, describe what happened, the context in which it happened, and why. Avoid writing a title that doesn’t convey useful information — like “Error” or “Error 329347 occurred” — but also avoid overly long titles that wrap to more than two lines. If the title is a complete sentence, use sentence-style capitalization and appropriate ending punctuation. If the title is a sentence fragment, use title-style capitalization, and don’t add ending punctuation.

**Include informative text only if it adds value.** If you need to add an informative message, keep it as short as possible, using complete sentences, sentence-style capitalization, and appropriate punctuation.

**Avoid explaining alert buttons.** If your alert text and button titles are clear, you don’t need to explain what the buttons do. In rare cases where you need to provide guidance on choosing a button, use a term like *choose* to account for people’s current device and interaction method, and refer to a button using its exact title without quotes. For guidance, see Buttons.

**If supported, include a text field only if you need people’s input to resolve the situation.** For example, you might need to present a secure text field to receive a password.

#### Buttons

**Create succinct, logical button titles.** Aim for a one- or two-word title that describes the result of selecting the button. Prefer verbs and verb phrases that relate directly to the alert text — for example, “View All,” “Reply,” or “Ignore.” In informational alerts only, you can use “OK” for acceptance, avoiding “Yes” and “No.” Always use “Cancel” to title a button that cancels the alert’s action. As with all button titles, use sentence-style capitalization and no ending punctuation.

**Avoid using OK as the default button title unless the alert is purely informational.** The meaning of “OK” can be unclear even in alerts that ask people to confirm that they want to do something. For example, does “OK” mean “OK, I want to complete the action” or “OK, I now understand the negative results my action would have caused”? A specific button title like “Erase,” “Convert,” “Clear,” or “Delete” helps people understand the action they’re taking.

**Place buttons where people expect.** In general, place the button people are most likely to choose on the trailing side in a row of buttons or at the top in a stack of buttons. Always place the default button on the trailing side of a row or at the top of a stack. Cancel buttons are typically on the leading side of a row or at the bottom of a stack.

**Use the destructive style to identify a button that performs a destructive action people didn’t deliberately choose.** For example, when people deliberately choose a destructive action — such as Empty Trash — the resulting alert doesn’t apply the destructive style to the Empty Trash button because the button performs the person’s original intent. In this scenario, the convenience of pressing Return to confirm the deliberately chosen Empty Trash action outweighs the benefit of reaffirming that the button is destructive. In contrast, people appreciate an alert that draws their attention to a button that can perform a destructive action they didn’t originally intend.

**If there’s a destructive action, include a Cancel button to give people a clear, safe way to avoid the action.** Always use the title “Cancel” for a button that cancels an alert’s action. Note that you don’t want to make a Cancel button the default button. If you want to encourage people to read an alert and not just automatically press Return to dismiss it, avoid making any button the default button. Similarly, if you must display an alert with a single button that’s also the default, use a Done button, not a Cancel button.

**Provide alternative ways to cancel an alert when it makes sense.** In addition to choosing a Cancel button, people appreciate using keyboard shortcuts or other quick ways to cancel an onscreen alert. For example:

| 
Action
 | 
Platform
 | 
| 
Exit to the Home Screen
 | 
iOS, iPadOS
 | 
| 
Pressing Escape (Esc) or Command-Period (.) on an attached keyboard
 | 
iOS, iPadOS, macOS, visionOS
 | 
| 
Pressing Menu on the remote
 | 
tvOS
 | 

#### Platform considerations

*No additional considerations for tvOS or watchOS.*

#### iOS, iPadOS

**Use an action sheet — not an alert — to offer choices related to an intentional action.** For example, when people cancel the Mail message they’re editing, an action sheet provides three choices: delete the edits (or the entire draft), save the draft, or return to editing. Although an alert can also help people confirm or cancel an action that has destructive consequences, it doesn’t provide additional choices related to the action. For guidance, see Action sheets.

**When possible, avoid displaying an alert that scrolls.** Although an alert might scroll if the text size is large enough, be sure to minimize the potential for scrolling by keeping alert titles short and including a brief message only when necessary.

#### macOS

macOS automatically displays your app icon in an alert, but you can supply an alternative icon or symbol. In addition, macOS lets you:

- Configure repeating alerts to let people suppress subsequent occurrences of the same alert.

- Append a custom view if it’s necessary to provide additional information (for developer guidance, see accessoryView).

- Include a Help button that opens your help documentation (see Help buttons).

**Use a caution symbol sparingly.** Using a caution symbol like `exclamationmark.triangle` too frequently in your alerts diminishes its significance. Use the symbol only when extra attention is really needed, as when confirming an action that might result in unexpected loss of data. Don’t use the symbol for tasks whose only purpose is to overwrite or remove data, such as a save or empty trash.

#### visionOS

When your app is running in the Shared Space, visionOS displays an alert in front of the app’s window, slightly forward along the z-axis.

If someone moves a window without dismissing its alert, the alert remains anchored to the window. If your app is running in a Full Space, the system displays the alert centered in the wearer’s Field of view.

If you need to display an accessory view in a visionOS alert, create a view that has a maximum height of 154 pt and a 16-pt corner radius.

#### Resources

##### Related

Modality

Action sheets

Sheets

##### Developer documentation

alert(_:isPresented:actions:) — SwiftUI

UIAlertController — UIKit

NSAlert — AppKit

#### Change log

| 
Date
 | 
Changes
 | 
| 
February 2, 2024
 | 
Enhanced guidance for using default and Cancel buttons.
 | 
| 
September 12, 2023
 | 
Added anatomy artwork for visionOS.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 

---

## HIG: Modality

Source: https://developer.apple.com/design/human-interface-guidelines/modality

Presenting content modally can:

- Ensure that people receive critical information and, if necessary, act on it

- Provide options that let people confirm or modify their most recent action

- Help people perform a distinct, narrowly scoped task without losing track of their previous context

- Give people an immersive experience or help them concentrate on a complex task

Depending on the platform, you might use different components to present these types of modal experiences. For example, all platforms can present an *alert*, which is a modal view that delivers important information related to your app or game. In addition, each platform may define various types of modal views for presenting context-specific options, such as *activity views,* *sheets*, and *confirmation dialogs* or *action sheets*. To help people perform a distinct task, iOS, iPadOS, and macOS apps tend to use sheets or popovers, but iPadOS, macOS, and visionOS apps might also just use a separate window.

To provide a temporary experience, like viewing media, or to help people perform a distinct, multistep task, like editing content, apps can offer a full-screen modal experience. In contrast, apps may also offer nonmodal types of full-screen experiences; for guidance, see Going full screen. visionOS apps can offer a range of immersive experiences; for guidance, see Immersive experiences.

#### Best practices

**Present content modally only when there’s a clear benefit.** A modal experience takes people out of their current context and requires an action to dismiss, so it’s important to use modality only when it helps people focus or make choices that affect their content or device.

**Aim to keep modal tasks simple, short, and streamlined.** If a modal task is too complicated, people can lose track of the task they suspended when they entered the modal view, especially if the modal view obscures their previous context.

**Take care to avoid creating a modal experience that feels like an app within your app.** In particular, presenting a hierarchy of views within a modal task can make people forget how to retrace their steps. If a modal task must contain subviews, provide a single path through the hierarchy and avoid including buttons that people might mistake for the button that dismisses the modal view.

**Consider using a full-screen modal style for in-depth content or a complex task.** A modal experience that fills a window or the device display minimizes distractions, so it can work well for presenting videos, photos, or camera views, or to support a multistep task like marking up a document or editing a photo. When a visionOS app runs alongside other apps in the Shared Space, a full-screen modal presentation fills a window; if people transition the app to a Full Space, the full-screen modal presentation can become a more immersive experience.

**Always give people an obvious way to dismiss a modal view.** In general, it works well to follow the platform conventions people already know. For example, in iOS, iPadOS, and watchOS apps, people typically expect to find a button in the top toolbar or swipe down; in macOS and tvOS apps, people expect to find a button in the main content view.

**When necessary, help people avoid data loss by getting confirmation before closing a modal view.** Regardless of whether people use a dismiss gesture or a button, if closing the view could result in the loss of user-generated content, be sure to explain the situation and give people ways to resolve it. For example, in iOS, you might present an action sheet that includes a save option.

**Make it easy to identify a modal view’s task.** When people enter a modal view, they switch away from their previous context and might not return to it right away. When you provide a title that names the modal view’s task — or additional text that describes the task or provides guidance — you can help people keep their place in your app.

**Let people dismiss a modal view before presenting another one.** Allowing multiple modal views to be visible at the same time tends to create visual clutter and can make your app seem scattered and disorganized. People need to remember the context they were in before a modal view appears, so presenting multiple views adds to people’s cognitive load, especially when a modal view hides another one by appearing on top of it. Although an alert can appear on top of all other content — including other modal views — you never want to display more than one alert at the same time.

#### Platform considerations

*No additional considerations for iOS, iPadOS, macOS, tvOS, visionOS, or watchOS.*

#### Resources

##### Related

Sheets

Alerts

Popovers

Action sheets

Activity views

##### Developer documentation

Presentation modifiers — SwiftUI

UIModalPresentationStyle — UIKit

Modal Windows and Panels — AppKit

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
December 5, 2023
 | 
Enhanced guidance for in-depth modal experiences and clarified guidance on multiple modal views.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 

---

## HIG: Searching

Source: https://developer.apple.com/design/human-interface-guidelines/searching

To search for content within an app, people generally expect to use a Search fields. When it makes sense, you can personalize the search experience by using what you know about how people interact with your app. For example, you might display recent searches, search suggestions, completions, or corrections based on terms people searched earlier in your app.

In some cases, people appreciate the ability to scope a search or filter the results. For example, people might want to search for items by specifying attributes like creation date, file size, or file type. For guidance, see Scope bars and tokens. You can also help people find content within an open document or file by implementing ways to find content in a window or page in your iOS, iPadOS, or macOS app.

In iOS, iPadOS, and macOS, Spotlight helps people find content across all apps in the system and on the web. When you index and provide information about your app’s content, people can use Spotlight to find content your app contains without opening it first. For guidance, see Systemwide search.

#### Best practices

**If search is important, give it a primary position in your app or view.** For example, in the Notes app, a search field is in the bottom Toolbars alongside other important actions. In apps that use Tab bars, like Photos and Apple TV, search is a dedicated tab.

**Aim to make your app’s content searchable through a single location.** People appreciate having one clearly identified location they can use to find anything they’re looking for in your app. For apps with clearly distinct sections, it may still be useful to offer a local search. For example, search acts as a filter on the current view when searching your songs and albums in the iOS Music app.

**Clearly display the current scope of a search.** Use a descriptive placeholder text, a Scope bars and tokens, or a title to help reinforce what someone is currently searching. For example, in the Mail app there is always a clear reference to the mailbox someone is searching.

**Provide suggestions to make searching easier.** When you display a personʼs recent searches before they start typing or offer predictive search suggestions while they’re typing, you can help people search faster and type less. For developer guidance, see searchSuggestions(_:).

**Take privacy into consideration before displaying search history.** People might not appreciate having their search history appear where others might see it. If you do show search history, provide a way for people to clear it if they want.

#### Systemwide search

**Make your app’s content searchable in Spotlight.** You can share content with Spotlight by making it indexable and specifying descriptive attributes known as *metadata*. Spotlight extracts, stores, and organizes this information to allow for fast, comprehensive searches.

**Define metadata for custom file types you handle.** Supply a Spotlight File Importer plug-in that describes the types of metadata your file format contains. For developer guidance, see CSImportExtension.

**Use Spotlight to offer advanced file-search capabilities within the context of your app.** For example, you might include a button that instantly initiates a Spotlight search based on the current selection. You might then display a custom view that presents the search results or a filtered subset of them.

**Prefer using the system-provided open and save views.** The system-provided open and save views generally include a built-in search field that people can use to search and filter the entire system. For related guidance, see File management.

**Implement a Quick Look generator if your app produces custom file types.** A Quick Look generator helps Spotlight and other apps show previews of your documents. For developer guidance, see Quick Look.

#### Platform considerations

*No additional considerations for iOS, iPadOS, macOS, tvOS, visionOS, or watchOS.*

#### Resources

##### Related

Search fields

##### Developer documentation

Adding your app’s content to Spotlight indexes — Core Spotlight

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
June 8, 2026
 | 
Updated terminology and refined best practices.
 | 
| 
June 9, 2025
 | 
Updated best practices with general guidance from Search fields, and reorganized guidance for systemwide search.
 | 

---

## HIG: Text fields

Source: https://developer.apple.com/design/human-interface-guidelines/text-fields

#### Best practices

**Use a text field to request a small amount of information, such as a name or an email address.** To let people input larger amounts of text, use a Text views instead.

**Show a hint in a text field to help communicate its purpose.** A text field can contain placeholder text — such as “Email” or “Password” — when there’s no other text in the field. Because placeholder text disappears when people start typing, it can also be useful to include a separate label describing the field to remind people of its purpose.

**Use secure text fields to hide private data.** Always use a secure text field when your app asks for sensitive data, such as a password. For developer guidance, see SecureField.

**To the extent possible, match the size of a text field to the quantity of anticipated text.** The size of a text field helps people visually gauge the amount of information to provide.

**Evenly space multiple text fields.** If your layout includes multiple text fields, leave enough space between them so people can easily see which input field belongs with each introductory label. Stack multiple text fields vertically when possible, and use consistent widths to create a more organized layout. For example, the first and last name fields on an address form might be one width, while the address and city fields might be a different width.

**Ensure that tabbing between multiple fields flows as people expect.** When tabbing between fields, move focus in a logical sequence. The system attempts to achieve this result automatically, so you won’t need to customize this too often.

**Validate fields when it makes sense.** For example, if the only legitimate value for a field is a string of digits, your app needs to alert people if they’ve entered characters other than digits. The appropriate time to check the data depends on the context: when entering an email address, it’s best to validate when people switch to another field; when creating a user name or password, validation needs to happen before people switch to another field.

**Use a number formatter to help with numeric data.** A number formatter automatically configures the text field to accept only numeric values. It can also display the value in a specific way, such as with a certain number of decimal places, as a percentage, or as currency. Don’t assume the actual presentation of data, however, as formatting can vary significantly based on people’s locale.

**Adjust line breaks according to the needs of the field.** By default, the system clips any text extending beyond the bounds of a text field. Alternatively, you can set up a text field to wrap text to a new line at the character or word level, or to truncate (indicated by an ellipsis) at the beginning, middle, or end.

**Consider using an expansion tooltip to show the full version of clipped or truncated text.** An expansion tooltip behaves like a regular tooltip and appears when someone places the pointer over the field.

**In iOS, iPadOS, tvOS, and visionOS apps, show the appropriate keyboard type.** Several different keyboard types are available, each designed to facilitate a different type of input, such as numbers or URLs. To streamline data entry, display the keyboard that’s appropriate for the type of content people are entering. For guidance, see Virtual keyboards.

**Minimize text entry in your tvOS and watchOS apps.** Entering long passages of text or filling out numerous text fields is time-consuming on Apple TV and Apple Watch. Minimize text input and consider gathering information more efficiently, such as with buttons.

#### Platform considerations

*No additional considerations for tvOS or visionOS.*

#### iOS, iPadOS

**Display a Clear button in the trailing end of a text field to help people erase their input.** When this element is present, people can tap it to clear the text field’s contents, without having to keep tapping the Delete key.

**Use images and buttons to provide clarity and functionality in text fields.** You can display custom images in both ends of a text field, or you can add a system-provided button, such as the Bookmarks button. In general, use the leading end of a text field to indicate a field’s purpose and the trailing end to offer additional features, such as bookmarking.

#### macOS

**Consider using a combo box if you need to pair text input with a list of choices.** For related guidance, see Combo boxes.

#### watchOS

**Present a text field only when necessary.** Whenever possible, prefer displaying a list of options rather than requiring text entry.

#### Resources

##### Related

Text views

Combo boxes

Entering data

##### Developer documentation

TextField — SwiftUI

SecureField — SwiftUI

UITextField — UIKit

NSTextField — AppKit

#### Change log

| 
Date
 | 
Changes
 | 
| 
June 5, 2023
 | 
Updated guidance to reflect changes in watchOS 10.
 | 

---

## HIG: Segmented controls

Source: https://developer.apple.com/design/human-interface-guidelines/segmented-controls

Within a segmented control, all segments are usually equal in width. Like Buttons, segments can contain text or images. Segments can also have text labels beneath them (or beneath the control as a whole).

A segmented control offers a single choice from among a set of options, or in macOS, either a single choice or multiple choices. For example, in macOS Keynote people can select only one segment in the alignment options control to align selected text. In contrast, people can choose multiple segments in the font attributes control to combine styles like bold, italics, and underline. The toolbar of a Keynote window also uses a segmented control to let people show and hide various editing panes within the main window area.

In addition to representing the state of a single or multiple-choice selection, a segmented control can function as a set of buttons that perform actions without showing a selection state. For example, the Reply, Reply all, and Forward buttons in macOS Mail. For developer guidance, see isMomentary and NSSegmentedControl.SwitchTracking.momentary.

#### Best practices

**Use a segmented control to provide closely related choices that affect an object, state, or view.** For example, a segmented control in an inspector could let people choose one or more attributes to apply to a selection, or a segmented control in a toolbar could offer a set of actions to perform on the current view.

**Consider a segmented control when it’s important to group functions together, or to clearly show their selection state.** Unlike other button styles, segmented controls preserve their grouping regardless of the view size or where they appear. This grouping can also help people understand at a glance which controls are currently selected.

**Keep control types consistent within a single segmented control.** Don’t assign actions to segments in a control that otherwise represents selection state, and don’t show a selection state for segments in a control that otherwise performs actions.

**Limit the number of segments in a control.** Too many segments can be hard to parse and time-consuming to navigate. Aim for no more than about five to seven segments in a wide interface and no more than about five segments on iPhone.

**In general, keep segment size consistent.** When all segments have equal width, a segmented control feels balanced. To the extent possible, it’s best to keep icon and title widths consistent too.

#### Content

**Prefer using either text or images — not a mix of both — in a single segmented control.** Although individual segments can contain text labels or images, mixing the two in a single control can lead to a disconnected and confusing interface.

**As much as possible, use content with a similar size in each segment.** Because all segments typically have equal width, it doesn’t look good if content fills some segments but not others.

**Use nouns or noun phrases for segment labels.** Write text that describes each segment and uses title-style capitalization. A segmented control that displays text labels doesn’t need introductory text.

#### Platform considerations

*Not supported in watchOS.*

#### iOS, iPadOS

**Consider a segmented control to switch between closely related subviews.** A segmented control can be useful as a way to quickly switch between related subviews. For example, the segmented control in Calendar’s New Event sheet switches between the subviews for creating a new event and a new reminder. For switching between completely separate sections of an app, use a Tab bars instead.

#### macOS

**Consider using introductory text to clarify the purpose of a segmented control.** When the control uses symbols or interface icons, you could also add a label below each segment to clarify its meaning. If your app includes tooltips, provide one for each segment in a segmented control.

**Use a tab view in the main window area — instead of a segmented control — for view switching.** A Tab views supports efficient view switching and is similar in appearance to a Boxes combined with a segmented control. Consider using a segmented control to help people switch views in a toolbar or inspector pane.

**Consider supporting spring loading.** On a Mac equipped with a Magic Trackpad, spring loading lets people activate a segment by dragging selected items over it and force clicking without dropping the selected items. People can also continue dragging the items after a segment activates.

#### tvOS

**Consider using a split view instead of a segmented control on screens that perform content filtering.** People generally find it easy to navigate back and forth between content and filtering options using a split view. Depending on its placement, a segmented control may not be as easy to access.

**Avoid putting other focusable elements close to segmented controls.** Segments become selected when focus moves to them, not when people click them. Carefully consider where you position a segmented control relative to other interface elements. If other focusable elements are too close, people might accidentally focus on them when attempting to switch between segments.

#### visionOS

When people look at a segmented control that uses icons, the system displays a tooltip that contains the descriptive text you supply.

#### Resources

##### Related

Split views

##### Developer documentation

segmented — SwiftUI

UISegmentedControl — UIKit

NSSegmentedControl — AppKit

#### Change log

| 
Date
 | 
Changes
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 

---

## HIG: Pull-down buttons

Source: https://developer.apple.com/design/human-interface-guidelines/pull-down-buttons

After people choose an item in a pull-down button’s menu, the menu closes, and the app performs the chosen action.

#### Best practices

**Use a pull-down button to present commands or items that are directly related to the button’s action.** The menu lets you help people clarify the button’s target or customize its behavior without requiring additional buttons in your interface. For example:

- An Add button could present a menu that lets people specify the item they want to add.

- A Sort button could use a menu to let people select an attribute on which to sort.

- A Back button could let people choose a specific location to revisit instead of opening the previous one.

If you need to provide a list of mutually exclusive choices that aren’t commands, use a Pop-up buttons instead.

**Avoid putting all of a view’s actions in one pull-down button.** A view’s primary actions need to be easily discoverable, so you don’t want to hide them in a pull-down button that people have to open before they can do anything.

**Balance menu length with ease of use.** Because people have to interact with a pull-down button before they can view its menu, listing a minimum of three items can help the interaction feel worthwhile. If you need to list only one or two items, consider using alternative components to present them, such as buttons to perform actions and toggles or switches to present selections. In contrast, listing too many items in a pull-down button’s menu can slow people down because it takes longer to find a specific item.

**Display a succinct menu title only if it adds meaning.** In general, a pull-down button’s content — combined with descriptive menu items — provides all the context people need, making a menu title unnecessary.

**Let people know when a pull-down button’s menu item is destructive, and ask them to confirm their intent.** Menus use red text to highlight actions that you identify as potentially destructive. When people choose a destructive action, the system displays an Action sheets (iOS) or Popovers (iPadOS) in which they can confirm their choice or cancel the action. Because an action sheet appears in a different location from the menu and requires deliberate dismissal, it can help people avoid losing data by mistake.

**Include an interface icon with a menu item when it provides value.** If you need to clarify an item’s meaning, you can display an Icons or image after its label. Using SF Symbols for this purpose can help you provide a familiar experience while ensuring that the symbol remains aligned with the text at every scale.

#### Platform considerations

*No additional considerations for macOS or visionOS. Not supported in tvOS or watchOS.*

#### iOS, iPadOS

> 
You can also let people reveal a pull-down menu by performing a specific gesture on a button. For example, in iOS 14 and later, Safari responds to a touch and hold gesture on the Tabs button by displaying a menu of tab-related actions, like New Tab and Close All Tabs.

**Consider using a More pull-down button to present items that don’t need prominent positions in the main interface.** A More button can help you offer a range of items where space is constrained, but it can also hinder discoverability. Although people generally understand that a More button offers additional functionality related to the current context, the ellipsis icon doesn’t necessarily help them predict its contents. To design an effective More button, weigh the convenience of its size against its impact on discoverability to find a balance that works in your app.

#### Resources

##### Related

Pop-up buttons

Buttons

Menus

##### Developer documentation

MenuPickerStyle — SwiftUI

showsMenuAsPrimaryAction — UIKit

pullsDown — AppKit

#### Change log

| 
Date
 | 
Changes
 | 
| 
September 14, 2022
 | 
Refined guidance on designing a useful menu length.
 | 

---

## HIG: Loading

Source: https://developer.apple.com/design/human-interface-guidelines/loading

If your app or game loads assets, levels, or other content, design the behavior so it doesn’t disrupt or negatively impact the user experience.

#### Best practices

**Show something as soon as possible.** If you make people wait for loading to complete before displaying anything, they can interpret the lack of content as a problem with your app or game. Instead, consider showing placeholder text, graphics, or animations as content loads, replacing these elements as content becomes available.

**Let people do other things in your app or game while they wait for content to load.** Loading content in the background helps give people access to other actions. For example, a game could load content in the background while players learn about the next level or view an in-game menu. For developer guidance, see Improving the player experience for games with large downloads.

**If loading takes an unavoidably long time, give people something interesting to view while they wait.** For example, you might provide gameplay hints, display tips, or introduce people to new features. Gauge the remaining loading time as accurately as possible to help you avoid giving people too little time to enjoy your placeholder content or having so much time that you need to repeat it.

**Improve installation and launch time by downloading large assets in the background.** Consider using the Background Assets framework to schedule asset downloads — like game level packs, 3D character models, and textures — to occur immediately after installation, during updates, or at other nondisruptive times.

#### Showing progress

**Clearly communicate that content is loading and how long it might take to complete.** Ideally, content displays instantly, but for situations where loading takes more than a moment or two, you can use system-provided components — called *progress indicators* — to show that loading is ongoing. In general, you use a *determinate* progress indicator when you know how long loading will take, and you use an *indeterminate* progress indicator when you don’t. For guidance, see Progress indicators.

**For games, consider creating a custom loading view.** Standard progress indicators work well in most apps, but can sometimes feel out of place in a game. Consider designing a more engaging experience by using custom animations and elements that match the style of your game.

#### Platform considerations

*No additional considerations for iOS, iPadOS, macOS, tvOS, or visionOS.*

#### watchOS

**As much as possible, avoid showing a loading indicator in your watchOS experience.** People expect quick interactions with their Apple Watch, so aim to display content immediately. In situations where content needs a second or two to load, it’s better to display a loading indicator than a blank screen.

#### Resources

##### Related

Launching

Progress indicators

##### Developer documentation

Background Assets

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
June 9, 2025
 | 
Revised guidance for storing downloads to reflect downloading large assets in the background.
 | 
| 
June 10, 2024
 | 
Added guidelines for showing progress and storing downloads, and enhanced guidance for games.
 | 

---

## HIG: Feedback

Source: https://developer.apple.com/design/human-interface-guidelines/feedback

Providing clear, consistent feedback as people interact with your app or game can make it feel intuitive and encourage deeper exploration. Feedback can communicate several different things, such as:

- The current status of something

- The success or failure of an important task or action

- A warning about an action that can have negative consequences

- An opportunity to correct a mistake or problematic situation

The most effective feedback tends to match the significance of the information to the way it’s delivered. For example, it often works well to display status information in a passive way so that people can view it when they need it. In contrast, a warning about possible data loss needs to interrupt people so they have a chance to avoid the problem.

#### Best practices

**Make sure all feedback is accessible.** When you use multiple ways to provide feedback, you reach more people and give them the opportunity to receive the feedback in ways that work for them. For example, when you provide feedback using color, text, sound, and haptics, people can receive it whether they silence their device, look away from the screen, or use VoiceOver. (For guidance on providing haptic feedback, see Playing haptics.)

**Consider integrating status feedback into your interface.** When status feedback is available near the items it describes, people get important information without having to take action or leave their current context. For example, Mail in iOS and iPadOS describes the most recent update and displays the number of unread messages in the toolbar of the mailbox screen, making the information unobtrusive but easy for people to check when they’re interested.

**Use alerts to deliver critical — and ideally actionable — information.** By design, alerts disrupt the current context, so you need to match the importance of the information to the level of interruption. Alerts can lose their impact if you use them too often or to deliver unimportant information. For guidance, see Alerts.

**Warn people when they initiate a task that can cause data loss that’s unexpected and irreversible.** In contrast, don’t warn people when data loss is the expected result of their action. For example, the Finder doesn’t warn people every time they throw away a file because deleting the file is the expected result.

**When it makes sense, confirm that a significant action or task has completed.** For example, people appreciate getting feedback that confirms a successful Apple Pay transaction. It’s generally best to reserve this type of confirmation for activities that are sufficiently important — because people typically expect their action or task to succeed, they only need to know when it doesn’t.

**Show people when a command can’t be carried out and help them understand why.** For example, if people request directions without specifying a destination, Maps tells them that it can’t provide directions to and from the same location.

#### Platform considerations

*No additional considerations for iOS, iPadOS, macOS, tvOS, or visionOS.*

#### watchOS

**Avoid displaying an indeterminate progress indicator — such as a loading indicator — in a watchOS app.** An animated indicator can make people think they need to continue paying attention to the display, which isn’t a good user experience. To provide a better experience, reassure people that they’ll receive a notification when the process completes.

#### Resources

##### Related

Playing audio

Playing haptics

Motion

##### Developer documentation

Animation and haptics — UIKit

##### Videos

---

## HIG: Onboarding

Source: https://developer.apple.com/design/human-interface-guidelines/onboarding

Ideally, people can understand your app or game simply by experiencing it, but if onboarding is necessary, design a flow that’s fast, fun, and optional. When available, onboarding occurs after Launching is complete — it isn’t part of the launch experience.

#### Best practices

**Teach through interactivity.** People tend to grasp and retain information better when they can actually perform the task they’re learning about instead of just viewing instructional material. As much as possible, provide an interactive onboarding experience where people can safely test an action, discover a feature, or try out a game mechanic.

**Consider providing a collection of context-specific tips instead of a single onboarding flow.** Integrating contextually relevant tips into your experience can help people learn about their current task while they make progress in your app or game. A context-specific tip can also help people learn better because it lets them concentrate on a single action or task before encountering new information. When you have instructional content that refers to a specific area of the interface, display these instructions near that area. For developer guidance, see TipKit.

**If you need to present a prerequisite onboarding flow, design a brief, enjoyable experience that doesn’t require people to memorize a lot of information.** When onboarding is quick and entertaining, people are more likely to complete it. In contrast, if you try to teach too much, people can feel overwhelmed and may be less likely to remember what they learned.

**If it makes sense to offer a separate tutorial, consider making it optional.** If you let people skip the tutorial when they first launch your app or game, don’t present it again on subsequent launches, but make sure it’s easy for people to find if they want to view it later. For example, you could make the tutorial available in a help, account, or settings area within your app or game.

**Keep onboarding content focused on the experience you provide.** People enter your onboarding flow to learn about your app or game; they don’t need to learn how to use the system or the device.

#### Additional content

**Briefly display a splash screen if necessary.** If you need to include a splash screen, design a beautiful graphic that communicates succinctly. Aim to display your splash screen just long enough for people to absorb the information at a glance without feeling that it’s delaying their experience.

**Don’t let large downloads hinder onboarding.** People want to start using your app or game immediately after first launching it, whether they participate in an onboarding flow or skip it. Consider including enough media and other content in your software package to prevent people from having to wait for downloads to complete before they can start interacting with your app or game. For guidance, see Launching.

**Avoid displaying licensing details within your onboarding flow.** Let the App Store display agreements and disclaimers so people can read them before downloading your app or game. If you must include these items within the onboarding flow, integrate them in a balanced way that doesn’t disrupt the experience.

#### Additional requests

**Postpone nonessential setup flows or customization steps.** Provide reasonable default settings so most people can immediately start interacting with your app or game without performing additional configuration.

**If your app or game needs access to private data or resources before it can function, consider integrating the permission request into your onboarding flow.** In this scenario, making the request during your onboarding flow gives you the opportunity to show people why your app or game needs their permission and the benefits of granting it. Otherwise, present a permission request when people first access the specific function that relies on private data or resources. For guidance, see Requesting permission.

**Prefer letting people experience your app or game before prompting them for ratings or purchases.** People can be more likely to respond positively to such requests when they’ve had a chance to become engaged with your app or game.

#### Platform considerations

*No additional considerations for iOS, iPadOS, macOS, tvOS, visionOS, or watchOS.*

#### Resources

##### Related

Launching

Feedback

Offering help

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
June 10, 2024
 | 
Clarified different approaches to onboarding and added a guideline on displaying a splash screen.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 

---

## HIG: Settings

Source: https://developer.apple.com/design/human-interface-guidelines/settings

On all Apple platforms, the system-provided Settings app lets people adjust things like the overall appearance of the system, network connections, account details, accessibility requirements, and language and region settings. On some platforms, the system-provided Settings app can also include settings for specific apps and games, often letting people adjust whether the app or game can access location information, use device features like microphone or camera, and integrate with system features like notifications, Siri, or Search.

When necessary, you can provide a custom settings area within your app or game to offer general settings that affect your overall experience, like interface style or game-saving behavior. If you need to offer settings that affect only a specific task, you can provide these options within the task itself, so people don’t have to leave the experience to customize it.

#### Best practices

**Aim to provide default settings that give the best experience to the largest number of people.** For example, you can automatically maximize performance for the device your game is running on instead of asking players to make this choice after your game launches (for developer guidance, see Improving your game’s graphics performance and settings). When you choose appropriate default settings, people may not have to make any adjustments before they can start enjoying your app or game.

**Minimize the number of settings you offer.** Although people appreciate having control over an app or game, too many settings can make the experience feel less approachable, while also making it hard to find a particular setting.

**Make settings available in ways people expect.** For example, when a physical keyboard is connected, people often use the standard Command-Comma (,) keyboard shortcut to open an app’s settings, whereas in a game, players often use the Esc (Escape) key.

**Avoid using settings to ask for setup information you can get in other ways.** For example, a game can automatically detect a connected controller or accessory instead of asking the player to identify it; an app can detect whether people are currently using Dark Mode.

**Respect people’s systemwide settings and avoid including redundant versions of them in your custom settings area.** People expect to use the system-provided Settings app to manage global options like accessibility accommodations, scrolling behavior, and authentication methods, and they expect all apps and games to adhere to their choices. Including custom versions of global options in your settings area is likely to confuse people because it implies that systemwide settings may not apply to your app or game and that changing your custom version of a global setting may affect other apps and games, too.

#### General settings

**Put general, infrequently changed settings in your custom settings area.** People must suspend what they’re doing to open an app’s or game’s settings area, so you want to include options that people don’t need to change all the time. For example, an app might list options for adjusting window configuration; a game might let players specify game-saving behavior or keyboard mappings; both apps and games might offer options related to people’s accounts.

#### Task-specific options

**When possible, prefer letting people modify task-specific options without going to your settings area.** For example, if people can adjust things like showing or hiding parts of the current view, reordering a collection of items, or filtering a list, make these options available in the screens they affect, where they’re discoverable and convenient. Putting this type of option in a separate settings area disconnects it from its context, requiring people to suspend their task to make adjustments, and often hiding the results until people resume the task.

> 
In games, players tend to adjust their approach to a specific task as part of the gameplay, not as a settings option to change.

#### System settings

**Add only the most rarely changed options to the system-provided Settings app.** If it makes sense to add your app’s or game’s settings to the system-provided Settings app, consider providing a button that opens it directly from your interface.

#### Platform considerations

*No additional considerations for iOS, iPadOS, tvOS, or visionOS.*

#### macOS

When people choose the Settings item in your app’s or game’s App menu, your custom settings window opens. Typically, a custom settings window contains a toolbar that includes buttons for switching between views — called *panes* — that each contain a group of related settings.

**Include a settings item in the App menu.** Avoid adding settings buttons to a window’s toolbar, because doing so decreases the space available for essential commands that people use frequently. If you provide document-level options, add this item to your app’s File menu.

**Dim a settings window’s minimize and maximize buttons.** It’s quick to open a custom settings window using the standard Command–Comma (,) keyboard command, so there’s no need to keep the window in the Dock, and because a settings window accommodates the size of the current pane, people don’t need to expand the window to see more.

**In your settings window, use a noncustomizable toolbar that remains visible and always indicates the active toolbar button.** A settings window’s toolbar identifies the areas people can customize and helps people navigate among those areas. People rely on a stable settings interface to help them find what they need.

**Update the window’s title to reflect the currently visible pane.** If your settings window doesn’t have multiple panes, use the title *App Name* Settings.

**Restore the most recently viewed pane.** People often adjust related settings more than once, so it can be convenient when a settings window opens to the last pane people used.

#### watchOS

In watchOS, apps and games don’t add custom settings to the system-provided Settings app. As an alternative, consider making a small number of essential options available at the bottom of the main view or letting people use a More menu to reconfigure objects.

#### Resources

##### Related

Onboarding

##### Developer documentation

Settings — SwiftUI

UserDefaults — Foundation

Preference Panes

#### Change log

| 
Date
 | 
Changes
 | 
| 
June 10, 2024
 | 
Reorganized some guidance into new topics and added game-specific examples.
 | 

---

## HIG: Launching

Source: https://developer.apple.com/design/human-interface-guidelines/launching

Launching begins when someone opens your app or game, includes an initial download, and ends when the first screen is ready. After launching completes, you might offer an Onboarding experience, which can give people a high-level view of your app or game.

#### Best practices

**Launch instantly.** People want to start interacting with your app or game right away, and sometimes they don’t want to wait more than a couple of seconds.

**If the platform requires it, provide a launch screen.** In iOS, iPadOS, and tvOS, the system displays your launch screen the moment your app or game starts and quickly replaces it with your first screen, giving people the impression that your experience is fast and responsive. For guidance, see Launch screens. macOS, visionOS, and watchOS don’t require launch screens.

**If you need a splash screen, consider displaying it at the beginning of your onboarding flow.** A splash screen is a beautiful graphic that succinctly communicates branding and other information you need to provide. If you don’t provide an onboarding experience, you might display your splash screen as soon as launching completes.

**Restore the previous state when your app restarts so people can continue where they left off.** Avoid making people retrace steps to reach their previous location in your app or game. Restore granular details of the previous state as much as possible. For example, scroll the view to people’s most recent position, and display windows in the same state and location in which people left them.

#### Launch screens

*Not applicable for macOS, visionOS, or watchOS.*

**Downplay the launch experience.** A launch screen isn’t part of an onboarding experience or a splash screen, and it isn’t an opportunity for artistic expression. A launch screen’s sole function is to enhance the perception of your experience as quick to launch and immediately ready to use.

**Design a launch screen that’s nearly identical to the first screen of your app or game.** If you include elements that look different when launching completes, people may experience an unpleasant flash between the launch screen and your first screen. If your app or game displays a solid color before transitioning to the first screen, create a launch screen that displays only that solid color. Also make sure that your launch screen matches the device’s current orientation and appearance mode.

**Avoid including text on your launch screen, even if your first screen displays text.** Because the content in a launch screen doesn’t change, any text you display won’t be localized.

**Don’t advertise.** The launch screen isn’t a branding opportunity. Avoid creating a screen that looks like a splash screen or an “About” window, and don’t include logos or other branding elements unless they’re a fixed part of your app’s first screen.

#### Platform considerations

*No additional considerations for macOS or watchOS.*

#### iOS, iPadOS

**Launch in the appropriate orientation.** If your app or game supports both portrait and landscape modes, launch using the device’s current orientation. If your interface only runs in one orientation, launch in that orientation and let people rotate the device if necessary. Ensure a landscape-only interface responds correctly, regardless of whether people enter landscape orientation by rotating the device left or right. For guidance, see Layout.

#### tvOS

> 
Unlike the Layered images throughout much of a tvOS app, the launch screen is static.

**In a live-viewing app, consider automatically starting playback soon after people start the app.** People come to your app to watch TV, so you might want to start playing new or recently viewed live content after a few seconds of inactivity. For guidance, see Live-viewing apps.

#### visionOS

**Consider launching in the Shared Space even if your app is fully immersive.** Opening a window in the Shared Space lets you provide more context about your app or game while giving it time to load, and it also lets you present a control that people can use to open your fully immersive experience. In general, people appreciate being able to choose when to transition to a Full Space, especially if they’re currently running other apps in the Shared Space. For guidance, see Immersive experiences.

#### Resources

##### Related

Onboarding

Loading

##### Developer documentation

Specifying your app’s launch screen — Xcode

Responding to the launch of your app — UIKit

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
June 10, 2024
 | 
Added guidance on displaying a splash screen.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 

---

## HIG: Privacy

Source: https://developer.apple.com/design/human-interface-guidelines/privacy

People use their devices in very personal ways and they expect apps to help them preserve their privacy.

When you submit a new or updated app, you must provide details about your privacy practices and the privacy-relevant data you collect so the App Store can display the information on your product page. (You can manage this information at any time in App Store Connect.) People use the privacy details on your product page to make an informed decision before they download your app. To learn more, see App privacy details on the App Store.

#### Best practices

**Request access only to data that you actually need.** Asking for more data than a feature needs — or asking for data before a person shows interest in the feature — can make it hard for people to trust your app. Give people precise control over their data by making your permission requests as specific as possible.

**Be transparent about how your app collects and uses people’s data.** People are less likely to be comfortable sharing data with your app if they don’t understand exactly how you plan to use it. Always respect people’s choices to use system features like Hide My Email and Mail Privacy Protection, and be sure you understand your obligations with regard to app tracking. To learn more about Apple privacy features, see Privacy; for developer guidance, see User privacy and data use.

**Process data on the device where possible.** In iOS, for example, you can take advantage of the Apple Neural Engine and custom CreateML models to process the data right on the device, helping you avoid lengthy and potentially risky round trips to a remote server.

**Adopt system-defined privacy protections and follow security best practices.** For example, in iOS 15 and later, you can rely on CloudKit to provide encryption and key management for additional data types, like strings, numbers, and dates.

#### Requesting permission

Here are several examples of the things you must request permission to access:

- Personal data, including location, health, financial, contact, and other personally identifying information

- User-generated content like emails, messages, calendar data, contacts, gameplay information, Apple Music activity, HomeKit data, and audio, video, and photo content

- Protected resources like Bluetooth peripherals, home automation features, Wi-Fi connections, and local networks

- Device capabilities like camera and microphone

- In a visionOS app running in a Full Space, ARKit data, such as hand tracking, plane estimation, image anchoring, and world tracking

- The device’s advertising identifier, which supports app tracking

The system provides a standard alert that lets people view each request you make. You supply copy that describes why your app needs access, and the system displays your description in the alert. People can also view the description — and update their choice — in Settings > Privacy.

**Request permission only when your app clearly needs access to the data or resource.** It’s natural for people to be suspicious of a request for personal information or access to a device capability, especially if there’s no obvious need for it. Ideally, wait to request permission until people actually use an app feature that requires access. For example, you can use the Location button to give people a way to share their location after they indicate interest in a feature that needs that information.

**Avoid requesting permission at launch unless the data or resource is required for your app to function.** People are less likely to be bothered by a launch-time request when it’s obvious why you’re making it. For example, people understand that a navigation app needs access to their location before they can benefit from it. Similarly, before people can play a visionOS game that lets them bounce virtual objects off walls in their surroundings, they need to permit the game to access information about their surroundings.

**Write copy that clearly describes how your app uses the ability, data, or resource you’re requesting.** The standard alert displays your copy (called a *purpose string* or *usage description string*) after your app name and before the buttons people use to grant or deny their permission. Aim for a brief, complete sentence that’s straightforward, specific, and easy to understand. Use sentence case, avoid passive voice, and include a period at the end. For developer guidance, see Requesting access to protected resources and App Tracking Transparency.

| 

 | 
Example purpose string
 | 
Notes
 | 
| 

 | 
The app records during the night to detect snoring sounds.
 | 
An active sentence that clearly describes how and why the app collects the data.
 | 
| 

 | 
Microphone access is needed for a better experience.
 | 
A passive sentence that provides a vague, undefined justification.
 | 
| 

 | 
Turn on microphone access.
 | 
An imperative sentence that doesn’t provide any justification.
 | 

Here are several examples of the standard system alert:

#### Pre-alert screens, windows, or views

Ideally, the current context helps people understand why you’re requesting their permission. If it’s essential to provide additional details, you can display a custom screen or window before the system alert appears. The following guidelines apply to custom views that display before system alerts that request permission to access protected data and resources, including camera, microphone, location, contact, calendar, and tracking.

**Include only one button and make it clear that it opens the system alert.** People can feel manipulated when a custom screen or window also includes a button that doesn’t open the alert because the experience diverts them from making their choice. Another type of manipulation is using a term like “Allow” to title the custom screen’s button. If the custom button seems similar in meaning and visual weight to the allow button in the alert, people can be more likely to choose the alert’s allow button without meaning to. Use a term like “Continue” or “Next” to title the single button in your custom screen or window, clarifying that its action is to open the system alert.

**Don’t include additional actions in your custom screen or window.** For example, don’t provide a way for people to leave the screen or window without viewing the system alert — like offering an option to close or cancel.

#### Tracking requests

App tracking is a sensitive issue. In some cases, it might make sense to display a custom screen or window that describes the benefits of tracking. If you want to perform app tracking as soon as people launch your app, you must display the system-provided alert before you collect any tracking data.

**Never precede the system-provided alert with a custom screen or window that could confuse or mislead people.** People sometimes tap quickly to dismiss alerts without reading them. A custom messaging screen, window, or view that takes advantage of such behaviors to influence choices will lead to rejection by App Store review.

There are several prohibited custom-screen designs that will cause rejection. Some examples are offering incentives, displaying a screen or window that looks like a request, displaying an image of the alert, and annotating the screen behind the alert (as shown below). To learn more, see App Review Guidelines: 5.1.1 (iv).

#### Location button

In iOS, iPadOS, and watchOS, Core Location provides a button so people can grant your app temporary authorization to access their location at the moment a task needs it. A location button’s appearance can vary to match your app’s UI and it always communicates the action of location sharing in a way that’s instantly recognizable.

The first time people open your app and tap a location button, the system displays a standard alert. The alert helps people understand how using the button limits your app’s access to their location, and reminds them of the location indicator that appears when sharing starts.

After people confirm their understanding of the button’s action, simply tapping the location button gives your app one-time permission to access their location. Although each one-time authorization expires when people stop using your app, they don’t need to reconfirm their understanding of the button’s behavior.

> 
If your app has no authorization status, tapping the location button has the same effect as when a person chooses *Allow Once* in the standard alert. If people previously chose *While Using the App*, tapping the location button doesn’t change your app’s status. For developer guidance, see LocationButton (SwiftUI) and CLLocationButton (Swift).

**Consider using the location button to give people a lightweight way to share their location for specific app features.** For example, your app might help people attach their location to a message or post, find a store, or identify a building, plant, or animal they’ve encountered in their location. If you know that people often grant your app *Allow Once* permission, consider using the location button to help them benefit from sharing their location without having to repeatedly interact with the alert.

**Consider customizing the location button to harmonize with your UI.** Specifically, you can:

- Choose the system-provided title that works best with your feature, such as “Current Location” or “Share My Current Location.”

- Choose the filled or outlined location glyph.

- Select a background color and a color for the title and glyph.

- Adjust the button’s corner radius.

To help people recognize and trust location buttons, you can’t customize the button’s other visual attributes. The system also ensures a location button remains legible by warning you about problems like low-contrast color combinations or too much translucency. In addition to fixing such problems, you’re responsible for making sure the text fits in the button — for example, button text needs to fit without truncation at all accessibility text sizes and when translated into other languages.

> 
If the system identifies consistent problems with your customized location button, it won’t give your app access to the device location when people tap it. Although such a button can perform other app-specific actions, people may lose trust in your app if your location button doesn’t work as they expect.

#### Protecting data

Protecting people’s information is paramount. Give people confidence in your app’s security and help preserve their privacy by taking advantage of system-provided security technologies when you need to store information locally, authorize people for specific operations, and transport information across a network.

Here are some high-level guidelines.

**Avoid relying solely on passwords for authentication.** Where possible, use passkeys to replace passwords. If you need to continue using passwords for authentication, augment security by requiring two-factor authentication (for developer guidance, see Securing Logins with iCloud Keychain Verification Codes). To further protect access to apps that people keep logged in on their device, use biometric identification like Face ID, Optic ID, or Touch ID. For developer guidance, see Local Authentication.

**Store sensitive information in a keychain.** A keychain provides a secure, predictable user experience when handling someone’s private information. For developer guidance, see Keychain services.

**Never store passwords or other secure content in plain-text files.** Even if you restrict access using file permissions, sensitive information is much safer in an encrypted keychain.

**Avoid inventing custom authentication schemes.** If your app requires authentication, prefer system-provided features like passkeys, Sign in with Apple or Password AutoFill. For related guidance, see Managing accounts.

#### Platform considerations

*No additional considerations for iOS, iPadOS, tvOS, or watchOS.*

#### macOS

**Sign your app with a valid Developer ID.** If you choose to distribute your app outside the store, signing your app with Developer ID identifies you as an Apple developer and confirms that your app is safe to use. For developer guidance, see Xcode Help.

**Protect people’s data with app sandboxing.** Sandboxing provides your app with access to system resources and user data while protecting it from malware. All apps submitted to the Mac App Store require sandboxing. For developer guidance, see Configuring the macOS App Sandbox.

**Avoid making assumptions about who is signed in.** Because of fast user switching, multiple people may be active on the same system.

#### visionOS

By default, visionOS uses ARKit algorithms to handle features like persistence, world mapping, segmentation, matting, and environment lighting. These algorithms are always running, allowing apps and games to automatically benefit from ARKit while in the Shared Space.

ARKit doesn’t send data to apps in the Shared Space; to access ARKit APIs, your app must open a Full Space. Additionally, features like Plane Estimation, Scene Reconstruction, Image Anchoring, and Hand Tracking require people’s permission to access any information. For developer guidance, see Setting up access to ARKit data.

In visionOS, user input is private by design. The system automatically displays hover effects when people look at interactive components you create using SwiftUI or RealityKit, giving people the visual feedback they need without exposing where they’re looking before they tap. For guidance, see Eyes and visionOS.

Developer access to device cameras works differently in visionOS than it does in other platforms. Specifically, the back camera provides blank input and is only available as a compatibility convenience; the front camera provides input for visionOS, but only after people grant their permission. If the iOS or iPadOS app you’re bringing to visionOS includes a feature that needs camera access, remove it or replace it with an option for people to import content instead. For developer guidance, see Making your existing app compatible with visionOS.

#### Resources

##### Related

Entering data

Onboarding

##### Developer documentation

Requesting access to protected resources — UIKit

Security

Requesting authorization to use location services — CoreLocation

App Tracking Transparency

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
June 21, 2023
 | 
Consolidated guidance into new page and updated for visionOS.
 | 

---

## HIG: Writing

Source: https://developer.apple.com/design/human-interface-guidelines/writing

Whether you’re building an onboarding experience, writing an alert, or describing an image for accessibility, designing through the lens of language will help people get the most from your app or game.

#### Getting started

**Determine your app’s voice.** Think about who you’re talking to, so you can figure out the type of vocabulary you’ll use. What types of words are familiar to people using your app? How do you want people to feel? The words for a banking app might convey trust and stability, for example, while the words in a game might convey excitement and fun. Create a list of common terms, and reference that list to keep your language consistent. Consistent language, along with a voice that reflects your app’s values, helps everything feel more cohesive.

**Match your tone to the context.** Once you’ve established your app’s voice, vary your tone based on the situation. Consider what people are doing while they’re using your app — both in the physical world and within the app itself. Are they exercising and reached a goal? Or are they trying to make a payment and received an error? Situational factors affect both what you say and how you display the text on the screen.

Compare the tone of these two examples from Apple Watch. In the first, the tone is straightforward and direct, reflecting the seriousness of the situation. In the second, the tone is light and congratulatory.

**Be clear.** Choose words that are easily understood and convey the right thing. Check each word to be sure it needs to be there. If you can use fewer words, do so. When in doubt, read your writing out loud.

**Write for everyone.** For your app to be useful for as many people as possible, it needs to speak to as many people as possible. Choose simple, plain language and write with accessibility and localization in mind, avoiding jargon and gendered terminology. For guidance, see Writing inclusively and VoiceOver; for developer guidance, see Localization.

#### Best practices

**Consider each screen’s purpose**. Pay attention to the order of elements on a screen, and put the most important information first. Format your text to make it easy to read. If you’re trying to convey more than one idea, consider breaking up the text onto multiple screens, and think about the flow of information across those screens.

**Be action oriented.** Active voice and clear labels help people navigate through your app from one step to the next, or from one screen to another. When labeling buttons and links, it’s almost always best to use a verb. Prioritize clarity and avoid the temptation to be too cute or clever with your labels. For example, just saying “Send” often works better than “Let’s do it!” For links, avoid using “Click here” in favor of more descriptive words or phrases, such as “Learn more about UX Writing.” This is especially important for people using screen readers to access your app.

**Build language patterns.** Consistency builds familiarity, helping your app feel cohesive, intuitive, and thoughtfully designed. It also makes writing for your app easier, as you can return to these patterns again and again.

**Adopt capitalization rules that align with your app’s style, then apply them consistently.** While certain components, like Content, have specific guidelines, how you format text reflects your app’s voice. Title case is generally considered formal, while sentence case is more casual. Choose a style for each UI element type and use it consistently throughout your app — for example, title case for all alerts or sentence case for all headlines.

**Give clear guidance and use consistent language throughout processes with multiple steps.** If your app has a flow that spans multiple screens, decide how you want to label the actions that take people from one step to the next. Begin with language like “Get Started” to indicate you’re starting a flow. You can use the button label to hint at the next step, or use terms like “Continue” or “Next,” but be consistent with what you choose. Make it clear when a flow is complete by using language like “Done.”

**Use possessive pronouns sparingly.** Possessive pronouns like *my* and *your* are often unnecessary to establish context. For example, “Favorites” conveys the same message as “Your Favorites,” and is more succinct. If you do use possessive pronouns, use them consistently throughout your app, and try not to switch perspectives. Avoid using *we* altogether because it may be unclear who the “we” in question refers to. This is particularly problematic in error messages like “We’re having trouble loading this content.” Something like “Unable to load content” is much clearer.

**Write for how people use each device.** People may use your app on several types of devices. While your language needs to be consistent across them, think about where it would be helpful to adjust your text to make it suitable for different devices. Make sure you describe gestures correctly on each device — for example, not saying “click” for a touch device like iPhone or iPad where you mean “tap.”

Where and how people use a device, its screen size, and its location all affect how you write for your app. iPhone and Apple Watch, for example, offer opportunities for personalization, but their small screens require brevity. TVs, on the other hand, are often in common living spaces, and several people are likely to see anything on the screen, so consider who you’re addressing. Bigger screens also require brevity, as the text must be large for people to see it from a distance.

**Provide clear next steps on any blank screens.** An empty state, like a completed to-do list or bookmarks folder with nothing in it, can provide a good opportunity to make people feel welcome and educate them about your app. Empty states can also showcase your app’s voice, but make sure that the content is useful and fits the context. An empty screen can be daunting if it isn’t obvious what to do next, so guide people on actions they can take, and give them a button or link to do so if possible. Remember that empty states are usually temporary, so don’t show crucial information that could then disappear.

**Write clear error messages.** It’s always best to help people avoid errors. When an error message is necessary, display it as close to the problem as possible, avoid blame, and be clear about what someone can do to fix it. For example, “That password is too short” isn’t as helpful as “Choose a password with at least 8 characters.” Remember that errors can be frustrating. Interjections like “oops!” or “uh-oh” are typically unnecessary and can sound insincere. If you find that language alone can’t address an error that’s likely to affect many people, use that as an opportunity to rethink the interaction.

**Choose the right delivery method.** There are many ways to get people’s attention, whether or not they are actively using your app. When there’s something you want to communicate, consider the urgency and importance of the message. Think about the context in which someone might see the message, whether it requires immediate action, and how much supporting information someone might need. Choose the correct delivery method, and use a tone appropriate for the situation. For guidance, see Notifications, Alerts, and Action sheets.

**Keep settings labels clear and simple.** Help people easily find the settings they need by labeling them as practically as possible. If the setting label isn’t enough, add an explanation. Describe what it does when turned on, and people can infer the opposite. In the Handwashing Timer setting for Apple Watch, for example, the description explains that a timer can start when you’re washing your hands. It isn’t necessary to tell you that a timer won’t start when this setting is off.

If you need to direct someone to a setting, provide a direct link or button, rather than trying to describe its location. For guidance, see Settings.

**Show hints in text fields.** If your app allows people to enter their own text, like account or contact information, label all fields clearly, and use hint or placeholder text so people know how to format the information. You can give an example in hint text, like “name@example.com,” or describe the information, such as “Your name.” Show errors right next to the field, and instruct people how to enter the information correctly, rather than scolding them for not following the rules. “Use only letters for your name” is better than “Don’t use numbers or symbols.” Avoid robotic error messages with no helpful information, like “Invalid name.” For guidance, see Text fields.

#### Platform considerations

*No additional considerations for iOS, iPadOS, macOS, tvOS, visionOS, or watchOS.*

#### Resources

##### Related

Apple Style Guide

Writing inclusively

Inclusion

Accessibility

Color

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
December 16, 2025
 | 
Clarified guidance on language patterns, and added guidance for possessive pronouns.
 | 
| 
February 27, 2023
 | 
New page.
 | 

---

## HIG: Web views

Source: https://developer.apple.com/design/human-interface-guidelines/web-views

For example, Mail uses a web view to show HTML content in messages.

#### Best practices

**Support forward and back navigation when appropriate.** Web views support forward and back navigation, but this behavior isn’t available by default. If people are likely to use your web view to visit multiple pages, allow forward and back navigation, and provide corresponding controls to initiate these features.

**Avoid using a web view to build a web browser.** Using a web view to let people briefly access a website without leaving the context of your app is fine, but Safari is the primary way people browse the web. Attempting to replicate the functionality of Safari in your app is unnecessary and discouraged.

#### Platform considerations

*No additional considerations for iOS, iPadOS, macOS, or visionOS. Not supported in tvOS or watchOS.*

#### Resources

##### Related

Webkit.org

##### Developer documentation

WKWebView — WebKit

##### Videos

---

## HIG: App icons

Source: https://developer.apple.com/design/human-interface-guidelines/app-icons

Your app icon is a crucial aspect of your app’s or game’s branding and user experience. It appears on the Home Screen and in key locations throughout the system, including search results, notifications, system settings, and share sheets. A well-designed app icon conveys your app’s or game’s identity clearly and consistently across all Apple platforms.

#### Layer design

Although you can provide a flattened image for your icon, layers give you the most control over how your icon design is represented. A layered app icon comes together to produce a sense of depth and vitality. On each platform, the system applies visual effects that respond to the environment and people’s interactions.

iOS, iPadOS, macOS, and watchOS app icons include a background layer and one or more foreground layers that coalesce to create dimensionality. These icons take on Liquid Glass attributes like specular highlights, refraction, and translucency. These effects automatically adapt with the size of your icon, apply consistently across platforms, and can appear differently between system versions.

tvOS app icons use between two and five layers to create a sense of dynamism as people bring them into focus. When focused, the app icon elevates to the foreground in response to someone’s finger movement on their remote, and gently sways while the surface illuminates. The separation between layers and the use of transparency produce a feeling of depth during the parallax effect.

A visionOS app icon includes a background layer and one or two layers on top, producing a three-dimensional object that subtly expands when people view it. The system enhances the icon’s visual dimensionality by adding shadows that convey a sense of depth between layers and by using the alpha channel of the upper layers to create an embossed appearance.

You use your favorite design tool to craft the individual foreground layers of your app icon. For iOS, iPadOS, macOS, and watchOS icons, you then import your icon layers into Icon Composer, a design tool included with Xcode and available from the Apple Developer website. In Icon Composer, you define the background layer for your icon, adjust your foreground layer placement, apply visual effects like specular highlights and refraction, annotate for default, dark, and mono appearance variants, test and preview your icon across system versions, and export your icon for use in Xcode. For additional guidance, see Creating your app icon using Icon Composer.

For tvOS and visionOS app icons, you add your icon layers directly to an image stack in Xcode to form your complete icon. You can download Parallax Previewer and Parallax Exporter plug-in from Apple Design Resources to preview and test parallax visual effects. For developer guidance, see Configuring your app icon using an asset catalog.

**Prefer clearly defined edges in foreground layers.** To ensure system-drawn highlights and shadows look best, avoid soft and feathered edges on foreground layer shapes.

**Vary opacity in foreground layers to increase the sense of depth and liveliness.** For example, the Photos icon separates its centerpiece into multiple layers that contain translucent pieces, bringing greater dynamism to the design. Importing fully opaque layers and adjusting transparency in Icon Composer lets you preview and make adjustments to your design based on how transparency and system effects impact one another.

**Design a background that both stands out and emphasizes foreground content.** If you choose a gradient for your background layer, ensure that it responds well to system lighting effects. Icon Composer supports solid colors and gradients for background layers, making it unnecessary to import custom background images in most cases. If you do import a background layer, make sure it’s full-bleed and opaque.

**Prefer vector graphics when bringing layers into Icon Composer.** Unlike raster images, vector graphics (such as SVG or PDF) scale gracefully and appear crisp at any size. Outline artwork and convert text to outline in your design. For mesh gradients and raster artwork, prefer PNG format because it’s a lossless image format.

#### Icon shape

An app icon’s shape varies based on a platform’s visual language. In iOS, iPadOS, and macOS, icons are square, and the system applies masking to produce rounded corners that precisely match the curvature of other rounded interface elements throughout the system and the bezel of the physical device itself. In tvOS, icons are rectangular, also with concentric edges. In visionOS and watchOS, icons are square and the system applies circular masking.

**Produce appropriately shaped, unmasked layers.** The system masks all layer edges to produce an icon’s final shape. For iOS, iPadOS, and macOS icons, provide square layers so the system can apply rounded corners. For visionOS and watchOS, provide square layers so the system can create the circular icon shape. For tvOS, provide rectangular layers so the system can apply rounded corners. Providing layers with pre-defined masking negatively impacts specular highlight effects and makes edges look jagged.

**Keep primary content centered to avoid truncation when the system adjusts corners or applies masking.** Pay particular attention to centering content in visionOS and watchOS icons. To help with icon placement, use the grids in the app icon production templates, which you can find in Apple Design Resources.

#### Design

Embrace simplicity in your icon design. Simple icons tend to be easiest for people to understand and recognize. An icon with fine visual features might look busy when rendered with system-provided shadows and highlights, and details may be hard to discern at smaller sizes. Find a concept or element that captures the essence of your app or game, make it the core idea of your icon, and express it in a simple, unique way with a minimal number of shapes. Prefer a simple background, such as a solid color or gradient, that puts the emphasis on your primary design — you don’t need to fill the entire icon canvas with content.

**Provide a visually consistent icon design across all the platforms your app supports.** A consistent design helps people quickly find your app wherever it appears and prevents people from mistaking your app for multiple apps.

**Consider basing your icon design around filled, overlapping shapes.** Overlapping solid shapes in the foreground, particularly when paired with transparency and blurring, can give an icon a sense of depth.

**Include text only when it’s essential to your experience or brand.** Text in icons doesn’t support accessibility or localization, is often too small to read easily, and can make an icon appear cluttered. In some contexts, your app name already appears nearby, making it redundant to display the name within the icon itself. Although displaying a mnemonic like the first letter of your app’s name can help people recognize your app or game, avoid including nonessential words that tell people what to do with it — like “Watch” or “Play” — or context-specific terms like “New” or “For visionOS.” If you include text in a tvOS app icon, make sure it’s above other layers so it’s not cropped by the parallax effect.

**Prefer illustrations to photos and avoid replicating UI components.** Photos are full of details that don’t work well when displayed in different appearances, viewed at small sizes, or split into layers. Instead of using photos, create a graphic representation of the content that emphasizes the features you want people to notice. Make sure to avoid extremely thin line weights and sharp corners, because they tend to lose detail and crispness in smaller icon sizes at lower resolutions. If your app has an interface that people recognize, don’t just replicate standard UI components or use app screenshots in your icon.

**Don’t use replicas of Apple hardware products.** Apple products are copyrighted and can’t be reproduced in your app icons.

#### Visual effects

**Let the system handle blurring and other visual effects.** The system dynamically applies visual effects to your app icon layers, so there’s no need to include specular highlights, drop shadows between layers, beveled edges, blurs, glows, and other effects. In addition to interfering with system-provided effects, custom effects are static, whereas the system supplies dynamic ones. If you do include custom visual effects on your icon layers, use them intentionally and test carefully with Icon Composer, on a simulated device in Device Hub, or on a physical device to make sure they appear as expected and don’t conflict with system effects.

**Create layer groupings to apply effects to multiple layers at once.** System effects typically occur on individual layers. If it makes sense for your design, however, you can group several layers together in Icon Composer or your design tool so effects occur at the group level. For a group, Icon Composer provides additional customization options for Liquid Glass effects, so you can configure attributes like specular highlights, refraction, and translucency.

#### Appearances

In iOS, iPadOS, and macOS, people can choose whether their Home Screen app icons are default, dark, clear, or tinted in appearance. For example, someone may want to personalize their app icon appearance to complement their wallpaper. You can design app icon variants for every appearance variant, and the system automatically generates variants you don’t provide.

**Keep your icon’s features consistent across appearances.** To create a seamless experience, keep your icon’s core visual features the same in the default, dark, clear, and tinted appearances. Avoid creating custom icon variants that swap elements in and out with each variant, which may make it harder for people to find your app when they switch appearances.

**Design dark and tinted icons that feel at home beside system app icons and widgets.** You can preserve the color palette of your default icon, but be mindful that dark icons are more subdued, and clear and tinted icons are even more so. A great app icon is visible, legible, and recognizable, regardless of its appearance variant.

**Use your light app icon as the basis for your dark icon.** Choose complementary colors that reflect the default design, and avoid excessively bright images. Color backgrounds generally offer the greatest contrast in dark icons. For guidance, see Dark Mode.

**Consider offering alternate app icons.** In iOS, iPadOS, tvOS, and compatible apps running in visionOS, it’s possible to let people visit your app’s settings to choose an alternate version of your app icon. For example, a sports app might offer icons for different teams, letting someone choose their favorite. If you offer this capability, make sure each icon you design remains closely related to your content and experience. Avoid creating one someone might mistake for another app.

> 
Alternate app icons in iOS and iPadOS require their own dark, clear, and tinted variants. As with your default app icon, all alternate and variant icons are subject to app review and must adhere to the App Review Guidelines.

#### Platform considerations

*No additional considerations for iOS, iPadOS, or macOS.*

#### tvOS

**Include a safe zone to ensure the system doesn’t crop your content.** When someone focuses your app icon, the system may crop content around the edges as the icon scales and moves. To ensure that your icon’s content is always visible, keep a safe zone around it. Be aware that the safe zone can vary, depending on the image size, layer depth, and motion, and the system crops foreground layers more than background layers.

#### visionOS

**Avoid adding a shape that’s intended to look like a hole or concave area to the background layer.** The system-added shadow and specular highlights can make such a shape stand out instead of recede.

#### watchOS

**Avoid using black for your icon’s background.** Lighten a black background so the icon doesn’t blend into the display background.

#### Specifications

The layout, size, style, and appearances of app icons vary by platform.

| 
Platform
 | 
Layout shape
 | 
Icon shape after system masking
 | 
Layout size
 | 
Style
 | 
Appearances
 | 
| 
iOS, iPadOS, macOS
 | 
Square
 | 
Rounded rectangle (square)
 | 
1024x1024 px
 | 
Layered
 | 
Default, dark, clear light, clear dark, tinted light, tinted dark
 | 
| 
tvOS
 | 
Rectangle (landscape)
 | 
Rounded rectangle (rectangular)
 | 
800x480 px
 | 
Layered (Parallax)
 | 
N/A
 | 
| 
visionOS
 | 
Square
 | 
Circular
 | 
1024x1024 px
 | 
Layered (3D)
 | 
N/A
 | 
| 
watchOS
 | 
Square
 | 
Circular
 | 
1088x1088 px
 | 
Layered
 | 
N/A
 | 

The system automatically scales your icon to produce smaller variants that appear in certain locations, such as Settings and notifications.

App icons support the following color spaces:

- sRGB (color)

- Gray Gamma 2.2 (grayscale)

- Display P3 (wide-gamut color in iOS, iPadOS, macOS, tvOS, and watchOS only)

#### Resources

##### Related

Apple Design Resources

Icon Composer

Icons

Images

Dark Mode

##### Developer documentation

Creating your app icon using Icon Composer

Configuring your app icon using an asset catalog

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
June 8, 2026
 | 
Refined guidance for Liquid Glass.
 | 
| 
June 9, 2025
 | 
Updated guidance to reflect layered icons, consistency across platforms, and best practices for Liquid Glass.
 | 
| 
June 10, 2024
 | 
Added guidance for creating dark and tinted app icon variants for iOS and iPadOS.
 | 
| 
January 31, 2024
 | 
Clarified platform availability for alternate app icons.
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 
| 
September 14, 2022
 | 
Added specifications for Apple Watch Ultra.
 | 

---

## HIG: Branding

Source: https://developer.apple.com/design/human-interface-guidelines/branding

In addition to expressing your brand in your app icon and throughout your experience, you have several opportunities to highlight it within the App Store. For guidance, see App Store Marketing Guidelines.

#### Best practices

**Use your brand’s unique voice and tone in all the written communication you display.** For example, your brand might convey feelings of encouragement and optimism by using plain words, occasional exclamation marks and emoji, and simple sentence structures.

**Apply your app’s accent color judiciously.** Using your brand color too broadly can overwhelm your interface and dilute its impact. Minimize its use on controls and instead use it intentionally for primary actions or status indicators, like badges for unread content or an icon for the selected tab in a tab bar. To express your brand through color, consider moving it into the content layer, where it scrolls beneath Liquid Glass controls and gets picked up dynamically. For guidance, see Color.

**Consider using a custom font.** If your brand is strongly associated with a specific font, be sure that it’s legible at all sizes and supports accessibility features like bold text and Dynamic Type. It can work well to use a custom font for headlines and subheadings while using system fonts for body copy and captions, because the system fonts are designed for optimal legibility at small sizes. For guidance, see Typography.

**Express your brand with familiar components.** When you use components that people already know, the experience feels immediately reliable and familiar, and people can focus on the unique content and features that make your app stand apart. If you need to customize a component’s appearance to reflect your brand, ensure that details like sizing, placement, and behavior continue to preserve a familiar experience that’s appropriate for the platform.

**Ensure branding always defers to content.** Using screen space for an element that does nothing but display a brand asset can mean there’s less room for the content people care about. Aim to incorporate branding in refined, unobtrusive ways that don’t distract people from your experience.

**Help people feel comfortable by using standard patterns consistently.** Even a highly stylized interface can be approachable if it maintains familiar behaviors and patterns. Place UI in expected locations, use standard symbols to represent common actions, and rely on established conventions for navigation and modality.

**Resist the temptation to display your logo throughout your app or game unless it’s essential for providing context.** People seldom need to be reminded which app they’re using, and it’s usually better to use the space to give people valuable information and controls.

**Avoid using a launch screen as a branding opportunity.** Some platforms use a launch screen to minimize the startup experience, while simultaneously giving the app or game a little time to load resources (for guidance, see Launch screens). A launch screen disappears too quickly to convey any information, but you might consider displaying a welcome or onboarding screen that incorporates your branding content at the beginning of your experience. For guidance, see Onboarding.

**Follow Apple’s trademark guidelines.** Apple trademarks must not appear in your app name or images. See Apple Trademark List and Guidelines for Using Apple Trademarks.

#### Platform considerations

*No additional considerations for iOS, iPadOS, macOS, tvOS, visionOS, or watchOS.*

#### Resources

##### Related

App Store Marketing Guidelines

Show more with app previews

Color

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
September 9, 2026
 | 
Refined guidance for using brand color.
 | 

---

## HIG: Entering data

Source: https://developer.apple.com/design/human-interface-guidelines/entering-data

Entering information can be a tedious process regardless of the interaction methods people use. Improve the experience by:

- Pre-gathering as much information as possible to minimize the amount of data that people need to supply

- Supporting all available input methods so people can choose the method that works for them

#### Best practices

**Get information from the system whenever possible.** Don’t ask people to enter information that you can gather automatically — such as from settings — or by getting their permission, such as their location or calendar information.

**Be clear about the data you need.** For example, you might display a prompt in a text field — like “username@company.com” — or provide an introductory label that describes the information, like “Email.” You can also prefill fields with reasonable default values, which can minimize decision making and speed data entry.

**Use a secure text-entry field when appropriate.** If your app or game needs sensitive data, use a field that obscures people’s input as they enter it, typically by displaying a small filled circle symbol for each character. For developer guidance, see SecureField. In tvOS, you can also configure a digit entry view to obscure the numerals people enter (for developer guidance, see isSecureDigitEntry). When you use the system-provided text field in visionOS, the system shows the entered data to the wearer, but not to anyone else; for example, a secure text field automatically blurs when people use AirPlay to stream their content.

**Never prepopulate a password field.** Always ask people to enter their password or use biometric or keychain authentication. For guidance, see Managing accounts.

**When possible, offer choices instead of requiring text entry.** It’s usually easier and more efficient to choose from lists of options than to type information, even when a keyboard is conveniently available. When it makes sense, consider using a picker, menu, or other selection component to give people an easy way to provide the information you need.

**As much as possible, let people provide data by dragging and dropping it or by pasting it.** Supporting these interactions can ease data entry and make your experience feel more integrated with the rest of the system.

**Dynamically validate field values.** People can get frustrated when they have to go back and correct mistakes after filling out a lengthy form. When you verify values as soon as people enter them — and provide feedback as soon as you detect a problem — you give them the opportunity to correct errors right away. For numeric data in particular, consider using a number formatter, which automatically configures a text field to accept only numeric values. You can also configure a formatter to display the value in a specific way, such as with a certain number of decimal places, as a percentage, or as currency.

**When data entry is necessary, make sure people understand that they must provide the required data before they can proceed.** For example, if you include a Next or Continue button after a set of text fields, make the button available only after people enter the data you require.

#### Platform considerations

*No additional considerations for iOS, iPadOS, tvOS, visionOS, or watchOS.*

#### macOS

**Consider using an expansion tooltip to show the full version of clipped or truncated text in a field.** An *expansion tooltip* behaves like a regular tooltip, appearing when the pointer rests on top of a field. Apps running in macOS — including iOS and iPadOS apps running on a Mac — can use an expansion tooltip to help people view the complete data they entered when a text field is too small to display it. For guidance, see Offering help > macOS, visionOS.

#### Resources

##### Related

Text fields

Virtual keyboards

Keyboards

##### Developer documentation

Input events — SwiftUI

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
June 21, 2023
 | 
Updated to include guidance for visionOS.
 | 

---

## HIG: Offering help

Source: https://developer.apple.com/design/human-interface-guidelines/offering-help

#### Best practices

**Let your app’s tasks inform the types of help people might need.** For example, you might help people perform simple, one- or two-step tasks by displaying an inline view that succinctly describes the task. In contrast, if your app or game supports complex or multistep tasks you might want to provide a tutorial that teaches people how to accomplish larger goals. In general, directly relate the help you provide to the precise action or task people are doing right now and make it easy for people to dismiss or avoid the help if they don’t need it.

**Use relevant and consistent language and images in your help content.** Always make sure guidance is appropriate for the current context. For example, if someone’s using the Siri Remote with your tvOS experience, don’t show tips or images that feature a game controller. Also be sure the terms and descriptions you use are consistent with the platform. For example, don’t write copy that tells people to click a button on an iPhone or tap a menu item on a Mac.

**Make sure all help content is inclusive.** For guidance, see Inclusion.

**Avoid bloating your help content by explaining how standard components or patterns work.** Instead, describe the specific action or task that a standard element performs in your app or game. If your experience introduces a unique control or expects people to use an input device in a nonstandard way — such as holding the Siri Remote rotated 90 degrees — orient people quickly, preferring animation or graphics to educate instead of a lengthy description.

#### Creating tips

A tip is a small, transient view that briefly describes how to use a feature in your app. Tips are a great way to teach people about new or less obvious features in your app, or help them discover faster ways to accomplish a task. For developer guidance, see TipKit.

**Use the most appropriate tip type for your app’s user interface.** Display a popover tip when you want to preserve the content flow, or an inline tip when you want to ensure that surrounding information is visible. You can use an annotation-style inline tip when pointing to a specific UI element, or a hint-style tip when it’s not related to a specific piece of UI.

**Use tips for simple features.** Tips work best on features that are easy to describe and that people can complete with a few simple steps. If a feature requires more than three actions, it’s probably too complicated for a tip.

**Make tips short, actionable, and engaging.** A tip’s goal is to encourage people to try new features. Use direct, action-oriented language to describe what the feature does and explain how to use it. Keep your tips to one or two sentences and avoid including content that’s promotional or related to a different feature or user flow. Promotional content is anything that advertises, sells, or isn’t aligned with the current context of what the person is doing.

**Define rules to help ensure your tips reach the intended audience.** Not everyone benefits from every tip. For example, people who’ve already used a feature won’t appreciate viewing a tip that describes it. Use parameter-based or event-based eligibility rules to control when a tip appears, and only display a tip if someone might benefit from its use. When your app has more than one tip, set the display frequency so tips display at a reasonable cadence — for example, once every 24 hours.

**If there’s an image or symbol that people associate with the feature, consider including it in the tip, and prefer the filled variant.** For example, a tip with a star can help people understand that the tip is related to favorites.

If the feature is represented by an image that the tip connects to directly, avoid repeating the same image in both the tip and the UI.

**Use buttons to direct people to information or options.** If your feature has settings people can customize, or you want to redirect people to an area where they can learn more about a feature, consider adding a button. Buttons can take people directly to the settings where they make adjustments. Or if there’s more information people might find useful, add a button to take them to additional resources, such as a setup flow.

#### Platform considerations

*No additional considerations for iOS, iPadOS, tvOS, or watchOS.*

#### macOS, visionOS

A *tooltip* (called a *help tag* in user documentation) displays a small, transient view that briefly describes how to use a component in the interface. In apps that run on a Mac — including iPhone and iPad apps — tooltips can appear when a person holds the pointer over an element; in visionOS apps, a tooltip can appear when a person looks at an element or holds the pointer over it. For developer guidance, see help(_:).

**Describe only the control that people indicate interest in.** When people want to know how to use a specific control, they don’t want to learn how to use nearby controls or how to perform a larger task.

**Explain the action or task the control initiates.** It often works well to begin the description with a verb — for example, “Restore default settings” or “Add or remove a language from the list.”

**In general, avoid repeating a control’s name in its tooltip.** Repeating the name takes up space in the tooltip and rarely adds value to the description.

**Be brief.** As much as possible, limit tooltip content to a maximum of 60 to 75 characters (note that localization often changes the length of text). To make a description brief and direct, consider using a sentence fragment and omitting articles. If you need a lot of text to describe a control, consider simplifying your interface design.

**Use sentence case.** Sentence case tends to appear more casual and approachable. If you write complete sentences, omit ending punctuation unless it’s required to be consistent with your app’s style.

**Consider offering context-sensitive tooltips.** For example, you could provide different text for a control’s different states.

#### Resources

##### Related

Onboarding

Feedback

Writing

Help menu

##### Developer documentation

TipKit

NSHelpManager — AppKit

##### Videos

#### Change log

| 
Date
 | 
Changes
 | 
| 
December 5, 2023
 | 
Included visionOS in guidance for creating tooltips.
 | 
| 
September 12, 2023
 | 
Added guidance for creating tips.
 | 
