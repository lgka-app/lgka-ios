import SwiftUI

/// Settings — native Form: DARSTELLUNG (segmented theme + palette accent),
/// MEHR (bug report, privacy, legal), version footer.
struct SettingsSheet: View {
    var onBugReport: () -> Void
    @EnvironmentObject private var prefs: Prefs
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    private let appVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

    var body: some View {
        NavigationStack {
            Form {
                Section(L.s("settingsSectionAppearance")) {
                    LabeledContent(L.s("appearanceTitle")) {
                        ThemeModePicker().frame(maxWidth: 220)
                    }
                    LabeledContent(L.s("accentColor")) {
                        AccentPalettePicker().frame(maxWidth: 220)
                    }
                }

                Section {
                    Button {
                        Haptics.light()
                        onBugReport()
                    } label: {
                        Label(L.s("bugReport"), systemImage: "ladybug")
                    }
                    Button {
                        Haptics.light()
                        openURL(URL(string: "https://luka-loehr.github.io/LGKA/privacy.html")!)
                    } label: {
                        Label {
                            Text(L.s("privacyLabel"))
                        } icon: {
                            Image(systemName: "hand.raised")
                        }
                    }
                    Button {
                        Haptics.light()
                        openURL(URL(string: "https://luka-loehr.github.io/LGKA/impressum.html")!)
                    } label: {
                        Label(L.s("legalLabel"), systemImage: "info.circle")
                    }
                } header: {
                    Text(L.s("settingsSectionMore"))
                } footer: {
                    HStack(spacing: 0) {
                        Spacer()
                        Text("© \(String(Calendar.current.component(.year, from: Date()))) ")
                        Text("Luka Löhr").foregroundStyle(.tint)
                        Text(" • v\(appVersion)")
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle(L.s("settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
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
