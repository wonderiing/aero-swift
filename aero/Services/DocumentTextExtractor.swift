import Foundation
import PDFKit
@preconcurrency import Vision
import UIKit

enum DocumentTextExtractorError: Error {
    case emptyPDF
    case noTextFound
}

enum DocumentTextExtractor {
    /// Extrae texto de PDF (PDFKit) o imagen (Vision OCR).
    static func extractText(from url: URL) async throws -> String {
        let isPDF = url.pathExtension.lowercased() == "pdf"
        if isPDF {
            return try extractPDF(url: url)
        }
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else {
            throw DocumentTextExtractorError.noTextFound
        }
        return try await recognizeText(in: image)
    }

    private static func extractPDF(url: URL) throws -> String {
        guard let doc = PDFDocument(url: url) else { throw DocumentTextExtractorError.emptyPDF }
        var parts: [String] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i), let s = page.string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { continue }
            parts.append(s)
        }
        let joined = parts.joined(separator: "\n\n")
        guard !joined.isEmpty else { throw DocumentTextExtractorError.emptyPDF }
        return joined
    }

    private static func recognizeText(in image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { throw DocumentTextExtractorError.noTextFound }

        // Task.detached keeps all Vision types within the same concurrency context,
        // eliminating Sendable capture warnings entirely.
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            if #available(iOS 16.0, *) {
                request.revision = VNRecognizeTextRequestRevision3
            }

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try handler.perform([request])

            let lines = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
            let text = lines.joined(separator: "\n")

            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DocumentTextExtractorError.noTextFound
            }
            return text
        }.value
    }
}
