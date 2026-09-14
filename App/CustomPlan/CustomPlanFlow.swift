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
    let onSaved: (SavedCustomPlan) -> Void
    @Environment(HomeModel.self) private var model
    @State private var reviewing: CustomPlanDraft?

    var body: some View {
        switch mode {
        case .scan:
            CustomPlanSetupScreen(onDraft: { reviewing = $0 })
                .navigationDestination(item: $reviewing) { draft in
                    CustomPlanReviewScreen(draft: draft) { save($0) }
                }
        case .edit:
            Group {
                if let reviewing {
                    CustomPlanReviewScreen(draft: reviewing) { save($0) }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task { await loadSaved() }
        }
    }

    private func save(_ value: SavedCustomPlan) {
        CustomPlanStore.shared.save(value)
        onSaved(value)
    }

    private func loadSaved() async {
        guard reviewing == nil, let saved = CustomPlanStore.shared.saved,
              let plans = try? await CustomPlanSource.plans(model: model),
              let loaded = CustomPlanSource.pick(plans, stufe: saved.plan.stufe, kurswahl: saved.kurswahl) else { return }
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
        try CustomPlanPDF.render(plan, labels: CustomPlanLabels.pdf).write(to: url, options: .atomic)
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
struct CustomPlanReviewScreen: View {
    @State var draft: CustomPlanDraft
    let onSave: (SavedCustomPlan) -> Void
    @Environment(\.appAccent) private var accent

    var body: some View {
        let plan = draft.plan
        List {
            Section {
                TextField(L.s("custom.review.namePlaceholder"), text: $draft.name)
                    .textContentType(.name)
                    .submitLabel(.done)
                LabeledContent(L.s("custom.review.plan"), value: "\(plan.stufe) · \(CustomPlanLabels.halbjahr(plan.halbjahr))")
                hoursRow(plan)
            }

            if !plan.checks.issues.isEmpty {
                Section(L.s("custom.review.issues")) {
                    ForEach(Array(plan.checks.issues.enumerated()), id: \.offset) { _, issue in
                        Label(issueText(issue, plan: plan), systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .symbolRenderingMode(.multicolor)
                    }
                }
            }

            Section {
                ForEach($draft.choices) { $choice in
                    courseRow($choice, plan: plan)
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
                Button(L.s("custom.review.save")) {
                    Haptics.success()
                    onSave(draft.saved)
                }
                .fontWeight(.semibold)
                .accessibilityIdentifier("customPlan.save")
            }
        }
    }

    private func hoursRow(_ plan: CustomPlan) -> some View {
        let matches = plan.checks.expectedTotal.map { $0 == plan.checks.totalHours } ?? true
        return HStack {
            Image(systemName: matches ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(matches ? .green : .orange)
                .accessibilityHidden(true)
            // everyone's total differs: compare with the sheet, never show it as a goal
            if let expected = plan.checks.expectedTotal, expected != plan.checks.totalHours {
                Text(L.f("custom.review.hoursMismatch", plan.checks.totalHours, expected))
            } else if plan.checks.expectedTotal != nil {
                Text(L.f("custom.review.hoursMatch", plan.checks.totalHours))
            } else {
                Text(L.f("custom.review.hours", plan.checks.totalHours))
            }
            Spacer()
        }
        .font(.subheadline.weight(.medium))
        .accessibilityElement(children: .combine)
    }

    private func courseRow(_ choice: Binding<CustomPlan.Choice>, plan: CustomPlan) -> some View {
        let value = choice.wrappedValue
        let course = plan.courses.first { $0.subjectKey == value.subject }
        let name = SchoolReference.subject(value.subject)?.name ?? value.subject
        let lf = CustomPlanBuilder.candidates(subject: value.subject, level: .leistungsfach,
                                              konfession: draft.kurswahl?.konfession, plan: draft.loaded.stufenplan)
        let basis = CustomPlanBuilder.candidates(subject: value.subject, level: .basisfach,
                                                 konfession: draft.kurswahl?.konfession, plan: draft.loaded.stufenplan)
        return Menu {
            if lf != basis {
                Section(L.s("custom.review.leistungsfach")) { codeButtons(lf, level: .leistungsfach, choice: choice) }
                Section(L.s("custom.review.basisfach")) { codeButtons(basis, level: .basisfach, choice: choice) }
            } else {
                codeButtons(lf, level: value.level, choice: choice)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.map(CustomPlanLabels.title) ?? name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let course {
                        Text("\(course.teacherLabel) · \(L.f("custom.review.hours", course.hours))")
                            .font(.caption)
                            .foregroundStyle(course.expectedHours == course.hours ? Color.secondary : Color.orange)
                    } else {
                        Text(L.s("custom.review.pickCourse"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)
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
    private func codeButtons(_ codes: [String], level: CustomPlan.Level, choice: Binding<CustomPlan.Choice>) -> some View {
        ForEach(codes, id: \.self) { code in
            Button {
                Haptics.medium()
                choice.wrappedValue.code = code
                choice.wrappedValue.level = level
                // a hand-picked course sets its own hours, so only the total is compared with the sheet
                choice.wrappedValue.hours = draft.loaded.stufenplan.slots(for: code).reduce(0) { $0 + $1.hours }
            } label: {
                let teacher = draft.loaded.stufenplan.slots(for: code).compactMap(\.teacher).first
                if choice.wrappedValue.code == code || (choice.wrappedValue.code == nil && draft.plan.courses.contains { $0.codes == [code] }) {
                    Label("\(code) · \(teacher.map { SchoolReference.lastName($0) } ?? "")", systemImage: "checkmark")
                } else {
                    Text("\(code) · \(teacher.map { SchoolReference.lastName($0) } ?? "")")
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
                Menu(subject.name) {
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
        let name = issue.subject.map { SchoolReference.subject($0)?.name ?? $0 } ?? ""
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
