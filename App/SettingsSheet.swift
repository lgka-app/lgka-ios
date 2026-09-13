import SwiftUI

/// Settings — native Form: DARSTELLUNG (segmented theme + palette accent),
/// MEHR (bug report, privacy, legal, log out), version footer.
struct SettingsSheet: View {
    var onBugReport: () -> Void
    /// Privacy and legal notice: pushed on the home stack like the bug report (a sheet on
    /// top of this sheet is not presented reliably).
    var onOpenWeb: (String, String) -> Void
    @Environment(Prefs.self) private var prefs
    @Environment(HomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmLogout = false

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
                        onOpenWeb("https://privacy.lgka.app", L.s("privacyLabel"))
                    } label: {
                        Label(L.s("privacyLabel"), systemImage: "hand.raised")
                    }
                    Button {
                        Haptics.light()
                        onOpenWeb("https://impressum.lgka.app", L.s("legalLabel"))
                    } label: {
                        Label(L.s("legalLabel"), systemImage: "info.circle")
                    }
                    Button(role: .destructive) {
                        Haptics.light()
                        confirmLogout = true
                    } label: {
                        Label(L.s("logout"), systemImage: "rectangle.portrait.and.arrow.right")
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
                    Button { Haptics.light(); dismiss() } label: {
                        Label(L.s("a11y.close"), systemImage: "xmark")
                    }
                    .accessibilityIdentifier("settings.close")
                }
            }
            .confirmationDialog(L.s("logoutConfirm"), isPresented: $confirmLogout, titleVisibility: .visible) {
                Button(L.s("logout"), role: .destructive) {
                    Haptics.medium()
                    dismiss()
                    model.clear() // explicit sign-out: snapshot, login and every preference go
                    prefs.reset() // back to the welcome screen
                }
                Button(L.s("cancel"), role: .cancel) { Haptics.light() }
            }
        }
    }
}

/// New Year's Day fireworks — mirrors fireworks_overlay.dart + provider
/// (visible on January 1st, Europe/Berlin). Respects Reduce Motion.
struct FireworksOverlay: View {
    @State private var isNewYear = isNewYearsDay()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func isNewYearsDay() -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        let comps = cal.dateComponents([.month, .day], from: Date())
        return comps.month == 1 && comps.day == 1
    }

    var body: some View {
        Group {
            if isNewYear && !reduceMotion {
                FireworksEmitter().allowsHitTesting(false).ignoresSafeArea()
                    .accessibilityHidden(true)
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
    func makeUIView(context: Context) -> EmitterView {
        let view = EmitterView()
        let emitter = view.emitter
        emitter.emitterShape = .point
        emitter.renderMode = .additive
        let colors: [UIColor] = [.systemYellow, .systemOrange, .systemPink,
                                 .systemTeal, .systemPurple]
        let dot: CGImage? = {
            let size = CGSize(width: 12, height: 12)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            }.cgImage
        }()
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
            cell.contents = dot
            return cell
        }
        view.layer.addSublayer(emitter)
        return view
    }

    func updateUIView(_ view: EmitterView, context: Context) {}

    /// Places the emitter on every layout pass: `updateUIView` runs before the view
    /// has bounds (and not on rotation), which left the bursts in the top-left corner.
    final class EmitterView: UIView {
        let emitter = CAEmitterLayer()

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.height * 0.3)
            CATransaction.commit()
        }
    }
}
