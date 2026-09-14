import SwiftUI
import LGKACore
import LGKAPlanKit

/// The saved personal J11 / J12 timetable: header, week grid, lesson details, PDF export.
struct CustomPlanScreen: View {
    let saved: SavedCustomPlan
    let onEditCourses: () -> Void
    let onRescan: () -> Void
    let onDelete: () -> Void

    @Environment(\.appAccent) private var accent
    @State private var selected: SelectedLesson?
    @State private var shareFile: ShareFile?
    @State private var confirmDelete = false

    private var plan: CustomPlan { saved.plan }

    private struct SelectedLesson: Identifiable {
        let id = UUID()
        let lesson: CustomPlan.Lesson
    }

    private struct ShareFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                CustomPlanGrid(plan: plan) { lesson in
                    selected = SelectedLesson(lesson: lesson)
                }
                .padding(10)
                .surfaceCard()
                if !plan.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(plan.notes, id: \.self) { note in
                            Label(note, systemImage: "info.circle")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .readableWidth(1000)
        }
        .background(Color.appBackground)
        .navigationTitle(L.s("plan.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { Haptics.light(); share() } label: {
                    Label(L.s("plan.share"), systemImage: "square.and.arrow.up")
                }
                Menu {
                    Button(L.s("plan.editCourses"), systemImage: "slider.horizontal.3") { Haptics.light(); onEditCourses() }
                    Button(L.s("plan.rescan"), systemImage: "doc.viewfinder") { Haptics.light(); onRescan() }
                    Divider()
                    Button(L.s("plan.delete"), systemImage: "trash", role: .destructive) { Haptics.light(); confirmDelete = true }
                } label: {
                    Label(L.s("plan.more"), systemImage: "ellipsis")
                }
            }
        }
        .sheet(item: $selected) { item in
            CustomPlanLessonSheet(plan: plan, lesson: item.lesson)
        }
        .sheet(item: $shareFile) { file in
            ActivityView(items: [file.url]).presentationDetents([.medium, .large])
        }
        .confirmationDialog(L.s("plan.deleteConfirm"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L.s("plan.delete"), role: .destructive) { Haptics.medium(); onDelete() }
            Button(L.s("cancel"), role: .cancel) { Haptics.light() }
        } message: {
            Text(L.s("plan.deleteMessage"))
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name.isEmpty ? L.s("plan.title") : plan.name)
                    .font(.title2.weight(.bold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(L.f("plan.hours", plan.checks.totalHours))
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(accent)
                if !plan.checks.issues.isEmpty {
                    Label(L.f("plan.issues", plan.checks.issues.count), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts = [plan.stufe, plan.halbjahr]
        if let stand = plan.stand { parts.append(L.f("plan.stand", stand)) }
        return parts.joined(separator: " · ")
    }

    private func share() {
        let who = (plan.name.isEmpty ? plan.stufe : plan.name)
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        let half = plan.halbjahr.first.map(String.init) ?? "1"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Stundenplan_\(who)_\(half)HJ.pdf")
        do {
            try CustomPlanPDF.render(plan).write(to: url, options: .atomic)
            shareFile = ShareFile(url: url)
        } catch {
            Haptics.error()
        }
    }
}

#if DEBUG
#Preview {
    let json = #"""
    {"version":1,"name":"Max Muster","stufe":"J11","halbjahr":"1. Halbjahr","schuljahr":"2026-2027","stand":"7.9.2026 14:39",
     "periods":[{"number":1,"start":"7:45","end":"8:30"},{"number":2,"start":"8:35","end":"9:20"},{"number":3,"start":"9:35","end":"10:20"},
      {"number":4,"start":"10:25","end":"11:10"},{"number":5,"start":"11:30","end":"12:15"},{"number":6,"start":"12:20","end":"13:05"},
      {"number":7,"start":"13:10","end":"13:55"},{"number":8,"start":"14:00","end":"14:45"},{"number":9,"start":"14:50","end":"15:35"},
      {"number":10,"start":"15:50","end":"16:35"},{"number":11,"start":"16:35","end":"17:20"}],
     "breaks":[{"after":2,"start":"9:20","end":"9:35"},{"after":4,"start":"11:10","end":"11:30"},{"after":9,"start":"15:35","end":"15:50"}],
     "courses":[
      {"id":"M3","subjectKey":"M","subject":"Mathematik","level":"LF","codes":["M3"],"title":"Mathematik (LF, M3)","teachers":[{"code":"Bur","name":"Johannes Burger"}],"hours":5,"expectedHours":5},
      {"id":"d3","subjectKey":"D","subject":"Deutsch","level":"Basis","codes":["d3"],"title":"Deutsch (d3)","teachers":[{"code":"Nm","name":"Ursula Neumann"}],"hours":3,"expectedHours":3},
      {"id":"s1/s2/s3","subjectKey":"Sport","subject":"Sport","level":"Basis","codes":["s1","s2","s3"],"title":"Sport (s1 / s2 / s3)","teachers":[{"code":"Bur","name":"Johannes Burger"},{"code":"Dom","name":"Evamaria Domin"}],"hours":2,"expectedHours":2}],
     "lessons":[
      {"day":0,"start":1,"end":2,"course":"M3","rooms":["301"],"teachers":["Bur"]},
      {"day":0,"start":10,"end":11,"course":"s1/s2/s3","rooms":["WB2","FrEb"],"teachers":["Bur","Dom"]},
      {"day":1,"start":8,"end":8,"course":"d3","rooms":["102"],"teachers":["Nm"]},
      {"day":3,"start":5,"end":6,"course":"d3","rooms":["312"],"teachers":["Nm"]},
      {"day":4,"start":1,"end":2,"course":"M3","rooms":["409"],"teachers":["Bur"]},
      {"day":2,"start":10,"end":10,"course":"M3","rooms":["109"],"teachers":["Bur"]}],
     "choices":[],"checks":{"totalHours":10,"expectedTotal":10,"issues":[]},"notes":["Sport: s1 / s2 / s3 im Kurswahlprotokoll nicht vermerkt"],
     "generatedAt":"2026-09-14T12:00:00Z"}
    """#
    let plan = try! JSONDecoder().decode(CustomPlan.self, from: Data(json.utf8))
    return NavigationStack {
        CustomPlanScreen(saved: SavedCustomPlan(plan: plan, kurswahl: nil, planTitle: nil),
                         onEditCourses: {}, onRescan: {}, onDelete: {})
    }
}
#endif
