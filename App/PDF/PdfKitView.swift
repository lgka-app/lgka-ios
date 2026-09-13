import SwiftUI
import PDFKit

/// `paged`: one page at a time, swipe horizontally (the timetable class page);
/// otherwise every page in one vertical scroll (the substitution plan).
struct PdfKitView: UIViewRepresentable {
    let document: PDFDocument
    let paged: Bool
    @Binding var goToPageIndex: Int?

    func makeUIView(context: Context) -> JumpingPDFView {
        let view = JumpingPDFView()
        // the app's grouped background instead of PDFKit's default grey, in both appearances
        view.backgroundColor = .systemGroupedBackground
        if paged {
            view.displayMode = .singlePage
            view.displayDirection = .horizontal
            view.usePageViewController(true, withViewOptions: nil)
        } else {
            view.displayMode = .singlePageContinuous
            view.displayDirection = .vertical
            view.pageBreakMargins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        }
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Never let a pinch leave the page smaller than the screen: the scroll view
        // rubber-bands back to the fit scale, and a stray smaller scale snaps back.
        // (selector observers are removed automatically on deallocation)
        NotificationCenter.default.addObserver(self, selector: #selector(scaleChanged),
                                               name: .PDFViewScaleChanged, object: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func scaleChanged() { snapBackIfTooSmall() }

    func jump(toPageIndex index: Int) {
        pendingIndex = index
        applyPendingJump()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        clampZoomToFit()
        applyPendingJump()
    }

    /// Fit-to-screen is the floor; four times that is the ceiling.
    private func clampZoomToFit() {
        let fit = scaleFactorForSizeToFit
        guard fit > 0, document != nil else { return }
        minScaleFactor = fit
        maxScaleFactor = fit * 4
        if scaleFactor < fit { scaleFactor = fit }
    }

    private func snapBackIfTooSmall() {
        let fit = scaleFactorForSizeToFit
        guard fit > 0, scaleFactor < fit * 0.999 else { return }
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            self.scaleFactor = fit
        }
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
