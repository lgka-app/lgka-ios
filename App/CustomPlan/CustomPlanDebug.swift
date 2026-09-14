#if DEBUG
import SwiftUI
import LGKACore

/// Debug builds only: open a custom-plan screen straight away for simulator screenshots, without
/// a school login, from JSON written by `lgka-plan`:
///   LGKA_DEBUG_CUSTOM_PLAN=plan.json                               plan screen
///   LGKA_DEBUG_CUSTOM_REVIEW=kurswahl.json LGKA_DEBUG_STUFENPLAN=stufenplan.json   review screen
///   LGKA_DEBUG_CUSTOM_SETUP=1                                      setup screen
@MainActor
enum CustomPlanDebug {
    private static var env: [String: String] { ProcessInfo.processInfo.environment }

    static var isActive: Bool {
        env["LGKA_DEBUG_CUSTOM_PLAN"] != nil || env["LGKA_DEBUG_CUSTOM_REVIEW"] != nil || env["LGKA_DEBUG_CUSTOM_SETUP"] != nil
    }

    @ViewBuilder static var root: some View {
        NavigationStack {
            if let plan: CustomPlan = decode(env["LGKA_DEBUG_CUSTOM_PLAN"]) {
                CustomPlanScreen(saved: .init(plan: plan, kurswahl: nil, planTitle: nil),
                                 onEditCourses: {}, onRescan: {}, onDelete: {})
            } else if let kurswahl: Kurswahl = decode(env["LGKA_DEBUG_CUSTOM_REVIEW"]),
                      let stufenplan: Stufenplan = decode(env["LGKA_DEBUG_STUFENPLAN"]),
                      let item = sampleItem(stufe: stufenplan.stufe) {
                CustomPlanReviewScreen(draft: CustomPlanDraft(kurswahl: kurswahl, loaded: .init(stufenplan: stufenplan, item: item))) { _ in }
            } else {
                CustomPlanSetupScreen()
            }
        }
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
