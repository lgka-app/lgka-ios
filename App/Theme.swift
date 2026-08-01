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

/// WMO weather scene gradient — stands in for the Flutter animated WeatherBg.
enum WeatherScene {
    static func gradient(_ code: Int, isDay: Bool) -> LinearGradient {
        let colors: [Color]
        switch code {
        case 0, 1:
            colors = isDay
                ? [Color(red: 0.28, green: 0.6, blue: 0.95), Color(red: 0.12, green: 0.42, blue: 0.85)]
                : [Color(red: 0.08, green: 0.1, blue: 0.32), Color(red: 0.03, green: 0.04, blue: 0.15)]
        case 2, 3:
            colors = isDay
                ? [Color(red: 0.45, green: 0.55, blue: 0.65), Color(red: 0.3, green: 0.38, blue: 0.47)]
                : [Color(red: 0.14, green: 0.18, blue: 0.24), Color(red: 0.08, green: 0.1, blue: 0.14)]
        case 45, 48:
            colors = [Color(red: 0.55, green: 0.6, blue: 0.66), Color(red: 0.4, green: 0.45, blue: 0.5)]
        case 51...67, 80...82:
            colors = [Color(red: 0.25, green: 0.4, blue: 0.6), Color(red: 0.1, green: 0.2, blue: 0.38)]
        case 71...77, 85, 86:
            colors = [Color(red: 0.6, green: 0.7, blue: 0.85), Color(red: 0.4, green: 0.52, blue: 0.68)]
        case 95, 96, 99:
            colors = [Color(red: 0.2, green: 0.12, blue: 0.45), Color(red: 0.08, green: 0.05, blue: 0.2)]
        default:
            colors = [Color(red: 0.45, green: 0.55, blue: 0.65), Color(red: 0.3, green: 0.38, blue: 0.47)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

/// Skeleton placeholder — mirrors SkeletonCard.
struct SkeletonCard: View {
    @State private var pulse = false
    var height: CGFloat = 76
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.quaternary.opacity(pulse ? 0.5 : 0.9))
            .frame(height: height)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
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
