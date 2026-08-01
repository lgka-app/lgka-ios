import SwiftUI
import PDFKit

/// PDF viewer — mirrors pdf_viewer_screen.dart: share, in-PDF text search
/// with next/previous, optional target-page jump (schedule class page).
struct PdfViewerScreen: View {
    let fileUrl: URL
    let title: String
    let targetPage: Int? // display page (pageIndex + 2 contract)

    @EnvironmentObject private var prefs: Prefs
    @Environment(\.dismiss) private var dismiss
    @State private var document: PDFDocument?
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
            .navigationTitle(title)
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
                    ShareLink(item: fileUrl) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .searchable(text: $searchText, isPresented: $showSearch,
                        prompt: L.s("searchInPdf"))
            .onSubmit(of: .search, runSearch)
            .safeAreaInset(edge: .bottom) {
                if !matches.isEmpty { matchStepper }
            }
            .onAppear {
                document = PDFDocument(url: fileUrl)
                if let targetPage {
                    // stored contract: display page = zero-based index + 2
                    goToPage = max(0, targetPage - 2)
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
        // schedule-PDF parity: searching a class persists it as your class
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if targetPage != nil,
           query.range(of: "^(j1[12]|\\d{1,2}[a-e])$", options: .regularExpression) != nil {
            prefs.selectedScheduleClass = query
        }
        matches = document.findString(searchText, withOptions: [.caseInsensitive])
        matchIndex = 0
        select(0)
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
