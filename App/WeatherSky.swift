import SwiftUI
import Vortex

/// GPU sky (Metal fbm cloud shader) + Vortex particle precipitation.
/// Replaces the hand-drawn Canvas sky.
struct WeatherSkyView: View {
    let code: Int
    let isDay: Bool
    /// Particle rain/snow overlay — on for the full page, off for small rows.
    var particles = true

    private var cloudiness: Double {
        switch code {
        case 0, 1: return 0.12
        case 2: return 0.5
        case 45, 48: return 0.95
        default: return 0.85
        }
    }

    private enum Precip { case none, rain, snow }
    private var precip: Precip {
        switch code {
        case 51...67, 80...82, 95, 96, 99: return .rain
        case 71...77, 85, 86: return .snow
        default: return .none
        }
    }

    var body: some View {
        ZStack {
            MetalSky(cloudiness: cloudiness, isDay: isDay)
            if particles {
                switch precip {
                case .rain:
                    VortexView(.rain) {
                        Circle()
                            .fill(.white.opacity(0.7))
                            .frame(width: 32)
                            .tag("circle")
                    }
                case .snow:
                    VortexView(.snow) {
                        Circle()
                            .fill(.white)
                            .frame(width: 24)
                            .blur(radius: 5)
                            .tag("circle")
                    }
                case .none:
                    EmptyView()
                }
            }
        }
    }
}

/// The Metal shader background, time-driven for cloud drift.
struct MetalSky: View {
    let cloudiness: Double
    let isDay: Bool
    private let start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Rectangle()
                .colorEffect(ShaderLibrary.sky(
                    .boundingRect,
                    .float(Float(timeline.date.timeIntervalSince(start))),
                    .float(Float(cloudiness)),
                    .float(isDay ? 1 : 0)))
        }
    }
}
