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
