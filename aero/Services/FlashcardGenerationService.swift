import Foundation

/// Genera borradores de flashcards a partir de texto (placeholder hasta Foundation Models).
enum FlashcardGenerationService {
    static func generateDrafts(from content: String, resourceId: UUID, depth: Depth = .medium) -> [EditableFlashcard] {
        let sentences = splitSentences(content)
        guard !sentences.isEmpty else { return [] }

        let target = depth.targetCount(clampedTo: sentences.count)
        var drafts: [EditableFlashcard] = []
        let otherSentences = sentences

        for i in 0..<target {
            let s = sentences[i % sentences.count]
            guard s.count > 25 else { continue }

            if i % 2 == 0 {
                let tags = tagsFor(s)
                drafts.append(
                    EditableFlashcard(
                        resourceId: resourceId,
                        question: "Explica con tus palabras: \(s.prefix(120))\(s.count > 120 ? "…" : "")",
                        answer: s,
                        type: .open,
                        options: nil,
                        conceptTags: tags
                    )
                )
            } else {
                let correct = s
                let distractors = (0..<3).compactMap { j -> String? in
                    let idx = (i + j + 1) % max(otherSentences.count, 1)
                    let alt = otherSentences[idx]
                    return alt != correct && alt.count > 15 ? String(alt.prefix(80)) : nil
                }
                let padded = distractors + [
                    "No se menciona en el texto.",
                    "Es un proceso no relacionado con el tema.",
                    "Ocurre solo en ausencia de luz."
                ]
                let three = Array(Set(padded).prefix(3))
                guard three.count == 3 else { continue }
                drafts.append(
                    EditableFlashcard(
                        resourceId: resourceId,
                        question: "¿Cuál afirmación resume mejor este punto del material?",
                        answer: String(correct.prefix(200)),
                        type: .multipleChoice,
                        options: FlashcardOptions(correct: String(correct.prefix(120)), distractors: three),
                        conceptTags: tagsFor(correct)
                    )
                )
            }
        }

        return drafts
    }

    enum Depth: String, CaseIterable, Identifiable {
        case low, medium, high
        var id: String { rawValue }

        func targetCount(clampedTo maxSentences: Int) -> Int {
            let base: Int
            switch self {
            case .low: base = 6
            case .medium: base = 12
            case .high: base = 20
            }
            return min(base, max(4, maxSentences))
        }

        /// Objetivo de tarjetas al pedir generación con Foundation Models.
        var approximateAICardCount: Int {
            switch self {
            case .low: return 6
            case .medium: return 12
            case .high: return 18
            }
        }
    }

    private static func splitSentences(_ text: String) -> [String] {
        var result: [String] = []
        text.replacingOccurrences(of: "\n", with: " ")
            .split(omittingEmptySubsequences: true) { $0 == "." || $0 == "?" || $0 == "!" }
            .forEach { chunk in
                let t = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.count > 20 { result.append(t + ".") }
            }
        if result.isEmpty {
            let paras = text.split(separator: "\n\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            return paras.filter { $0.count > 25 }
        }
        return result
    }

    private static func tagsFor(_ sentence: String) -> [String] {
        let stop: Set<String> = ["el", "la", "los", "las", "un", "una", "de", "en", "y", "a", "que", "es", "se", "del", "al"]
        let words = sentence
            .lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 4 && !stop.contains($0.lowercased()) }
        return Array(words.prefix(3))
    }
}
