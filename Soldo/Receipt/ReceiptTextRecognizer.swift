import CoreImage
import Foundation
import UIKit
@preconcurrency import Vision

/// Runs Vision's text recogniser and rebuilds the receipt's visual lines.
///
/// Vision returns one observation per text block, so "TOTALE" and "12,50" arrive
/// separately even though they are printed on the same row. Grouping observations
/// by their vertical position is what lets the parser see `TOTALE 12,50`.
enum ReceiptTextRecognizer {

    enum RecognizerError: LocalizedError {
        case noImage
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .noImage: "Immagine non leggibile."
            case .recognitionFailed(let reason): "Lettura non riuscita: \(reason)"
            }
        }
    }

    static func recognizeLines(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw RecognizerError.noImage }
        return try await recognizeLines(in: cgImage, orientation: image.imageOrientation.cgOrientation)
    }

    static func recognizeLines(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation = .up
    ) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            // Vision's request and handler are built inside the work item so neither
            // has to cross a concurrency boundary.
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["it-IT", "en-US"]
                // Receipts are full of codes and abbreviations that autocorrection mangles.
                request.usesLanguageCorrection = false

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    continuation.resume(returning: assembleLines(from: observations))
                } catch {
                    continuation.resume(throwing: RecognizerError.recognitionFailed(error.localizedDescription))
                }
            }
        }
    }

    /// Groups observations that sit on the same printed row, left to right.
    static func assembleLines(from observations: [VNRecognizedTextObservation]) -> [String] {
        struct Fragment {
            let text: String
            let midY: CGFloat
            let minX: CGFloat
            let height: CGFloat
        }

        let fragments: [Fragment] = observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return Fragment(text: candidate.string, midY: box.midY, minX: box.minX, height: box.height)
        }
        guard !fragments.isEmpty else { return [] }

        // Vision's origin is bottom-left, so the top of the receipt has the highest y.
        let sorted = fragments.sorted { $0.midY > $1.midY }
        let tolerance = max(sorted.map(\.height).reduce(0, +) / CGFloat(sorted.count) * 0.6, 0.008)

        var rows: [[Fragment]] = []
        for fragment in sorted {
            if let last = rows.last, let reference = last.first,
               abs(reference.midY - fragment.midY) <= tolerance {
                rows[rows.count - 1].append(fragment)
            } else {
                rows.append([fragment])
            }
        }

        return rows.map { row in
            row.sorted { $0.minX < $1.minX }
                .map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
        }
        .filter { !$0.isEmpty }
    }
}

extension UIImage.Orientation {
    var cgOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
