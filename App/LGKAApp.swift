import SwiftUI

@main
struct LGKAApp: App {
    @State private var web: WebItem?
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var prefs = Prefs()
    @State private var model = HomeModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .onChange(of: scenePhase) { _, phase in
                    // resume: one hash sync (fresh answers cost ~0.5 KB)
                    if phase == .active && prefs.isSignedIn {
                        Task { await model.refreshOnForeground() }
                    }
                }
                .task(id: scenePhase) {
                    // while active: re-sync every minute (substitution plans change during the day)
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(60))
                        if !Task.isCancelled && prefs.isSignedIn {
                            await model.sync()
                        }
                    }
                }
                .onChange(of: model.unauthorized) { _, rejected in
                    // the school rotated the password (confirmed by /v1/auth/check):
                    // back to the login gate; the snapshot stays on disk
                    guard rejected else { return }
                    model.unauthorized = false
                    prefs.passwordRotated = true
                    prefs.signOut()
                }
                .environment(prefs)
                .environment(model)
                .environment(\.appAccent, prefs.accent)
                // every Link / inline link in the app: tap haptic, then the app's own web
                // screen (the one the bug report uses); non-web URLs go to the system
                .environment(\.openURL, OpenURLAction { url in
                    Haptics.light()
                    guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return .systemAction }
                    web = WebItem(url: url)
                    return .handled
                })
                .sheet(item: $web) { item in
                    NavigationStack {
                        WebScreen(url: item.url.absoluteString, title: item.title)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button { Haptics.light(); web = nil } label: {
                                        Label(L.s("a11y.close"), systemImage: "xmark")
                                    }
                                }
                            }
                    }
                }
                .tint(prefs.accent)
                .preferredColorScheme(prefs.colorScheme)
                .overlay(FireworksOverlay())
        }
    }
}

/// Route gating — mirrors main.dart's initialRoute logic, kept live.
struct RootView: View {
    @Environment(Prefs.self) private var prefs

    var body: some View {
        #if DEBUG
        if CustomPlanDebug.isActive {
            CustomPlanDebug.root
        } else {
            gate
        }
        #else
        gate
        #endif
    }

    @ViewBuilder private var gate: some View {
        if !prefs.onboardingCompleted {
            OnboardingFlow()
        } else if !prefs.isSignedIn {
            AuthScreen()
        } else {
            HomeScreen()
        }
    }
}

struct WebItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
    var title: String { url.host?.replacingOccurrences(of: "www.", with: "") ?? "" }
}
