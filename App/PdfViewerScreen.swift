import SwiftUI
import PDFKit
import LGKACore

/// PDF viewer — mirrors pdf_viewer_screen.dart: share, in-PDF text search
/// with next/previous, optional target-page jump (schedule class page).
struct PdfViewerScreen: View {
    let fileUrl: URL
    let title: String
    let targetPage: Int? // display page (pageIndex + 2 contract)
    /// "Klassen 5-10" / "J11/J12" for schedule PDFs, nil for substitution.
    var gradeLevel: String? = nil

    @Environment(Prefs.self) private var prefs
    @Environment(HomeModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var document: PDFDocument?
    @State private var displayTitle = ""
    @State private var currentGrade: String?
    @State private var shareUrl: URL?
    @State private var feedback: String?
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var matches: [PDFSelection] = []
    @State private var matchIndex = 0
    @State private var currentSelection: PDFSelection?
    @State private var goToPage: Int?

    var body: some View {
        NavigationStack {
            Group {
                if let document {
                    PdfKitView(document: document,
                               highlight: currentSelection,
                               goToPageIndex: $goToPage)
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
                    Button {
                        Haptics.light()
                        withAnimation { showSearch.toggle() }
                    } label: {
                        Label(L.s("a11y.search"), systemImage: "magnifyingglass")
                    }
                    ShareLink(item: shareUrl ?? fileUrl) {
                        Label(L.s("a11y.share"), systemImage: "square.and.arrow.up")
                    }
                }
            }
            .searchable(text: $searchText, isPresented: $showSearch,
                        prompt: L.s("searchInPdf"))
            .onSubmit(of: .search, runSearch)
            .safeAreaInset(edge: .bottom) {
                if let feedback {
                    Text(feedback)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .glassEffect()
                        .padding(.bottom, 8)
                        .accessibilityAddTraits(.updatesFrequently)
                } else if !matches.isEmpty {
                    matchStepper
                }
            }
            .onAppear {
                document = PDFDocument(url: fileUrl)
                displayTitle = title
                currentGrade = gradeLevel
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

    private var matchStepper: some View {
        HStack(spacing: 16) {
            Text("\(matchIndex + 1)/\(matches.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel(L.f("a11y.matchPosition", matchIndex + 1, matches.count))
            Button { step(-1) } label: {
                Label(L.s("a11y.previousMatch"), systemImage: "chevron.up")
            }
            .buttonStyle(.glass)
            Button { step(1) } label: {
                Label(L.s("a11y.nextMatch"), systemImage: "chevron.down")
            }
            .buttonStyle(.glass)
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect()
        .padding(.bottom, 8)
    }

    private func runSearch() {
        guard let document, !searchText.isEmpty else { return }
        feedback = nil
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let isClass = query.wholeMatch(of: #/j1[12]|\d{1,2}[a-e]/#) != nil

        if let grade = currentGrade, isClass {
            // schedule-PDF parity: persist class; switch PDFs across groups
            prefs.selectedScheduleClass = query
            let targetGroup = query.hasPrefix("j") ? "J11/J12" : "Klassen 5-10"
            if targetGroup != grade {
                switchPdf(to: targetGroup, className: query)
                return
            }
        }
        matches = document.findString(searchText, withOptions: [.caseInsensitive])
        matchIndex = 0
        if matches.isEmpty {
            feedback = isClass ? L.f("noResults", query.uppercased()) : L.s("noMatches")
            Task { try? await Task.sleep(for: .seconds(2)); feedback = nil }
        } else {
            select(0)
        }
    }

    /// Cross-PDF class switching (pdf_viewer_screen _navigateCrossPdf parity).
    private func switchPdf(to group: String, className: String) {
        guard let schedule = model.preferredGroup
            .first(where: { $0.gradeLevel == group }) else {
            feedback = L.f("noResults", className.uppercased())
            return
        }
        Task {
            do {
                let (file, index) = try await SchoolAPI.schedulePdf(schedule)
                document = PDFDocument(url: file)
                currentGrade = group
                let half = schedule.halbjahr == "1. Halbjahr"
                    ? L.s("firstSemester") : L.s("secondSemester")
                let name = L.className(className)
                displayTitle = L.f("titleWithSemester", name, half)
                shareUrl = makeShareUrl(file, title: name)
                matches = []
                if let page = index[className] {
                    goToPage = max(0, page - 2)
                }
                feedback = L.f("classChanged", name)
                try? await Task.sleep(for: .seconds(2))
                feedback = nil
            } catch {
                feedback = L.s("serverConnectionFailed")
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

    private func step(_ delta: Int) {
        guard !matches.isEmpty else { return }
        Haptics.light()
        matchIndex = (matchIndex + delta + matches.count) % matches.count
        select(matchIndex)
    }

    private func select(_ index: Int) {
        guard matches.indices.contains(index) else { return }
        let selection = matches[index]
        selection.color = .systemYellow
        currentSelection = selection
        if let page = selection.pages.first, let document {
            goToPage = document.index(for: page)
        }
    }
}

struct PdfKitView: UIViewRepresentable {
    let document: PDFDocument
    let highlight: PDFSelection?
    @Binding var goToPageIndex: Int?

    func makeUIView(context: Context) -> JumpingPDFView {
        let view = JumpingPDFView()
        view.autoScales = true
        view.document = document
        return view
    }

    func updateUIView(_ view: JumpingPDFView, context: Context) {
        if view.document !== document { view.document = document }
        view.highlightedSelections = highlight.map { [$0] }
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
