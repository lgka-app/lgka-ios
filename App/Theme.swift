import SwiftUI
import UIKit

/// Accent palette — mirrors ColorProvider (color_provider.dart).
enum Accent: String, CaseIterable {
    case blue, mint, lavender, rose, peach

    var color: Color {
        switch self {
        case .blue: return Color(red: 0x37 / 255, green: 0x70 / 255, blue: 0xD4 / 255)
        case .mint: return Color(red: 0x45 / 255, green: 0xA8 / 255, blue: 0x8A / 255)
        case .lavender: return Color(red: 0x9B / 255, green: 0x6B / 255, blue: 0xDF / 255)
        case .rose: return Color(red: 0xC4 / 255, green: 0x7A / 255, blue: 0x7A / 255)
        case .peach: return Color(red: 0xBF / 255, green: 0x7F / 255, blue: 0x46 / 255)
        }
    }
}

/// Theme surfaces — mirrors app_theme.dart (pure black dark / F2F2F7 light).
extension Color {
    static let darkBg = Color.black
    static let darkSurface = Color(red: 0x1E / 255, green: 0x1E / 255, blue: 0x1E / 255)
    static let lightBg = Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF7 / 255)
    static let lightSurface = Color.white
}

struct ThemeBg: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.background(
            (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea())
    }
}

struct SurfaceCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content.background(
            scheme == .dark ? Color.darkSurface : Color.lightSurface,
            in: RoundedRectangle(cornerRadius: radius))
    }
}

extension View {
    func themeBg() -> some View { modifier(ThemeBg()) }
    func surfaceCard(radius: CGFloat = 16) -> some View {
        modifier(SurfaceCard(radius: radius))
    }
}

/// Haptics — mirrors HapticService.
enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func intense() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
}

/// 44pt tinted icon square used across the home cards.
struct IconSquare: View {
    let systemName: String
    var alpha: Double = 0.12
    @Environment(\.appAccent) private var accent
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(accent)
            .frame(width: 44, height: 44)
            .background(accent.opacity(alpha), in: RoundedRectangle(cornerRadius: 12))
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
