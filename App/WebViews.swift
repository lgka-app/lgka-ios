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
    @State private var isLoading = true
    @State private var failed = false
    @State private var reloadToken = 0

    var body: some View {
        ZStack {
            WebViewRepresentable(url: url,
                                 isLoading: $isLoading,
                                 failed: $failed, reloadToken: reloadToken)
            if failed {
                ContentUnavailableView {
                    Label(L.s("formLoadError"), systemImage: "wifi.exclamationmark")
                } description: {
                    Text(L.s("formLoadErrorHint"))
                } actions: {
                    Button(L.s("tryAgain")) {
                        Haptics.light()
                        failed = false
                        isLoading = true
                        reloadToken += 1
                    }
                    .buttonStyle(.borderedProminent)
                }
                .themeBg()
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(L.s("loading")).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .themeBg()
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let url: String
    @Binding var isLoading: Bool
    @Binding var failed: Bool
    let reloadToken: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent() // incognito parity
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.customUserAgent = SchoolAPI.userAgent
        view.isOpaque = false
        load(view)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            load(view)
        }
    }

    private func load(_ view: WKWebView) {
        guard let target = URL(string: url) else { return }
        view.load(URLRequest(url: target, timeoutInterval: 20))
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewRepresentable
        var lastReloadToken = 0

        init(_ parent: WebViewRepresentable) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!,
                     withError error: any Error) {
            // a link tapped before the page finished cancels the old load; the new one reports itself
            if (error as NSError).code == NSURLErrorCancelled { return }
            parent.isLoading = false
            parent.failed = true
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: any Error) {
            if (error as NSError).code == NSURLErrorCancelled { return }
            parent.isLoading = false
            parent.failed = true
        }

        // webview_screen parity: answer HTTP basic-auth challenges — but only
        // for the school's own host, and only with the user's stored login.
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge)
            async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            let space = challenge.protectionSpace
            if space.authenticationMethod == NSURLAuthenticationMethodHTTPBasic,
               SchoolAPI.isSchoolHost(space.host),
               challenge.previousFailureCount == 0,
               let creds = Credentials.load() {
                return (.useCredential,
                        URLCredential(user: creds.user, password: creds.password,
                                      persistence: .forSession))
            }
            return (.performDefaultHandling, nil)
        }

        // target="_blank" links and window.open have no window to open in: without this they do nothing
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
            return nil
        }
    }
}
