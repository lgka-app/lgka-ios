import SwiftUI
import PhotosUI
import LGKACore
import LGKAPlanKit

// MARK: - Host

/// Pushed from Home: scanning a Kurswahlprotokoll (setup, then review) or correcting the saved
/// courses. Saving hands the plan back to Home, which opens its PDF.
struct CustomPlanHost: View {
    enum Mode { case scan, edit }

    let mode: Mode
    /// After the new plan was revealed and its viewer closed: back to Home.
    let onFinished: () -> Void
    @Environment(HomeModel.self) private var model
    @State private var reviewing: CustomPlanDraft?
    /// The plan just saved, revealed over the review.
    @State private var ready: SavedCustomPlan?
    /// The saved plan could not be loaded for editing.
    @State private var loadFailed = false

    var body: some View {
        switch mode {
        case .scan:
            CustomPlanSetupScreen(onDraft: { reviewing = $0 })
                .navigationDestination(item: $reviewing) { draft in
                    review(draft)
                }
        case .edit:
            Group {
                if let reviewing {
                    review(reviewing)
                } else if loadFailed {
                    Text(L.s("custom.error.generic"))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle(L.s("custom.review.title"))
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task { await loadSaved() }
        }
    }

    private func review(_ draft: CustomPlanDraft) -> some View {
        CustomPlanReviewScreen(draft: draft) { save($0) }
            .toolbar(ready == nil ? .automatic : .hidden, for: .navigationBar)
            .overlay {
                if let ready {
                    CustomPlanReadyView(saved: ready, onFinished: onFinished)
                        .transition(.opacity)
                }
            }
    }

    private func save(_ value: SavedCustomPlan) {
        CustomPlanStore.shared.save(value)
        withAnimation(.easeInOut(duration: 0.3)) { ready = value }
    }

    private func loadSaved() async {
        guard reviewing == nil else { return }
        guard let saved = CustomPlanStore.shared.saved,
              let plans = try? await CustomPlanSource.plans(model: model),
              let loaded = CustomPlanSource.pick(plans, stufe: saved.plan.stufe, kurswahl: saved.kurswahl) else {
            // offline or no Stufenplan: say so instead of spinning forever (as on Android)
            loadFailed = true
            return
        }
        reviewing = CustomPlanDraft(saved: saved, loaded: loaded)
    }
}

// MARK: - Sources

/// The J11 / J12 Stufenpläne of the current semester, read from their PDFs on the device.
@MainActor
enum CustomPlanSource {
    struct Loaded: Hashable, Sendable {
        var stufenplan: Stufenplan
        var item: ScheduleItem
    }

    enum Failure: Error { case noPlanPublished }

    /// The saved plan against the current Stufenplan: rebuilt (and saved) when the school published a
    /// newer one or the next Halbjahr started, unchanged otherwise or when offline.
    static func refreshed(_ saved: SavedCustomPlan, model: HomeModel) async -> (saved: SavedCustomPlan, rebuilt: Bool) {
        guard let plans = try? await plans(model: model),
              let loaded = pick(plans, stufe: nil, kurswahl: saved.kurswahl) ?? pick(plans, stufe: saved.plan.stufe, kurswahl: nil),
              loaded.item.pdf?.sha256 != saved.plan.planSha256 else { return (saved, false) }
        let updated = CustomPlanDraft(saved: saved, loaded: loaded).saved
        CustomPlanStore.shared.save(updated)
        return (updated, true)
    }

    /// The plan rendered as its Untis-style PDF in Caches, named for sharing.
    static func pdfFile(for plan: CustomPlan) throws -> URL {
        let caches = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let owner = plan.name.isEmpty ? plan.stufe : plan.name
        let url = caches.appendingPathComponent("Stundenplan \(owner) \(plan.halbjahr).pdf")
        // a saved plan keeps the names from when it was built: take the current staff list
        var current = plan
        for c in current.courses.indices {
            for t in current.courses[c].teachers.indices {
                let code = current.courses[c].teachers[t].code
                current.courses[c].teachers[t].name = SchoolReference.teacherName(code) ?? current.courses[c].teachers[t].name
            }
        }
        try CustomPlanPDF.render(current, labels: CustomPlanLabels.pdf).write(to: url, options: .atomic)
        return url
    }

    static func plans(model: HomeModel) async throws -> [Loaded] {
        let items = model.preferredGroup.filter { item in
            item.available && item.pdf != nil && item.grades.contains(where: { $0 >= 11 })
        }
        var loaded: [Loaded] = []
        for item in items {
            guard let pdf = item.pdf else { continue }
            let url = try await model.pdfURL(for: pdf)
            let plan = try await Task.detached(priority: .userInitiated) { try PdfText.stufenplan(at: url) }.value
            loaded.append(.init(stufenplan: plan, item: item))
        }
        if loaded.isEmpty { throw Failure.noPlanPublished }
        return loaded
    }

    /// The plan of the sheet's Jahrgang, else of the given Stufe, else the only one.
    static func pick(_ plans: [Loaded], stufe: String?, kurswahl: Kurswahl?) -> Loaded? {
        if let kurswahl, let match = plans.first(where: { loaded in
            loaded.stufenplan.schuljahr.flatMap { kurswahl.grade(inSchuljahr: $0) } == loaded.stufenplan.grade
        }) { return match }
        if let stufe { return plans.first { $0.stufenplan.stufe == stufe } }
        return plans.count == 1 ? plans[0] : nil
    }
}

// MARK: - Draft

/// Course choices being reviewed against one Stufenplan; the plan is rebuilt on every change.
struct CustomPlanDraft: Identifiable, Hashable {
    var id = UUID()
    var kurswahl: Kurswahl?
    var loaded: CustomPlanSource.Loaded
    var name: String
    var choices: [CustomPlan.Choice]
    /// Findings of the scan itself (unreadable cells, sheet of another Jahrgang).
    var scanIssues: [CustomPlan.Issue]
    var expectedTotal: Int?
    /// Courses found by the scan; an unrecognised row counts as handled once a subject was added.
    var initialChoiceCount = 0

    init(kurswahl: Kurswahl, loaded: CustomPlanSource.Loaded, name: String? = nil) {
        let built = CustomPlanBuilder.build(kurswahl: kurswahl, plan: loaded.stufenplan, halbjahr: loaded.item.halbjahr)
        self.kurswahl = kurswahl
        self.loaded = loaded
        self.name = name ?? built.name
        choices = built.choices
        scanIssues = built.checks.issues.filter { [.unreadable, .gradeMismatch, .unknownRow, .sumUnreadable, .inferred].contains($0.kind) }
        expectedTotal = built.checks.expectedTotal
        initialChoiceCount = built.choices.count
    }

    /// A saved plan against a (possibly newer) Stufenplan: same choices, or the sheet's
    /// choices of the new Halbjahr when the semester changed.
    init(saved: SavedCustomPlan, loaded: CustomPlanSource.Loaded) {
        let semesterChanged = loaded.item.halbjahr != saved.plan.halbjahr || loaded.stufenplan.stufe != saved.plan.stufe
        if semesterChanged, let kurswahl = saved.kurswahl {
            self = CustomPlanDraft(kurswahl: kurswahl, loaded: loaded, name: saved.plan.name)
            return
        }
        kurswahl = saved.kurswahl
        self.loaded = loaded
        name = saved.plan.name
        choices = saved.plan.choices
        scanIssues = []
        expectedTotal = saved.plan.checks.expectedTotal
    }

    var plan: CustomPlan {
        CustomPlanBuilder.build(name: name.trimmingCharacters(in: .whitespaces), choices: choices,
                                konfession: kurswahl?.konfession, plan: loaded.stufenplan,
                                halbjahr: loaded.item.halbjahr, expectedTotal: expectedTotal,
                                extraIssues: scanIssues.filter { $0.kind != .unknownRow || choices.count <= initialChoiceCount },
                                planSha256: loaded.item.pdf?.sha256)
    }

    var saved: SavedCustomPlan {
        var value = plan
        // hints about the photo itself do not belong to the saved plan
        value.checks.issues.removeAll { [.unknownRow, .sumUnreadable, .inferred].contains($0.kind) }
        return .init(plan: value, kurswahl: kurswahl, planTitle: loaded.item.title)
    }

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Review

/// The courses found, checked against the Stufenplan; every course can be corrected by hand.
///
/// Editing is a work state: picking, adding or removing a course only changes `draft.choices`, and
/// the rows read the Stufenplan directly. The plan itself is built once when the screen opens (for
/// the colours and hints of what the scan found) and once more on "Weiter", never per change.
struct CustomPlanReviewScreen: View {
    @State var draft: CustomPlanDraft
    let onSave: (SavedCustomPlan) -> Void
    /// The plan as the scan (or the saved plan) left it.
    private let initial: CustomPlan

    init(draft: CustomPlanDraft, onSave: @escaping (SavedCustomPlan) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
        initial = draft.plan
    }

    /// What one row shows, from the choice alone: a hand-picked course from the Stufenplan, any other
    /// from the initial plan.
    private struct RowInfo {
        var title: String
        var teachers: String?
        var hours: Int?
        var expectedHours: Int?
        var status: RowStatus
    }

    private func info(_ choice: CustomPlan.Choice) -> RowInfo {
        let name = CustomPlanLabels.subject(key: choice.subject)
        if let code = choice.code {
            let slots = draft.loaded.stufenplan.slots(for: code)
            var codes: [String] = []
            for teacher in slots.compactMap(\.teacher) where !codes.contains(teacher) { codes.append(teacher) }
            let teachers = codes.count == 1
                ? (SchoolReference.teacherName(codes[0]) ?? codes[0])
                : codes.map { SchoolReference.lastName($0) }.joined(separator: " / ")
            let level = choice.level == .leistungsfach ? "\(L.s("custom.level.short.LF")), " : ""
            let subject = CustomPlanLabels.subject(key: choice.subject, code: code)
            return RowInfo(title: "\(subject) (\(level)\(code))", teachers: codes.isEmpty ? nil : teachers,
                           hours: slots.reduce(0) { $0 + $1.hours }, expectedHours: nil, status: .fine)
        }
        guard let course = initial.courses.first(where: { $0.subjectKey == choice.subject }) else {
            return RowInfo(title: name, teachers: nil, hours: nil, expectedHours: nil, status: .problem)
        }
        return RowInfo(title: CustomPlanLabels.title(course), teachers: course.teacherLabel, hours: course.hours,
                       expectedHours: course.expectedHours, status: rowStatus(choice.subject, course: course, plan: initial))
    }

    var body: some View {
        let rows = Dictionary(draft.choices.map { ($0.id, info($0)) }, uniquingKeysWith: { first, _ in first })
        let total = draft.choices.reduce(0) { $0 + (rows[$1.id]?.hours ?? 0) }
        let marked = rows.values.contains { $0.status != .fine }
        let subjects = Set(draft.choices.map(\.subject))
        // hints about subjects still in the list; the total is shown by the hours row instead
        let issues = initial.checks.issues.filter { issue in
            issue.kind != .totalMismatch && (issue.subject.map(subjects.contains) ?? true)
        }
        List {
            // plain text on the page like the tutorial, not a card
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(L.s(marked ? "custom.review.greetingBodyMarked" : "custom.review.greetingBodyClean"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
            }

            Section {
                TextField(L.s("custom.review.namePlaceholder"), text: $draft.name)
                    .textContentType(.name)
                    .submitLabel(.done)
                LabeledContent(L.s("custom.review.plan"), value: "\(initial.stufe) · \(CustomPlanLabels.halbjahr(initial.halbjahr))")
                hoursRow(total: total, expected: initial.checks.expectedTotal)
            } header: {
                Text(L.s("custom.review.overview"))
            }

            if !issues.isEmpty {
                Section(L.s("custom.review.issues")) {
                    ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                        Label(issueText(issue, plan: initial), systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .symbolRenderingMode(.multicolor)
                    }
                }
            }

            Section {
                ForEach(draft.choices) { choice in
                    courseRow(choice, info: rows[choice.id] ?? info(choice))
                }
                .onDelete { offsets in
                    Haptics.medium()
                    draft.choices.remove(atOffsets: offsets)
                }
                addSubjectMenu
            } header: {
                Text(L.s("custom.review.courses"))
            } footer: {
                Text(L.s("custom.review.footer"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.s("custom.review.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L.s("custom.review.next")) {
                    Haptics.success()
                    // the edits become the plan only here
                    onSave(draft.saved)
                }
                .fontWeight(.semibold)
                .accessibilityIdentifier("customPlan.save")
            }
        }
    }

    /// "Hey Luka, …" with the first name from the sheet (or the edited name field).
    private var greeting: String {
        let first = draft.name.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? L.s("custom.review.greetingNoName") : L.f("custom.review.greeting", first)
    }

    private enum RowStatus { case fine, estimated, problem }

    /// Red: the course could not be matched, is missing or clashes; yellow: its hours were not readable
    /// on the sheet and were filled in from the rest of it.
    private func rowStatus(_ subject: String, course: CustomPlan.Course?, plan: CustomPlan) -> RowStatus {
        guard let course else { return .problem }
        let issues = plan.checks.issues
        let problems: Set<CustomPlan.Issue.Kind> = [.notInPlan, .ambiguous, .unreadable, .hoursMismatch]
        if issues.contains(where: { $0.subject == subject && problems.contains($0.kind) }) { return .problem }
        if issues.contains(where: { $0.kind == .conflict && !Set($0.codes).isDisjoint(with: course.codes + [course.id]) }) {
            return .problem
        }
        if issues.contains(where: { $0.kind == .inferred && $0.subject == subject }) { return .estimated }
        return .fine
    }

    /// The row's title carries the status; the row itself stays plain.
    private func titleColor(_ status: RowStatus) -> Color {
        switch status {
        case .fine: .primary
        // system yellow is unreadable on white, so a deeper yellow in light mode
        case .estimated: Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .systemYellow : UIColor(red: 0.8, green: 0.6, blue: 0, alpha: 1) })
        case .problem: .red
        }
    }

    private func hoursRow(total: Int, expected: Int?) -> some View {
        let matches = expected.map { $0 == total } ?? true
        return HStack {
            Image(systemName: matches ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(matches ? .green : .orange)
                .accessibilityHidden(true)
            // everyone's total differs: compare with the sheet, never show it as a goal
            if let expected, expected != total {
                Text(L.f("custom.review.hoursMismatch", total, expected))
            } else {
                Text(L.f("custom.review.hoursMatch", total))
            }
            Spacer()
        }
        .font(.subheadline.weight(.medium))
        .accessibilityElement(children: .combine)
    }

    private func courseRow(_ choice: CustomPlan.Choice, info: RowInfo) -> some View {
        let konfession = draft.kurswahl?.konfession
        let stufenplan = draft.loaded.stufenplan
        let name = CustomPlanLabels.subject(key: choice.subject)
        return Menu {
            // built when the menu opens, not for every row on every change
            let lf = CustomPlanBuilder.candidates(subject: choice.subject, level: .leistungsfach, konfession: konfession, plan: stufenplan)
            let basis = CustomPlanBuilder.candidates(subject: choice.subject, level: .basisfach, konfession: konfession, plan: stufenplan)
            if lf != basis {
                Section(L.s("custom.review.leistungsfach")) { codeButtons(lf, level: .leistungsfach, choice: choice) }
                Section(L.s("custom.review.basisfach")) { codeButtons(basis, level: .basisfach, choice: choice) }
            } else {
                codeButtons(lf, level: choice.level, choice: choice)
            }
            Section {
                Button(role: .destructive) {
                    Haptics.medium()
                    draft.choices.removeAll { $0.id == choice.id }
                } label: {
                    Label(L.f("custom.review.remove", name), systemImage: "trash")
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor(info.status))
                    if let hours = info.hours {
                        Text([info.teachers, L.f("custom.review.hours", hours)].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(info.expectedHours.map { $0 == hours } ?? true ? Color.secondary : Color.red)
                    } else {
                        Text(L.s("custom.review.pickCourse"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                    }
                    if info.status == .estimated {
                        Label(L.s("custom.review.estimated"), systemImage: "exclamationmark.circle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 0.62, green: 0.48, blue: 0))
                    }
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
    }

    @ViewBuilder
    private func codeButtons(_ codes: [String], level: CustomPlan.Level, choice: CustomPlan.Choice) -> some View {
        let current = choice.code ?? initial.courses.first { $0.subjectKey == choice.subject && $0.codes.count == 1 }?.codes.first
        ForEach(codes, id: \.self) { code in
            Button {
                Haptics.medium()
                guard let index = draft.choices.firstIndex(where: { $0.id == choice.id }) else { return }
                draft.choices[index].code = code
                draft.choices[index].level = level
                // a hand-picked course sets its own hours, so only the total is compared with the sheet
                draft.choices[index].hours = draft.loaded.stufenplan.slots(for: code).reduce(0) { $0 + $1.hours }
            } label: {
                let teacher = draft.loaded.stufenplan.slots(for: code).compactMap(\.teacher).first
                let text = "\(code) · \(teacher.map { SchoolReference.lastName($0) } ?? "")"
                if code == current {
                    Label(text, systemImage: "checkmark")
                } else {
                    Text(text)
                }
            }
        }
    }

    private var addSubjectMenu: some View {
        let taken = Set(draft.choices.map(\.subject))
        let konfession = draft.kurswahl?.konfession
        let plan = draft.loaded.stufenplan
        let available = SchoolReference.subjects.filter { subject in
            !taken.contains(subject.key)
                && !CustomPlanBuilder.candidates(subject: subject.key, level: nil, konfession: konfession, plan: plan).isEmpty
        }
        return Menu {
            ForEach(available, id: \.key) { subject in
                Menu(CustomPlanLabels.subject(key: subject.key)) {
                    ForEach(CustomPlanBuilder.candidates(subject: subject.key, level: nil, konfession: konfession, plan: plan), id: \.self) { code in
                        Button(code) {
                            Haptics.medium()
                            let parsed = CourseCode(code)
                            let both = Set(CustomPlanBuilder.candidates(subject: subject.key, level: nil, konfession: konfession, plan: plan)
                                .compactMap { CourseCode($0)?.capitalised }).count == 2
                            let level: CustomPlan.Level = both && parsed?.capitalised == true ? .leistungsfach : .basisfach
                            draft.choices.append(.init(subject: subject.key, level: level,
                                                       hours: plan.slots(for: code).reduce(0) { $0 + $1.hours },
                                                       parallel: parsed?.number, code: code))
                        }
                    }
                }
            }
        } label: {
            Label(L.s("custom.review.addSubject"), systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.medium))
        }
    }

    private func issueText(_ issue: CustomPlan.Issue, plan: CustomPlan) -> String {
        let name = issue.subject.map { CustomPlanLabels.subject(key: $0, code: issue.codes.first) } ?? ""
        switch issue.kind {
        case .unreadable: return L.f("custom.issue.unreadable", name)
        case .notInPlan: return L.f("custom.issue.notInPlan", name)
        case .ambiguous: return L.f("custom.issue.ambiguous", name, issue.codes.joined(separator: ", "))
        case .hoursMismatch: return L.f("custom.issue.hours", name)
        case .totalMismatch: return L.f("custom.issue.total", plan.checks.totalHours, plan.checks.expectedTotal ?? 0)
        case .conflict: return L.f("custom.issue.conflict", issue.codes.joined(separator: " & "))
        case .gradeMismatch: return L.s("custom.issue.grade")
        case .unknownRow: return L.f("custom.issue.unknownRow", issue.codes.first ?? "?")
        case .sumUnreadable: return L.s("custom.issue.sumUnreadable")
        case .inferred: return L.f("custom.issue.inferred", name)
        }
    }
}
