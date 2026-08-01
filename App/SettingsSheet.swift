import SwiftUI

/// Settings bottom sheet — mirrors settings_modal.dart:
/// DARSTELLUNG (theme mode + accent dots), MEHR (bug report, privacy,
/// legal), © footer with version.
struct SettingsSheet: View {
    var onBugReport: () -> Void
    @EnvironmentObject private var prefs: Prefs
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var scheme

    private let appVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L.s("settings"))
                .font(.title3.bold())
                .padding(.bottom, 20)

            caps(L.s("settingsSectionAppearance"))
            VStack(spacing: 0) {
                HStack {
                    Text(L.s("appearanceTitle")).font(.subheadline.weight(.medium))
                    Spacer()
                    ThemeModePicker(order: ["dark", "light", "system"],
                                    iconSize: 15, labels: false)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Divider().padding(.leading, 16)
                HStack {
                    Text(L.s("accentColor")).font(.subheadline.weight(.medium))
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(Accent.allCases, id: \.rawValue) { accent in
                            let isSelected = prefs.accentColor == accent.rawValue
                            Button {
                                Haptics.light()
                                prefs.accentColor = accent.rawValue
                            } label: {
                                Circle()
                                    .fill(accent.color)
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        if isSelected {
                                            Circle().strokeBorder(.white, lineWidth: 2)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .shadow(color: isSelected
                                        ? accent.color.opacity(0.4) : .clear, radius: 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .surfaceCard(radius: 14)

            Spacer().frame(height: 20)

            caps(L.s("settingsSectionMore"))
            VStack(spacing: 0) {
                linkTile("ladybug", L.s("bugReport"), chevron: true) {
                    Haptics.light()
                    onBugReport()
                }
                Divider().padding(.leading, 16)
                linkTile("hand.raised", L.s("privacyLabel"), chevron: false) {
                    Haptics.light()
                    openURL(URL(string: "https://luka-loehr.github.io/LGKA/privacy.html")!)
                }
                Divider().padding(.leading, 16)
                linkTile("info.circle", L.s("legalLabel"), chevron: false) {
                    Haptics.light()
                    openURL(URL(string: "https://luka-loehr.github.io/LGKA/impressum.html")!)
                }
            }
            .surfaceCard(radius: 14)

            Spacer().frame(height: 24)

            HStack(spacing: 0) {
                Spacer()
                Text("© \(String(Calendar.current.component(.year, from: Date()))) ")
                    .foregroundStyle(.secondary.opacity(0.5))
                Text("Luka Löhr")
                    .foregroundStyle(prefs.accent.opacity(0.6))
                    .fontWeight(.medium)
                Text(" • v\(appVersion)")
                    .foregroundStyle(.secondary.opacity(0.5))
                Spacer()
            }
            .font(.caption)
            Spacer()
        }
        .padding(16)
        .presentationBackground(scheme == .dark ? Color.darkBg : Color.lightBg)
    }

    private func caps(_ label: String) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .kerning(0.6)
            .padding(.leading, 4)
            .padding(.bottom, 8)
    }

    private func linkTile(_ icon: String, _ label: String, chevron: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: chevron ? "chevron.right" : "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// New Year's Day fireworks — mirrors fireworks_overlay.dart + provider
/// (visible on January 1st, Europe/Berlin).
struct FireworksOverlay: View {
    @State private var isNewYear = isNewYearsDay()

    static func isNewYearsDay() -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        let comps = cal.dateComponents([.month, .day], from: Date())
        return comps.month == 1 && comps.day == 1
    }

    var body: some View {
        Group {
            if isNewYear {
                FireworksEmitter().allowsHitTesting(false).ignoresSafeArea()
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                isNewYear = Self.isNewYearsDay()
            }
        }
    }
}

struct FireworksEmitter: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .point
        emitter.renderMode = .additive
        let colors: [UIColor] = [.systemYellow, .systemOrange, .systemPink,
                                 .systemTeal, .systemPurple]
        emitter.emitterCells = colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 1.2
            cell.lifetime = 2.2
            cell.velocity = 220
            cell.velocityRange = 120
            cell.emissionRange = .pi * 2
            cell.scale = 0.06
            cell.scaleRange = 0.03
            cell.alphaSpeed = -0.45
            cell.yAcceleration = 90
            cell.color = color.cgColor
            cell.contents = {
                let size = CGSize(width: 12, height: 12)
                UIGraphicsBeginImageContextWithOptions(size, false, 0)
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
                let img = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                return img?.cgImage
            }()
            return cell
        }
        view.layer.addSublayer(emitter)
        context.coordinator.emitter = emitter
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.emitter?.emitterPosition =
            CGPoint(x: view.bounds.midX, y: view.bounds.height * 0.3)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var emitter: CAEmitterLayer? }
}
