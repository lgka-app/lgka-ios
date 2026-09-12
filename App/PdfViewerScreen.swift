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
    let targetPage: Int? // display page (pageIndex + 2 contract)
    /// "Klassen 5-10" / "J11/J12" for schedule PDFs, nil for substitution.
    var gradeLevel: String? = nil
    /// class → display page for the schedule PDF (empty for substitution).
    var classIndex: [String: Int] = [:]

    @Environment(Prefs.self) private var prefs
    @Environment(HomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var document: PDFDocument?
    @State private var displayTitle = ""
    @State private var currentGrade: String?
    @State private var currentIndex: [String: Int] = [:]
    @State private var shareUrl: URL?
    @State private var feedback: String?
    @State private var classInput = ""
    @State private var showClassBar = false
    @State private var goToPage: Int?
    @FocusState private var classFocused: Bool

    private var isSchedule: Bool { currentGrade != nil }

    var body: some View {
        NavigationStack {
            Group {
                if let document {
                    PdfKitView(document: document, goToPageIndex: $goToPage)
                        .ignoresSafeArea(edges: .bottom)
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
                    ShareLink(item: shareUrl ?? fileUrl) {
                        Label(L.s("a11y.share"), systemImage: "square.and.arrow.up")
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                if showClassBar { classBar }
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
                displayTitle = title
                currentGrade = gradeLevel
                currentIndex = classIndex
                shareUrl = makeShareUrl(fileUrl, title: title)
                if let targetPage {
                    // stored contract: display page = zero-based index + 2
                    goToPage = max(0, targetPage - 2)
                }
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
        guard query.wholeMatch(of: #/j1[12]|\d{1,2}[a-e]/#) != nil else {
            flash(L.f("noResults", query.uppercased()), error: true); return
        }
        let targetGroup = query.hasPrefix("j") ? "J11/J12" : "Klassen 5-10"
        if targetGroup != currentGrade {
            switchPdf(to: targetGroup, className: query)
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
        shareUrl = makeShareUrl(fileUrl, title: name)
        goToPage = max(0, page - 2)
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

    /// Cross-PDF class switching (pdf_viewer_screen _navigateCrossPdf parity).
    private func switchPdf(to group: String, className: String) {
        guard let schedule = model.preferredGroup
            .first(where: { $0.gradeLevel == group }) else {
            flash(L.f("noResults", className.uppercased()), error: true)
            return
        }
        Task {
            do {
                let (file, index) = try await SchoolAPI.schedulePdf(schedule)
                guard let page = index[className] else {
                    flash(L.f("noResults", className.uppercased()), error: true); return
                }
                document = PDFDocument(url: file)
                currentGrade = group
                currentIndex = index
                applyClass(className, page: page)
            } catch {
                flash(L.s("serverConnectionFailed"), error: true)
            }
        }
    }

    /// Friendly share filename (pdf_share_service parity).
    private func makeShareUrl(_ source: URL, title: String) -> URL {
        let prefix = currentGrade != nil || gradeLevel != nil
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

/// One page at a time, swipe horizontally for the next (pdfx PdfView parity).
struct PdfKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var goToPageIndex: Int?

    func makeUIView(context: Context) -> JumpingPDFView {
        let view = JumpingPDFView()
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.usePageViewController(true, withViewOptions: nil)
        view.autoScales = true
        view.document = document
        return view
    }

    func updateUIView(_ view: JumpingPDFView, context: Context) {
        if view.document !== document { view.document = document }
        if let index = goToPageIndex, document.pageCount > 0 {
            view.jump(toPageIndex: min(max(0, index), document.pageCount - 1))
            Task { @MainActor in goToPageIndex = nil }
        }
    }
}

/// PDFKit drops `go(to:)` while the view has no layout yet (the class-page jump
/// arrived before the first `layoutSubviews`, so the schedule opened on page 1).
/// The request is kept until the view has bounds, then applied once — the
/// pdf_viewer_screen.dart `_tryJumpToPage` retry, without the polling.
final class JumpingPDFView: PDFView {
    private var pendingIndex: Int?

    func jump(toPageIndex index: Int) {
        pendingIndex = index
        applyPendingJump()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyPendingJump()
    }

    private func applyPendingJump() {
        guard let index = pendingIndex, bounds.width > 0, bounds.height > 0,
              let page = document?.page(at: index) else { return }
        pendingIndex = nil
        // one more turn of the run loop: autoScales settles its scale factor in this layout pass
        DispatchQueue.main.async { [weak self] in
            guard let self, self.document?.page(at: index) === page else { return }
            self.go(to: page)
        }
    }
}
