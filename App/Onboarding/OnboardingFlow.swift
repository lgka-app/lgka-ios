import SwiftUI

/// welcome -> what-you-can-do -> accent-color -> appearance -> auth
struct OnboardingFlow: View {
    @State private var path: [Step] = []

    enum Step: Hashable { case features, accent, appearance, auth }

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeScreen { path.append(.features) }
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .features: FeaturesScreen { path.append(.accent) }
                    case .accent: AccentColorScreen { path.append(.appearance) }
                    case .appearance: AppearanceScreen { path.append(.auth) }
                    case .auth: AuthScreen()
                    }
                }
        }
    }
}

/// Native full-width prominent button used across onboarding.
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button { Haptics.medium(); action() } label: {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }
}
