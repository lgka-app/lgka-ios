import SwiftUI
import UIKit

/// Example images of the custom timetable tutorial (WebP bundle resources), decoded off the main
/// thread once and kept for the session.
@MainActor
enum TutorialImages {
    static var sample: String { localized("kurswahl_sample") }
    static var good: String { localized("kurswahl_good") }
    static var bad: String { localized("kurswahl_bad") }
    /// The personal timetable PDF made from the sample sheet.
    static var result: String { localized("plan_result") }

    /// Every image exists once in German and once in English: "kurswahl_sample_de" / "_en", by app language.
    static func localized(_ base: String) -> String {
        base + (AppLanguage.shared.effective == "de" ? "_de" : "_en")
    }

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
