import SwiftUI

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

/// Bug report form — mirrors bug_report_screen.dart (self-hosted, incognito).
struct BugReportScreen: View {
    var body: some View {
        WebContainer(url:
            "https://bugreport.lgka.app")
            .themeBg()
            .navigationTitle(L.s("bugReportTitle"))
            .navigationBarTitleDisplayMode(.inline)
    }
}
