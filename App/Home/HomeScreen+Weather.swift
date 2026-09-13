import SwiftUI
import LGKACore

extension HomeScreen {
    // ── Weather card ────────────────────────────────────────────────────────

    @ViewBuilder var weatherSection: some View {
        if let w = model.weather {
            Button {
                Haptics.medium()
                path.append(HomeRoute.weather)
            } label: {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L.s("city"))
                            .font(.footnote.weight(.semibold))
                            .opacity(0.85)
                        Text("\(Int(w.current.temp.rounded()))°")
                            .font(.system(size: heroSize, weight: .medium, design: .rounded))
                        Text(Wmo.description(w.current.weatherCode))
                            .font(.footnote.weight(.medium))
                            .opacity(0.9)
                            .lineLimit(1)
                        Text(feelsLikeLine(w))
                            .font(.caption2.weight(.semibold))
                            .opacity(0.8)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 3) {
                        Image(systemName: Wmo.symbol(w.current.weatherCode, isDay: w.current.isDay))
                            .font(.title)
                            .symbolRenderingMode(.multicolor)
                        if let today = w.daily.first {
                            Text(L.f("highLow", Int(today.tempMax.rounded()), Int(today.tempMin.rounded())))
                                .font(.caption.weight(.medium))
                                .opacity(0.9)
                        }
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 4)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                // The whole card is the hit target, not only the glyphs.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowBackground(
                WeatherSkyView(code: w.current.weatherCode, isDay: w.current.isDay, particles: false)
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.18)],
                                            startPoint: .top, endPoint: .bottom))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.f("a11y.weatherCard", Wmo.description(w.current.weatherCode), Int(w.current.temp.rounded())))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("home.weather")
        } else if model.weatherError {
            HStack(spacing: 14) {
                Image(systemName: "cloud.slash").foregroundStyle(.secondary)
                Text(L.s("weatherDataNotAvailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                retryButton { await model.sync(only: [.weather]) }
            }
            .frame(minHeight: 56)
        } else {
            skeletonRow
        }
    }

    private func feelsLikeLine(_ w: WeatherData) -> String {
        let feels = Int(w.current.feelsLike.rounded())
        if let today = w.daily.first {
            return L.f("feelsLike.range", feels, Int(today.tempMin.rounded()), Int(today.tempMax.rounded()))
        }
        return L.f("feelsLike.humidity", feels, w.current.humidity)
    }
}
