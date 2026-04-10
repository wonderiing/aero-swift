import Foundation
import FoundationModels

/// Capa de Apple Intelligence / Foundation Models: generación de flashcards desde recursos, evaluación y explicaciones.
enum IntelligentStudyAssistant {

    static var isAppleIntelligenceReady: Bool {
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        case .unavailable:
            return false
        }
    }

    static func unavailabilityReasonDescription() -> String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return ""
        case .unavailable(let reason):
            return String(describing: reason)
        }
    }

    // MARK: Flashcards desde recursos seleccionados

    static func generateFlashcardsFromResources(
        resources: [(id: UUID, title: String, content: String)],
        depth: FlashcardGenerationService.Depth
    ) async throws -> [EditableFlashcard] {
        guard case .available = SystemLanguageModel.default.availability else {
            throw StudyAIError.modelUnavailable(unavailabilityReasonDescription())
        }

        let target = depth.approximateAICardCount
        let titleToId = Dictionary(uniqueKeysWithValues: resources.map { ($0.title, $0.id) })

        // Ventana de contexto del modelo on-device (~4096 tokens); recortamos por recurso.
        let material = resources.map { r in
            let body = String(r.content.prefix(3_500))
            return "### \(r.title)\n\(body)"
        }.joined(separator: "\n\n---\n\n")

        let resourceList = resources.map { "- \($0.title)" }.joined(separator: "\n")

        let session = LanguageModelSession(model: SystemLanguageModel.default) {
            "Eres un tutor experto que crea flashcards en español para estudiar."
            "Usa únicamente información presente en el material marcado como ### Título."
            "No inventes hechos ni citas que no aparezcan en el texto."
            "Para cardKind usa exactamente open o multiple_choice."
            "Para multiple_choice: mcCorrect es la opción correcta y mcDistractors debe tener exactamente 3 strings (distractores plausibles)."
            "Para open: mcCorrect y mcDistractors deben ir vacíos."
            "sourceResourceTitle debe ser exactamente uno de los títulos listados bajo RECURSOS."
        }

        let prompt = """
        RECURSOS (títulos exactos para sourceResourceTitle):
        \(resourceList)

        Genera aproximadamente \(target) flashcards de calidad a partir del material siguiente.

        MATERIAL:
        \(material)
        """

        let response = try await session.respond(
            to: prompt,
            generating: GeneratedFlashcardPack.self
        )
        let pack = response.content

        return pack.cards.compactMap { item in
            mapGeneratedItem(item, titleToId: titleToId, fallbackResourceId: resources.first?.id)
        }
    }

    private static func mapGeneratedItem(
        _ item: GeneratedFlashcardItem,
        titleToId: [String: UUID],
        fallbackResourceId: UUID?
    ) -> EditableFlashcard? {
        let q = item.question.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = item.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 4, a.count >= 2 else { return nil }

        let kind = item.cardKind.lowercased().replacingOccurrences(of: "-", with: "_")
        let type: FlashcardType = (kind == "multiple_choice") ? .multipleChoice : .open

        let rid = titleToId[item.sourceResourceTitle] ?? fallbackResourceId
        guard let resourceId = rid else { return nil }

        let tags = Array(item.conceptTags.prefix(3)).filter { !$0.isEmpty }
        let conceptTags = tags.isEmpty ? [String(a.prefix(24))] : tags

        var options: FlashcardOptions?
        if type == .multipleChoice {
            let correct = (item.mcCorrect ?? a).trimmingCharacters(in: .whitespacesAndNewlines)
            var dist = item.mcDistractors.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            while dist.count < 3 {
                dist.append("Opción alternativa no soportada por el texto.")
            }
            dist = Array(dist.prefix(3))
            options = FlashcardOptions(correct: correct, distractors: dist)
        }

        return EditableFlashcard(
            resourceId: resourceId,
            question: q,
            answer: a,
            type: type,
            options: options,
            conceptTags: conceptTags
        )
    }

    // MARK: Evaluación (práctica)

    static func evaluateStudentAnswer(
        question: String,
        correctAnswer: String,
        userAnswer: String?,
        cardType: FlashcardType,
        options: FlashcardOptions?
    ) async throws -> CreateAttemptDto {
        guard case .available = SystemLanguageModel.default.availability else {
            throw StudyAIError.modelUnavailable(unavailabilityReasonDescription())
        }

        let session = LanguageModelSession(model: SystemLanguageModel.default) {
            "Eres un tutor que evalúa respuestas de estudio en español."
            "Compara la respuesta del estudiante con la respuesta modelo."
            "Sé justo: respuestas parafraseadas correctas deben marcar isCorrect true."
            "errorTypeToken: vacío si isCorrect; si no, uno de: conceptual, memoria, confusion, incompleto."
            "confidenceScore entre 0 y 1."
        }

        let user = userAnswer ?? ""
        let optText: String
        if cardType == .multipleChoice, let o = options {
            optText = "Opción correcta: \(o.correct). Distractores: \(o.distractors.joined(separator: " | "))."
        } else {
            optText = "Tipo: pregunta abierta."
        }

        let prompt = """
        Pregunta: \(question)
        Respuesta modelo: \(correctAnswer)
        \(optText)
        Respuesta del estudiante: \(user)

        Devuelve la evaluación estructurada.
        """

        let response = try await session.respond(
            to: prompt,
            generating: GeneratedAnswerEvaluation.self
        )
        let ev = response.content

        let errToken = ev.errorTypeToken.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let mappedError: ErrorType? = {
            guard !ev.isCorrect, !errToken.isEmpty else { return nil }
            return ErrorType(rawValue: errToken)
        }()

        return CreateAttemptDto(
            userAnswer: userAnswer,
            isCorrect: ev.isCorrect,
            errorType: mappedError,
            missingConcepts: ev.missingConcepts,
            incorrectConcepts: ev.incorrectConcepts,
            feedback: ev.feedback,
            confidenceScore: min(1, max(0, ev.confidenceScore))
        )
    }

    // MARK: Explicar más

    static func expandExplanation(
        question: String,
        correctAnswer: String,
        userAnswer: String?,
        feedbackSoFar: String?,
        resourceContext: String?
    ) async throws -> String {
        guard case .available = SystemLanguageModel.default.availability else {
            throw StudyAIError.modelUnavailable(unavailabilityReasonDescription())
        }

        let session = LanguageModelSession(model: SystemLanguageModel.default) {
            "Explicas conceptos a un estudiante en español, con claridad y sin inventar fuera del contexto dado."
        }

        let ctx = (resourceContext ?? "").prefix(4_000)
        let prompt = """
        Pregunta: \(question)
        Respuesta esperada: \(correctAnswer)
        Respuesta del estudiante: \(userAnswer ?? "")
        Feedback previo: \(feedbackSoFar ?? "")
        Contexto del material (si existe): \(ctx)

        Amplía la explicación para que el estudiante entienda el concepto. No repitas exactamente el feedback previo.
        """

        let response = try await session.respond(
            to: prompt,
            generating: ConceptDeepExplanation.self
        )
        return response.content.text
    }
}

enum StudyAIError: LocalizedError {
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let r):
            return "Apple Intelligence no está disponible: \(r)"
        }
    }
}
