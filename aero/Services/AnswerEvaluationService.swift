import Foundation

/// Evaluación on-device (sustituto/heurística hasta conectar Foundation Models).
/// Produce un `CreateAttemptDto` listo para `POST /flashcards/:id/attempts`.
enum AnswerEvaluationService {
    static func evaluate(
        question: String,
        correctAnswer: String,
        userAnswer: String?,
        selectedMultipleChoice: String?,
        cardType: FlashcardType,
        options: FlashcardOptions?
    ) -> CreateAttemptDto {
        switch cardType {
        case .open:
            return evaluateOpen(
                question: question,
                correctAnswer: correctAnswer,
                userAnswer: userAnswer ?? ""
            )
        case .multipleChoice:
            guard let opts = options else {
                return CreateAttemptDto(
                    userAnswer: selectedMultipleChoice,
                    isCorrect: false,
                    errorType: .confusion,
                    missingConcepts: [],
                    incorrectConcepts: [],
                    feedback: "Faltan opciones en la tarjeta.",
                    confidenceScore: 0
                )
            }
            return evaluateMultipleChoice(selected: selectedMultipleChoice, options: opts)
        }
    }

    private static func evaluateOpen(
        question: String,
        correctAnswer: String,
        userAnswer: String
    ) -> CreateAttemptDto {
        let user = normalize(userAnswer)
        let correct = normalize(correctAnswer)

        if user.isEmpty {
            return CreateAttemptDto(
                userAnswer: userAnswer,
                isCorrect: false,
                errorType: .memoria,
                missingConcepts: keyTokens(from: correctAnswer),
                incorrectConcepts: [],
                feedback: "No escribiste respuesta. Intenta explicar con tus palabras.",
                confidenceScore: 0.1
            )
        }

        if user == correct {
            return CreateAttemptDto(
                userAnswer: userAnswer,
                isCorrect: true,
                errorType: nil,
                missingConcepts: [],
                incorrectConcepts: [],
                feedback: "Correcto.",
                confidenceScore: 0.98
            )
        }

        let overlap = tokenOverlap(user: user, reference: correct)
        let containsCore = !correct.isEmpty && user.count >= 4 && correct.contains(user)
        let userContainsAnswer = !correct.isEmpty && user.contains(correct)

        let isCorrect = overlap >= 0.45 || containsCore || userContainsAnswer

        if isCorrect {
            return CreateAttemptDto(
                userAnswer: userAnswer,
                isCorrect: true,
                errorType: overlap < 0.65 ? .incompleto : nil,
                missingConcepts: overlap < 0.65 ? missingTokens(user: user, reference: correct) : [],
                incorrectConcepts: [],
                feedback: overlap < 0.65
                    ? "Correcto en esencia; podrías afinar algunos términos."
                    : "Muy bien, cubriste los conceptos clave.",
                confidenceScore: min(0.95, 0.55 + overlap * 0.5)
            )
        }

        let missing = missingTokens(user: user, reference: correct)
        let wrong = spuriousTokens(user: user, reference: correct)

        return CreateAttemptDto(
            userAnswer: userAnswer,
            isCorrect: false,
            errorType: wrong.isEmpty ? .incompleto : .conceptual,
            missingConcepts: Array(missing.prefix(3)),
            incorrectConcepts: Array(wrong.prefix(3)),
            feedback: buildFeedback(
                question: question,
                correctAnswer: correctAnswer,
                missing: missing,
                wrong: wrong
            ),
            confidenceScore: max(0.05, overlap)
        )
    }

    private static func evaluateMultipleChoice(selected: String?, options: FlashcardOptions) -> CreateAttemptDto {
        let sel = normalize(selected ?? "")
        let correctNorm = normalize(options.correct)
        let isCorrect = !sel.isEmpty && sel == correctNorm

        if isCorrect {
            return CreateAttemptDto(
                userAnswer: selected,
                isCorrect: true,
                errorType: nil,
                missingConcepts: [],
                incorrectConcepts: [],
                feedback: "Opción correcta.",
                confidenceScore: 1
            )
        }

        let wrongConcept = selected.map { [$0] } ?? []

        return CreateAttemptDto(
            userAnswer: selected,
            isCorrect: false,
            errorType: .confusion,
            missingConcepts: keyTokens(from: options.correct),
            incorrectConcepts: wrongConcept,
            feedback: "No es la opción correcta. La respuesta esperada era: \(options.correct).",
            confidenceScore: 0
        )
    }

    private static func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokens(_ s: String) -> Set<String> {
        let stop: Set<String> = ["el", "la", "los", "las", "un", "una", "de", "en", "y", "a", "que", "es", "se", "no", "al", "del", "por", "para", "con", "su", "the", "a", "an", "of", "in", "and", "to", "is", "are", "on", "at"]
        return Set(
            normalize(s).split(separator: " ").map(String.init).filter { $0.count > 2 && !stop.contains($0) }
        )
    }

    private static func tokenOverlap(user: String, reference: String) -> Double {
        let tu = tokens(user)
        let tr = tokens(reference)
        guard !tr.isEmpty else { return tu.isEmpty ? 1 : 0 }
        let hit = tu.intersection(tr).count
        return Double(hit) / Double(tr.count)
    }

    private static func keyTokens(from text: String) -> [String] {
        Array(tokens(text).prefix(3))
    }

    private static func missingTokens(user: String, reference: String) -> [String] {
        let tu = tokens(user)
        let tr = tokens(reference)
        return Array(tr.subtracting(tu).prefix(4))
    }

    private static func spuriousTokens(user: String, reference: String) -> [String] {
        let tu = tokens(user)
        let tr = tokens(reference)
        return Array(tu.subtracting(tr).prefix(4))
    }

    private static func buildFeedback(
        question: String,
        correctAnswer: String,
        missing: [String],
        wrong: [String]
    ) -> String {
        var parts: [String] = []
        if !wrong.isEmpty {
            parts.append("Hay conceptos que no encajan con la respuesta modelo.")
        }
        if !missing.isEmpty {
            parts.append("Faltó mencionar: \(missing.joined(separator: ", ")).")
        }
        parts.append("Repasa: \(correctAnswer.prefix(200))\(correctAnswer.count > 200 ? "…" : "")")
        return parts.joined(separator: " ")
    }
}
