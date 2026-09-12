import SwiftUI
import UIKit

/// Brand accent palette — mirrors ColorProvider (color_provider.dart).
/// See DESIGN_GUIDELINES.md for the contrast rules that go with it.
enum Accent: String, CaseIterable, Identifiable {
    case blue, mint, lavender, rose, peach

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return Color(red: 0x37 / 255, green: 0x70 / 255, blue: 0xD4 / 255)
        case .mint: return Color(red: 0x45 / 255, green: 0xA8 / 255, blue: 0x8A / 255)
        case .lavender: return Color(red: 0x9B / 255, green: 0x6B / 255, blue: 0xDF / 255)
        case .rose: return Color(red: 0xC4 / 255, green: 0x7A / 255, blue: 0x7A / 255)
        case .peach: return Color(red: 0xBF / 255, green: 0x7F / 255, blue: 0x46 / 255)
        }
    }

    /// Localized name for VoiceOver.
    var label: String { L.s("accent.\(rawValue)") }
}

/// Backgrounds use the system semantic colors so Liquid Glass bars, sheets
/// and scroll-edge effects blend correctly; the values match the brand
/// (pure black / #F2F2F7) in both appearances.
extension Color {
    static let appBackground = Color(uiColor: .systemGroupedBackground)
    static let appSurface = Color(uiColor: .secondarySystemGroupedBackground)
}

struct ThemeBg: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Color.appBackground.ignoresSafeArea())
    }
}

struct SurfaceCard: ViewModifier {
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content.background(Color.appSurface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func themeBg() -> some View { modifier(ThemeBg()) }
    func surfaceCard(radius: CGFloat = 16) -> some View {
        modifier(SurfaceCard(radius: radius))
    }
}

/// Haptics — mirrors HapticService. UIKit feedback generators are
/// main-actor only.
@MainActor
enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func intense() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

/// 44pt tinted icon square used across the home cards.
struct IconSquare: View {
    let systemName: String
    var alpha: Double = 0.12
    @Environment(\.appAccent) private var accent
    @ScaledMetric(relativeTo: .body) private var size = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.body.weight(.medium))
            .foregroundStyle(accent)
            .frame(width: size, height: size)
            .background(accent.opacity(alpha), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct AppAccentKey: EnvironmentKey {
    static let defaultValue: Color = Accent.blue.color
}

extension EnvironmentValues {
    var appAccent: Color {
        get { self[AppAccentKey.self] }
        set { self[AppAccentKey.self] = newValue }
    }
}

extension View {
    /// HIG Layout: on wide screens (iPad, landscape) content stays in a readable
    /// column instead of stretching edge to edge. Phones are narrower than the
    /// limit, so they are unaffected.
    func readableWidth(_ max: CGFloat = 760) -> some View {
        frame(maxWidth: max).frame(maxWidth: .infinity)
    }
}

extension View {
    /// Sheet sizing that follows the platform idiom: a resizable bottom sheet (half and full
    /// height) on iPhone, the native centered form sheet on iPad. Half-height stops are a
    /// phone pattern; on iPad they become a short floating card that cuts the content off.
    /// Decided by device, not size class: inside an iPad form sheet the size class reads
    /// compact, which would flip it back to detents. In narrow iPad multitasking the form
    /// sheet adapts to a regular sheet on its own.
    @ViewBuilder func adaptiveSheetSizing() -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            presentationSizing(.form)
        } else {
            presentationDetents([.medium, .large])
        }
    }
}

extension View {
    /// Tap haptic for controls SwiftUI drives itself (NavigationLink, ShareLink):
    /// fires alongside the control's own tap without swallowing it.
    func tapHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        simultaneousGesture(TapGesture().onEnded { UIImpactFeedbackGenerator(style: style).impactOccurred() })
    }
}
