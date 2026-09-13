import SwiftUI

/// Krankmeldung pre-info — mirrors krankmeldung_info_screen.dart.
struct KrankmeldungInfoScreen: View {
    let onContinue: () -> Void
    @Environment(Prefs.self) private var prefs
    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(spacing: 16) {
            infoCard("exclamationmark.triangle", L.s("krankmeldungDisclaimer"))
            infoCard("person.wave.2", L.s("krankmeldungContact"))
            Spacer()
            Button {
                Haptics.light()
                prefs.krankmeldungInfoShown = true
                onContinue()
            } label: {
                Label(L.s("krankmeldungButton"), systemImage: "cross.case")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding(16)
        .themeBg()
        .navigationTitle(L.s("krankmeldungInfoHeader"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoCard(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 52, height: 52)
                .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}
