import SwiftUI
import WebKit

/// In-app browser — mirrors webview_screen.dart (progress, error, retry;
/// non-persistent store for privacy like the Flutter incognito settings).
struct WebScreen: View {
    let url: String
    let title: String

    var body: some View {
        WebContainer(url: url)
            .themeBg()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Krankmeldung pre-info — mirrors krankmeldung_info_screen.dart.
struct KrankmeldungInfoScreen: View {
    let onContinue: () -> Void
    @EnvironmentObject private var prefs: Prefs
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
                HStack(spacing: 8) {
                    Image(systemName: "cross.case")
                    Text(L.s("krankmeldungButton")).fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(accent, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .themeBg()
        .navigationTitle(L.s("krankmeldungInfoHeader"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoCard(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(accent)
                .frame(width: 52, height: 52)
                .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
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

/// Bug report form — mirrors bug_report_screen.dart (Google form, incognito).
struct BugReportScreen: View {
    var body: some View {
        WebContainer(url:
            "https://docs.google.com/forms/d/e/1FAIpQLSdknGu7-xgFurrghbUYOwoYu-Vsaftar6PGLzMv64UFpwJtRw/viewform?usp=publish-editor")
            .themeBg()
            .navigationTitle(L.s("bugReportTitle"))
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct WebContainer: View {
    let url: String
    @State private var progress = 0.0
    @State private var failed = false
    @State private var reloadToken = 0

    var body: some View {
        ZStack {
            WebViewRepresentable(url: url, progress: $progress,
                                 failed: $failed, reloadToken: reloadToken)
            if failed {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 52))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(L.s("formLoadError")).font(.callout.weight(.semibold))
                    Text(L.s("formLoadErrorHint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(L.s("tryAgain")) {
                        Haptics.light()
                        failed = false
                        reloadToken += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 12)
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .themeBg()
            } else if progress < 1.0 {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(L.s("loading")).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .themeBg()
            }
        }
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let url: String
    @Binding var progress: Double
    @Binding var failed: Bool
    let reloadToken: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent() // incognito parity
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.customUserAgent = "LGKA+/3.0.0"
        view.isOpaque = false
        context.coordinator.observe(view)
        load(view)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            load(view)
        }
    }

    private func load(_ view: WKWebView) {
        guard let target = URL(string: url) else { return }
        view.load(URLRequest(url: target, timeoutInterval: 20))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let parent: WebViewRepresentable
        private var observation: NSKeyValueObservation?
        var lastReloadToken = 0

        init(_ parent: WebViewRepresentable) { self.parent = parent }

        func observe(_ view: WKWebView) {
            observation = view.observe(\.estimatedProgress) { [weak self] view, _ in
                DispatchQueue.main.async { self?.parent.progress = view.estimatedProgress }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!,
                     withError error: Error) {
            parent.failed = true
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            parent.failed = true
        }
    }
}
