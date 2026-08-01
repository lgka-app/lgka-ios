import SwiftUI
import PDFKit

/// PDF viewer — mirrors pdf_viewer_screen.dart: share, in-PDF text search
/// with next/previous, optional target-page jump (schedule class page).
struct PdfViewerScreen: View {
    let fileUrl: URL
    let title: String
    let targetPage: Int? // display page (pageIndex + 2 contract)
    /// "Klassen 5-10" / "J11/J12" for schedule PDFs, nil for substitution.
    var gradeLevel: String? = nil

    @EnvironmentObject private var prefs: Prefs
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
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(displayTitle.isEmpty ? title : displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Haptics.light(); dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Haptics.light()
                        withAnimation { showSearch.toggle() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    ShareLink(item: shareUrl ?? fileUrl) {
                        Image(systemName: "square.and.arrow.up")
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
                AppDelegate.orientationLock = .all
            }
            .onDisappear {
                AppDelegate.orientationLock = .portrait
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                }
            }
        }
    }

    private var matchStepper: some View {
        HStack(spacing: 16) {
            Text("\(matchIndex + 1)/\(matches.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Button { step(-1) } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.glass)
            Button { step(1) } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.glass)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect()
        .padding(.bottom, 8)
    }

    private func runSearch() {
        guard let document, !searchText.isEmpty else { return }
        feedback = nil
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let isClass = query.range(of: "^(j1[12]|\\d{1,2}[a-e])$",
                                  options: .regularExpression) != nil

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
            feedback = isClass ? L.noResults(query)
                : (L.isGerman ? "Keine Treffer" : "No matches")
            Task { try? await Task.sleep(for: .seconds(2)); feedback = nil }
        } else {
            select(0)
        }
    }

    /// Cross-PDF class switching (pdf_viewer_screen _navigateCrossPdf parity).
    private func switchPdf(to group: String, className: String) {
        guard let schedule = HomeModel.shared.preferredGroup
            .first(where: { $0.gradeLevel == group }) else {
            feedback = L.noResults(className)
            return
        }
        Task {
            do {
                let (file, index) = try await SchoolAPI.schedulePdf(schedule)
                document = PDFDocument(url: file)
                currentGrade = group
                let half = schedule.halbjahr == "1. Halbjahr"
                    ? L.s("firstSemester") : L.s("secondSemester")
                let name = className == "j11" ? L.s("jahrgang11")
                    : className == "j12" ? L.s("jahrgang12")
                    : (L.isGerman ? "Klasse " : "Class ") + className.uppercased()
                displayTitle = "\(name) – \(half)"
                shareUrl = makeShareUrl(file, title: name)
                matches = []
                if let page = index[className] {
                    goToPage = max(0, page - 2)
                }
                feedback = L.classChanged(name)
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

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = document
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
        view.highlightedSelections = highlight.map { [$0] }
        if let index = goToPageIndex, let page = document.page(
            at: min(max(0, index), document.pageCount - 1)) {
            view.go(to: page)
            DispatchQueue.main.async { goToPageIndex = nil }
        }
    }
}
