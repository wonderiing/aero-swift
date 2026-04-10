import Foundation
import PDFKit
import Vision
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
        return try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err {
                    cont.resume(throwing: err)
                    return
                }
                let lines = (req.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                let text = lines.joined(separator: "\n")
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    cont.resume(throwing: DocumentTextExtractorError.noTextFound)
                } else {
                    cont.resume(returning: text)
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            if #available(iOS 16.0, *) {
                request.revision = VNRecognizeTextRequestRevision3
            }
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}
