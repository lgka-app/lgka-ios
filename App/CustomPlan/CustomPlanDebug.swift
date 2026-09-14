#if DEBUG
import SwiftUI
import LGKACore
import LGKAPlanKit

/// Debug builds only: open a custom-plan screen straight away for simulator screenshots, without
/// a school login, from JSON written by `lgka-plan`:
///   LGKA_DEBUG_CUSTOM_REVIEW=kurswahl.json LGKA_DEBUG_STUFENPLAN=stufenplan.json   review screen
///   LGKA_DEBUG_CUSTOM_SETUP=1                                      setup screen
@MainActor
enum CustomPlanDebug {
    private static var env: [String: String] { ProcessInfo.processInfo.environment }

    static var isActive: Bool {
        env["LGKA_DEBUG_CUSTOM_REVIEW"] != nil || env["LGKA_DEBUG_CUSTOM_SETUP"] != nil
    }

    @ViewBuilder static var root: some View {
        NavigationStack {
            if let kurswahl: Kurswahl = decode(env["LGKA_DEBUG_CUSTOM_REVIEW"]),
                      let stufenplan: Stufenplan = decode(env["LGKA_DEBUG_STUFENPLAN"]),
                      let item = sampleItem(stufe: stufenplan.stufe) {
                CustomPlanReviewScreen(draft: CustomPlanDraft(kurswahl: kurswahl, loaded: .init(stufenplan: stufenplan, item: item))) { _ in }
            } else {
                CustomPlanSetupScreen()
            }
        }
    }

    /// Keeps the last scan (recognised text, parsed sheet) in Caches/last-scan.json to replay it
    /// on the Mac: `lgka-plan build --plan J11.pdf --scan last-scan.json --out plan.json`.
    static func keep(_ scan: KurswahlScanner.Result) {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let data = try? JSONEncoder().encode(scan) else { return }
        try? data.write(to: caches.appendingPathComponent("last-scan.json"), options: .atomic)
    }

    private static func decode<T: Decodable>(_ path: String?) -> T? {
        guard let path, let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func sampleItem(stufe: String) -> ScheduleItem? {
        let json = """
        {"title":"Stundenpläne - 2026/2027 - 1.HJ - \(stufe)","url":"","fullUrl":"debug","halbjahr":"1. Halbjahr",
         "gradeLevel":"\(stufe)","available":true,"pdf":null,"classIndex":{},"pages":[]}
        """
        return try? JSONDecoder().decode(ScheduleItem.self, from: Data(json.utf8))
    }
}
#endif
