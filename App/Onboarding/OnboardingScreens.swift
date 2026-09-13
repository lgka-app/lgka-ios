import SwiftUI

struct WelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("OnboardingLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .accessibilityHidden(true)
            Text(L.s("welcomeHeadline"))
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text(L.s("welcomeSubtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .readableWidth(560)
        .padding(.horizontal, 32)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: L.s("continueLabel")) {
                Haptics.light()
                onContinue()
            }
            .accessibilityIdentifier("onboarding.continue")
            .padding(.horizontal, 32)
            .padding(.bottom, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct FeaturesScreen: View {
    let onContinue: () -> Void
    @Environment(\.appAccent) private var accent

    private let features: [(String, String, String)] = [
        ("calendar", "featureSubstitutionTitle", "featureSubstitutionDesc"),
        ("clock", "featureScheduleTitle", "featureScheduleDesc"),
        ("cloud.sun", "featureWeatherTitle", "featureWeatherDesc"),
        ("newspaper", "featureNewsTitle", "featureNewsDesc"),
        ("cross.case", "featureSickTitle", "featureSickDesc"),
        ("calendar.badge.clock", "featureEventsTitle", "featureEventsDesc"),
    ]

    var body: some View {
        List {
            ForEach(features, id: \.1) { icon, title, desc in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.s(title)).font(.body.weight(.medium))
                        Text(L.s(desc)).font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: icon).foregroundStyle(accent)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.s("infoHeader"))
        .navigationBarBackButtonHidden()
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: L.s("continueLabel")) {
                onContinue()
            }
            .accessibilityIdentifier("onboarding.continue")
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
}

struct AccentColorScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(L.s("accentColorTitle"))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(L.s("accentColorDescription"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 16)
            AccentPalettePicker()
                .scaleEffect(1.3)
            Spacer()
        }
        .readableWidth(560)
        .padding(.horizontal, 24)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: L.s("continueLabel")) {
                onContinue()
            }
            .accessibilityIdentifier("onboarding.continue")
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .navigationBarBackButtonHidden()
    }
}

struct AppearanceScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(L.s("appearanceTitle"))
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            ThemeModePicker()
                .frame(maxWidth: 340)
            Spacer()
        }
        .readableWidth(560)
        .padding(.horizontal, 24)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: L.s("letsGo")) {
                onContinue()
            }
            .accessibilityIdentifier("onboarding.continue")
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .navigationBarBackButtonHidden()
    }
}
