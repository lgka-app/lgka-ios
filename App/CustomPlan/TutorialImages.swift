import SwiftUI
import UIKit

/// Example images of the custom timetable tutorial (WebP bundle resources), decoded off the main
/// thread once and kept for the session.
@MainActor
enum TutorialImages {
    static let sample = "kurswahl_sample"
    static let good = "kurswahl_good"
    static let bad = "kurswahl_bad"

    private static var cache: [String: UIImage] = [:]

    static func load(_ name: String) async -> UIImage? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "webp") else { return nil }
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            return await image.byPreparingForDisplay() ?? image
        }.value
        if let image { cache[name] = image }
        return image
    }
}

/// A tutorial image, or a calm placeholder while it loads or when the file is missing.
struct TutorialImage: View {
    let name: String
    let aspect: CGFloat
    var symbol = "doc.text.image"
    @State private var image: UIImage?

    var body: some View {
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    ZStack {
                        Rectangle().fill(.quaternary)
                        Image(systemName: symbol)
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .clipped()
            .task(id: name) {
                let loaded = await TutorialImages.load(name)
                withAnimation(.easeOut(duration: 0.25)) { image = loaded }
            }
    }
}

/// Full-screen, pinch-to-zoom viewer for the sample sheet.
struct TutorialImageViewer: View {
    let name: String
    let label: String
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: geo.size.width * scale, height: geo.size.height * scale)
                }
                .scrollBounceBehavior(.basedOnSize)
                .gesture(
                    MagnifyGesture()
                        .onChanged { scale = min(4, max(1, baseScale * $0.magnification)) }
                        .onEnded { _ in baseScale = scale }
                )
                .onTapGesture(count: 2) {
                    Haptics.light()
                    withAnimation(.snappy) { scale = scale > 1 ? 1 : 2.5 }
                    baseScale = scale
                }
            }
            .background(Color.appBackground)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.light(); dismiss() } label: {
                        Label(L.s("a11y.close"), systemImage: "xmark")
                    }
                }
            }
            .task { image = await TutorialImages.load(name) }
        }
    }
}
