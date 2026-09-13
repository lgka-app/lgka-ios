import SwiftUI
import PDFKit
import LGKACore

/// PDF viewer — mirrors pdf_viewer_screen.dart: one page at a time (swipe for
/// the next page), share, and for schedule PDFs a class selector behind the
/// school icon that validates against the class index and jumps to the class
/// page (switching to the other schedule PDF when the class lives there).
/// Substitution plans get no search at all.
struct PdfViewerScreen: View {
    let fileUrl: URL
    let title: String
    /// 0-based page index to open on.
    let targetPage: Int?
    /// The schedule this PDF belongs to (grades discovered from its title); nil for substitution.
    var schedule: ScheduleItem? = nil
    /// class → real 1-based page for the schedule PDF (empty for substitution).
    var classIndex: [String: Int] = [:]

    @Environment(Prefs.self) private var prefs
    @Environment(HomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var document: PDFDocument?
    /// The file on screen: differs from `fileUrl` after a cross-PDF class switch.
    @State private var currentFile: URL?
    @State private var displayTitle = ""
    @State private var currentSchedule: ScheduleItem?
    @State private var currentIndex: [String: Int] = [:]
    @State private var shareUrl: URL?
    @State private var feedback: String?
    @State private var classInput = ""
    @State private var showClassBar = false
    @State private var showShare = false
    @State private var goToPage: Int?
    @FocusState private var classFocused: Bool

    private var isSchedule: Bool { currentSchedule != nil }

    var body: some View {
        NavigationStack {
            Group {
                if let document {
                    // timetable: one class page at a time; substitution plan: all pages in one vertical scroll
                    PdfKitView(document: document, paged: isSchedule, goToPageIndex: $goToPage)
                        .ignoresSafeArea(edges: .bottom)
                        .background(Color.appBackground)
                        .accessibilityLabel(displayTitle)
                } else {
                    ContentUnavailableView(L.s("errorLoading"), systemImage: "doc.questionmark")
                }
            }
            .navigationTitle(displayTitle.isEmpty ? title : displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Haptics.light(); dismiss() } label: {
                        Label(L.s("a11y.close"), systemImage: "xmark")
                    }
                    .accessibilityIdentifier("pdf.close")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isSchedule {
                        Button {
                            Haptics.light()
                            withAnimation(.snappy) { showClassBar.toggle() }
                            classFocused = showClassBar
                        } label: {
                            Label(L.s("a11y.changeClass"), systemImage: showClassBar ? "xmark" : "graduationcap")
                        }
                        .accessibilityIdentifier("pdf.changeClass")
                    }
                    // a Button (not ShareLink): toolbar items swallow simultaneous gestures, so
                    // the haptic fires here and the share sheet is presented explicitly
                    Button { Haptics.light(); showShare = true } label: {
                        Label(L.s("a11y.share"), systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("pdf.share")
                }
            }
            .safeAreaInset(edge: .top) {
                if showClassBar { classBar }
            }
            .sheet(isPresented: $showShare) {
                ActivityView(items: [shareUrl ?? currentFile ?? fileUrl])
                    .adaptiveSheetSizing()
            }
            .safeAreaInset(edge: .bottom) {
                if let feedback {
                    Text(feedback)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .glassEffect()
                        .padding(.bottom, 8)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .onAppear {
                document = PDFDocument(url: fileUrl)
                currentFile = fileUrl
                displayTitle = title
                currentSchedule = schedule
                currentIndex = classIndex
                shareUrl = makeShareUrl(fileUrl, title: title)
                if let targetPage { goToPage = max(0, targetPage) }
                // pdf_viewer parity: PDFs may rotate; app stays portrait
                OrientationLock.shared.allowAll()
            }
            .onDisappear {
                OrientationLock.shared.restorePortrait()
            }
        }
    }

    // ── Class selector (pdf_search_bar.dart parity) ─────────────────────────

    private var canSubmit: Bool { classInput.trimmingCharacters(in: .whitespaces).count >= 2 }

    private var classBar: some View {
        HStack(spacing: 10) {
            TextField(L.s("searchHint"), text: $classInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($classFocused)
                .onSubmit(submitClass)
                .accessibilityIdentifier("pdf.classInput")
            Button(L.s("setClassButton"), action: submitClass)
                .buttonStyle(.glassProminent)
                .disabled(!canSubmit)
                .accessibilityIdentifier("pdf.classSubmit")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: 20))
        .padding(.horizontal, 16).padding(.top, 6)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// Validates the class against the index (pdf_viewer_screen _validateAndSaveClass):
    /// unknown → "Klasse X existiert nicht.", known → persist, jump, confirm.
    private func submitClass() {
        let query = classInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard canSubmit else { return }
        Haptics.medium()
        guard ScheduleGrades.isClassToken(query) else {
            flash(L.f("noResults", query.uppercased()), error: true); return
        }
        if let current = currentSchedule, !current.covers(query) {
            switchPdf(className: query) // the class lives in another schedule PDF
            return
        }
        guard let page = currentIndex[query] else {
            flash(L.f("noResults", query.uppercased()), error: true); return
        }
        applyClass(query, page: page)
    }

    private func applyClass(_ cls: String, page: Int) {
        prefs.selectedScheduleClass = cls
        let name = L.className(cls)
        displayTitle = name
        shareUrl = makeShareUrl(currentFile ?? fileUrl, title: name)
        goToPage = max(0, page - 1) // API pages are 1-based
        classInput = ""
        classFocused = false
        withAnimation(.snappy) { showClassBar = false }
        Haptics.success()
        flash(L.f("classChanged", name))
    }

    private func flash(_ text: String, error: Bool = false) {
        if error { Haptics.error() }
        withAnimation { feedback = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { if feedback == text { feedback = nil } }
        }
    }

    /// Cross-PDF class switching (pdf_viewer_screen _navigateCrossPdf parity):
    /// the PDF whose discovered grades contain the class, whatever it is called.
    private func switchPdf(className: String) {
        guard let schedule = model.preferredGroup.first(where: { $0.covers(className) }),
              schedule.available, let pdf = schedule.pdf,
              let page = schedule.classIndex[className] else {
            flash(L.f("noResults", className.uppercased()), error: true)
            return
        }
        Task {
            do {
                let file = try await model.pdfURL(for: pdf)
                document = PDFDocument(url: file)
                currentFile = file
                currentSchedule = schedule
                currentIndex = schedule.classIndex
                applyClass(className, page: page)
            } catch {
                flash(L.s("serverConnectionFailed"), error: true)
            }
        }
    }

    /// Friendly share filename (pdf_share_service parity).
    private func makeShareUrl(_ source: URL, title: String) -> URL {
        let prefix = currentSchedule != nil || schedule != nil
            ? "LGKA_Stundenplan_" : "LGKA_Vertretungsplan_"
        let safe = title.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: "_")
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(prefix + (safe.isEmpty ? "Plan" : safe) + ".pdf")
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: source, to: dest)
        return dest
    }
}
