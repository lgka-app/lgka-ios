import SwiftUI

struct WeatherView: View {
    var body: some View {
        NavigationStack {
            LoadableView(load: { try await SchoolAPI.weather() }) { weather in
                ScrollView {
                    VStack(spacing: 20) {
                        // current conditions
                        VStack(spacing: 8) {
                            Image(systemName: Wmo.symbol(weather.code, isDay: weather.isDay))
                                .font(.system(size: 64))
                                .symbolRenderingMode(.multicolor)
                            Text("\(Int(weather.temp.rounded()))°")
                                .font(.system(size: 64, weight: .thin))
                            Text(Wmo.description(weather.code))
                                .font(.headline)
                            Text("Gefühlt \(Int(weather.feelsLike.rounded()))°")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)

                        // stats
                        HStack(spacing: 12) {
                            stat("humidity", "\(weather.humidity) %", "Luftfeuchte")
                            stat("wind", "\(Int(weather.windSpeed.rounded())) km/h", "Wind")
                            stat("gauge", "\(weather.pressure) hPa", "Druck")
                            stat("sun.max", String(format: "%.1f", weather.uvi), "UV")
                        }
                        .padding(.horizontal)

                        // hourly
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stündlich")
                                .font(.headline)
                                .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(weather.hourly) { hour in
                                        VStack(spacing: 6) {
                                            Text(hour.time).font(.caption2)
                                            Image(systemName: Wmo.symbol(hour.code, isDay: hour.isDay))
                                                .symbolRenderingMode(.multicolor)
                                            Text("\(Int(hour.temp.rounded()))°")
                                                .font(.subheadline.weight(.medium))
                                            if hour.pop >= 0.1 {
                                                Text("\(Int(hour.pop * 100)) %")
                                                    .font(.caption2)
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // daily
                        VStack(alignment: .leading, spacing: 8) {
                            Text("3-Tage-Vorhersage")
                                .font(.headline)
                            ForEach(weather.daily) { day in
                                HStack {
                                    Text(germanDayLabel(day.date))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if day.pop >= 0.1 {
                                        Text("\(Int(day.pop * 100)) %")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                    Image(systemName: Wmo.symbol(day.code, isDay: true))
                                        .symbolRenderingMode(.multicolor)
                                        .frame(width: 32)
                                    Text("\(Int(day.tempMin.rounded()))° / \(Int(day.tempMax.rounded()))°")
                                        .font(.subheadline.monospacedDigit())
                                        .frame(width: 90, alignment: .trailing)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Wetter")
        }
    }

    private func stat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.callout)
            Text(value).font(.subheadline.weight(.semibold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}
