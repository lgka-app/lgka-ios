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
    static func refreshed(_ saved: SavedCustomPlan, model: HomeModel) async -> SavedCustomPlan {
        guard let plans = try? await plans(model: model),
              let loaded = pick(plans, stufe: nil, kurswahl: saved.kurswahl) ?? pick(plans, stufe: saved.plan.stufe, kurswahl: nil),
              loaded.item.pdf?.sha256 != saved.plan.planSha256 else { return saved }
        let updated = CustomPlanDraft(saved: saved, loaded: loaded).saved
        CustomPlanStore.shared.save(updated)
        return updated
    }

    /// The plan rendered as its Untis-style PDF in Caches, named for sharing.
    static func pdfFile(for plan: CustomPlan) throws -> URL {
        let caches = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let owner = plan.name.isEmpty ? plan.stufe : plan.name
        let url = caches.appendingPathComponent("Stundenplan \(owner) \(plan.halbjahr).pdf")
        try CustomPlanPDF.render(plan).write(to: url, options: .atomic)
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

// MARK: - Setup

/// Explains the feature, then scans (guided camera) or picks a photo of the Kurswahlprotokoll.
struct CustomPlanSetupScreen: View {
    /// When set, the host shows the review; otherwise this screen pushes it itself.
    var onDraft: ((CustomPlanDraft) -> Void)?
    var onDone: (() -> Void)?
    @Environment(HomeModel.self) private var model
    @Environment(\.appAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var reading: UIImage?
    @State private var failure: String?
    @State private var draft: CustomPlanDraft?
    @State private var sweep = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                hero
                steps
                Label(L.s("custom.setup.privacy"), systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .surfaceCard()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .readableWidth()
        }
        .background(Color.appBackground)
        .navigationTitle(L.s("custom.title"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { actions }
        .overlay { if let reading { readingOverlay(reading) } }
        .fullScreenCover(isPresented: $showCamera) {
            KurswahlCameraScreen(onCapture: { images in
                showCamera = false
                read(images)
            }, onCancel: { showCamera = false })
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = KurswahlScanner.image(from: data) else {
                    failure = L.s("custom.error.photo")
                    return
                }
                read([image])
            }
        }
        .navigationDestination(item: $draft) { draft in
            CustomPlanReviewScreen(draft: draft) { value in
                CustomPlanStore.shared.save(value)
                self.draft = nil
                onDone?()
            }
        }
        .alert(failure ?? "", isPresented: .init(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) { Haptics.light() }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(accent)
                .symbolEffect(.pulse, options: .repeat(2), isActive: !reduceMotion)
                .frame(width: 96, height: 96)
                .glassEffect(.regular.tint(accent.opacity(0.12)), in: .rect(cornerRadius: 28))
                .accessibilityHidden(true)
            Text(L.s("custom.setup.title"))
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text(L.s("custom.setup.subtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 16) {
            step(1, "camera.viewfinder", L.s("custom.setup.step1"))
            step(2, "checklist", L.s("custom.setup.step2"))
            step(3, "tablecells", L.s("custom.setup.step3"))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }

    private func step(_ number: Int, _ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 36, height: 36)
                .background(accent.opacity(0.12), in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)
            Text(text).font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(number). \(text)")
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.medium()
                showCamera = true
            } label: {
                Label(L.s("custom.setup.scan"), systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.glassProminent)
            .tint(accent)
            .accessibilityIdentifier("customPlan.scan")
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(L.s("custom.setup.pick"), systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.glass)
            .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .disabled(reading != nil)
    }

    private func readingOverlay(_ image: UIImage) -> some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 22) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 300)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay {
                        // a light sweeping over the sheet while it is being read
                        GeometryReader { geo in
                            LinearGradient(colors: [.clear, accent.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: 60)
                                .offset(y: sweep ? geo.size.height - 30 : -30)
                        }
                        .clipShape(.rect(cornerRadius: 14))
                        .allowsHitTesting(false)
                        .opacity(reduceMotion ? 0 : 1)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { sweep = true }
                    }
                VStack(spacing: 6) {
                    Text(L.s("custom.reading.title")).font(.headline)
                    Text(L.s("custom.reading.subtitle")).font(.footnote).foregroundStyle(.secondary)
                }
                ProgressView()
            }
            .padding(32)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    private func read(_ images: [CGImage]) {
        guard let first = images.first else { return }
        withAnimation { reading = UIImage(cgImage: first) }
        sweep = false
        finish { try await KurswahlScanner.read(images) }
    }

    /// Reads the photos, loads the Stufenplan meanwhile, then shows the review.
    private func finish(_ scanned: @escaping @Sendable () async throws -> KurswahlScanner.Result) {
        Task {
            defer { withAnimation { reading = nil } }
            do {
                async let plans = CustomPlanSource.plans(model: model)
                let scan = try await scanned()
                let published = try await plans
                guard let loaded = CustomPlanSource.pick(published, stufe: nil, kurswahl: scan.kurswahl)
                        ?? CustomPlanSource.pick(published, stufe: nil, kurswahl: nil) else {
                    throw CustomPlanSource.Failure.noPlanPublished
                }
                #if DEBUG
                CustomPlanDebug.keep(scan)
                #endif
                Haptics.success()
                let next = CustomPlanDraft(kurswahl: scan.kurswahl, loaded: loaded)
                if let onDraft { onDraft(next) } else { draft = next }
            } catch is KurswahlParser.Failure {
                Haptics.error()
                failure = L.s("custom.error.notASheet")
            } catch CustomPlanSource.Failure.noPlanPublished {
                Haptics.error()
                failure = L.s("custom.error.noPlan")
            } catch {
                Haptics.error()
                failure = L.s("custom.error.generic")
            }
        }
    }
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
                LabeledContent(L.s("custom.review.plan"), value: "\(plan.stufe) · \(plan.halbjahr)")
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
            if let expected = plan.checks.expectedTotal {
                Text(L.f("custom.review.hoursOf", plan.checks.totalHours, expected))
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
                    Text(course?.title ?? name)
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
