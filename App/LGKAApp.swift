import SwiftUI

@main
struct LGKAApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Color("AccentColor"))
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Vertretung", systemImage: "arrow.triangle.2.circlepath") {
                SubstitutionView()
            }
            Tab("Stundenplan", systemImage: "calendar.day.timeline.left") {
                ScheduleView()
            }
            Tab("News", systemImage: "newspaper") {
                NewsView()
            }
            Tab("Termine", systemImage: "calendar") {
                EventsView()
            }
            Tab("Wetter", systemImage: "cloud.sun") {
                WeatherView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

/// Shared async-state wrapper: spinner -> content -> error with retry.
struct LoadableView<Value, Content: View>: View {
    let load: () async throws -> Value
    @ViewBuilder let content: (Value) -> Content

    @State private var value: Value?
    @State private var error: String?

    var body: some View {
        Group {
            if let value {
                content(value)
            } else if let error {
                ContentUnavailableView {
                    Label("Serververbindung fehlgeschlagen", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Erneut versuchen") {
                        self.error = nil
                        Task { await run() }
                    }
                    .buttonStyle(.glassProminent)
                }
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .task { if value == nil { await run() } }
        .refreshable { await run() }
    }

    private func run() async {
        do {
            value = try await load()
            error = nil
        } catch {
            if value == nil { self.error = error.localizedDescription }
        }
    }
}
