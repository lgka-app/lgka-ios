import CoreVideo
import Vision
import LGKACore
import LGKAPlanKit

/// Fast text recognition on a preview frame, turned into the Kurswahlprotokoll structure a photo
/// step needs (title, table header, subject column, cell values, "Summen" row).
enum KurswahlShotTracker {
    /// Runs on the camera's analysis queue; a few tenths of a second on current iPhones.
    static func structure(in buffer: CVPixelBuffer) -> ShotStructure {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
        guard (try? handler.perform([request])) != nil, let results = request.results else { return .empty }
        let boxes = results.compactMap { observation -> TextBox? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let b = observation.boundingBox // 0…1, origin bottom-left
            return TextBox(text: candidate.string, x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height,
                           confidence: Double(candidate.confidence))
        }
        return ShotStructure.analyse(boxes)
    }
}
