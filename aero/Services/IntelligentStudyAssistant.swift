import Foundation
import FoundationModels

/// Capa de Apple Intelligence / Foundation Models.
enum IntelligentStudyAssistant {

    // MARK: - Disponibilidad

    static var isAppleIntelligenceReady: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// Razón específica de no-disponibilidad con mensaje accionable en español.
    static var unavailabilityReason: SystemLanguageModel.Availability.UnavailableReason? {
        if case .unavailable(let reason) = SystemLanguageModel.default.availability {
            return reason
        }
        return nil
    }

    static func unavailabilityReasonDescription() -> String {
        guard let reason = unavailabilityReason else { return "" }
        switch reason {
        case .deviceNotEligible:
            return "Este dispositivo no soporta Apple Intelligence. Necesitas un iPhone 15 Pro o posterior, o un iPad/Mac con chip M1+."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence no está activada. Ve a Ajustes → Apple Intelligence y Siri → activa Apple Intelligence."
        case .modelNotReady:
            return "El modelo se está descargando. Ve a Ajustes → Apple Intelligence y Siri y espera a que termine la descarga. Luego reinicia la app."
        @unknown default:
            return "Apple Intelligence no está disponible en este momento."
        }
    }

    /// Señal al sistema para pre-cargar el modelo antes de que el usuario genere tarjetas.
    static func prewarm() {
        guard isAppleIntelligenceReady else { return }
        let session = LanguageModelSession()
        session.prewarm()
        fmLog("prewarm", "→ pre-carga solicitada al sistema")
    }

    /// Espera breve (~10s max) a que el modelo pase a `.available` si está en `.modelNotReady`.
    /// Útil cuando los assets están casi listos.
    static func waitForModelReadiness(timeout: TimeInterval = 10) async -> Bool {
        if isAppleIntelligenceReady { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(500))
            if isAppleIntelligenceReady { return true }
        }
        return isAppleIntelligenceReady
    }

    // MARK: - Depth

    enum Depth: String, CaseIterable, Identifiable {
        case low, medium, high
        var id: String { rawValue }

        var approximateCardCount: Int {
            switch self {
            case .low:    return 5
            case .medium: return 10
            case .high:   return 15
            }
        }
    }

    // MARK: - Generación de flashcards

    /// Progreso reportado durante la generación chunked.
    /// `completedChunks` / `totalChunks` indica el avance real.
    struct GenerationProgress: Sendable {
        let completedChunks: Int
        let totalChunks: Int
        var fraction: Double { totalChunks > 0 ? Double(completedChunks) / Double(totalChunks) : 0 }
    }

    static func generateFlashcardsFromResources(
        resources: [(id: UUID, title: String, content: String)],
        depth: Depth,
        onProgress: (@Sendable (GenerationProgress) -> Void)? = nil
    ) async throws -> [EditableFlashcard] {
        // Esperar brevemente si el modelo está descargándose
        if !isAppleIntelligenceReady {
            fmLog("generateFlashcards", "⏳ Modelo no listo, esperando hasta 10s...")
            let ready = await waitForModelReadiness(timeout: 10)
            if !ready {
                throw StudyAIError.modelUnavailable(unavailabilityReasonDescription())
            }
        }

        let target = depth.approximateCardCount
        let titleToId = Dictionary(uniqueKeysWithValues: resources.map { ($0.title, $0.id) })

        // ── Dividir material en chunks que quepan en 4096 tokens ──
        // El modelo usa ~2 tokens/char en español. Instructions + schema + output
        // consumen ~3000 tokens, dejando ~1000 tokens ≈ ~500 chars para material.
        // Usamos 1500 chars como límite por chunk (conservador pero seguro).
        let maxCharsPerChunk = 1_500
        let chunks = buildMaterialChunks(resources: resources, maxCharsPerChunk: maxCharsPerChunk)
        let cardsPerChunk = max(2, target / max(1, chunks.count))

        fmLog("generateFlashcards", "→ depth=\(depth.rawValue) target=\(target) chunks=\(chunks.count) cardsPerChunk=\(cardsPerChunk)")

        // ── Generar chunk por chunk con sesiones frescas ──
        var allCards: [EditableFlashcard] = []
        var firstError: Error?

        for (idx, chunk) in chunks.enumerated() {
            onProgress?(GenerationProgress(completedChunks: idx, totalChunks: chunks.count))

            let cardsForThisChunk = (idx == chunks.count - 1)
                ? max(2, target - allCards.count)   // último chunk completa lo que falta
                : cardsPerChunk

            do {
                let cards = try await generateChunk(
                    chunk: chunk,
                    cardsTarget: cardsForThisChunk,
                    titleToId: titleToId,
                    fallbackResourceId: resources.first?.id,
                    chunkIndex: idx,
                    totalChunks: chunks.count
                )
                allCards.append(contentsOf: cards)
                fmLog("generateFlashcards", "  chunk \(idx+1)/\(chunks.count) → \(cards.count) tarjetas (acumulado: \(allCards.count))")
            } catch {
                fmLog("generateFlashcards", "  ⚠️ chunk \(idx+1) falló: \(error.localizedDescription)")
                if firstError == nil { firstError = error }
                // Continuar con los otros chunks si ya tenemos algunas tarjetas
            }
        }

        onProgress?(GenerationProgress(completedChunks: chunks.count, totalChunks: chunks.count))

        // Si no generamos nada, lanzar el primer error
        if allCards.isEmpty, let err = firstError { throw err }

        fmLog("generateFlashcards", "✅ Total: \(allCards.count) tarjetas de \(chunks.count) chunks")
        return allCards
    }

    /// Genera flashcards para un solo chunk de material (sesión fresca).
    private static func generateChunk(
        chunk: MaterialChunk,
        cardsTarget: Int,
        titleToId: [String: UUID],
        fallbackResourceId: UUID?,
        chunkIndex: Int,
        totalChunks: Int
    ) async throws -> [EditableFlashcard] {
        let instructions = Instructions {
            "Eres un profesor experto que crea flashcards pedagógicas en español."
            "Usa únicamente información del material proporcionado. No inventes datos."
            "Mezcla tipos: aproximadamente 60% open, 40% multiple_choice."
            "IMPORTANTE: Varía los estilos de pregunta. Usa comparaciones, causa-efecto, aplicación práctica, procesos, clasificación y relación entre conceptos. NO repitas '¿Qué es X?' más de 1 vez. Cada pregunta debe tener un enfoque diferente."
            "sourceResourceTitle debe ser una copia exacta del título del recurso."
        }

        let session = LanguageModelSession(instructions: instructions)

        let prompt: String
        if totalChunks == 1 {
            prompt = """
            RECURSOS:
            \(chunk.resourceList)

            Genera \(cardsTarget) flashcards a partir del siguiente material.

            MATERIAL:
            \(chunk.material)
            """
        } else {
            prompt = """
            RECURSOS:
            \(chunk.resourceList)

            Este es el fragmento \(chunkIndex + 1) de \(totalChunks) del material.
            Genera \(cardsTarget) flashcards a partir de este fragmento.

            MATERIAL:
            \(chunk.material)
            """
        }

        fmLog("generateChunk", "  chunk \(chunkIndex+1)/\(totalChunks) → prompt=\(prompt.count)chars target=\(cardsTarget)")

        // Elegir schema según tamaño: pack completo si 1 chunk, chunk pequeño si multi
        if totalChunks == 1 {
            return try await executeGeneration(tag: "generateChunk[\(chunkIndex)]") {
                try await session.respond(to: prompt, generating: GeneratedFlashcardPack.self)
            } transform: { response in
                response.content.cards.compactMap {
                    mapGeneratedItem($0, titleToId: titleToId, fallbackResourceId: fallbackResourceId)
                }
            }
        } else {
            return try await executeGeneration(tag: "generateChunk[\(chunkIndex)]") {
                try await session.respond(to: prompt, generating: GeneratedFlashcardChunk.self)
            } transform: { response in
                response.content.cards.compactMap {
                    mapGeneratedItem($0, titleToId: titleToId, fallbackResourceId: fallbackResourceId)
                }
            }
        }
    }

    // MARK: - Material chunking

    struct MaterialChunk {
        let resourceList: String
        let material: String
    }

    /// Divide los recursos en chunks que no excedan `maxChars` de material.
    /// Mantiene la integridad del texto: divide por recurso primero y por párrafos después.
    private static func buildMaterialChunks(
        resources: [(id: UUID, title: String, content: String)],
        maxCharsPerChunk: Int
    ) -> [MaterialChunk] {
        // Caso simple: todo cabe en un solo chunk
        let totalChars = resources.reduce(0) { $0 + $1.content.count + $1.title.count + 10 }
        if totalChars <= maxCharsPerChunk {
            let material = resources.map { "### \($0.title)\n\($0.content)" }.joined(separator: "\n\n---\n\n")
            let list = resources.map { "- \($0.title)" }.joined(separator: "\n")
            return [MaterialChunk(resourceList: list, material: material)]
        }

        // Dividir recurso por recurso, y si un recurso es muy largo dividirlo por párrafos
        var chunks: [MaterialChunk] = []
        var currentMaterial = ""
        var currentTitles: [String] = []
        var currentSize = 0

        for resource in resources {
            let segments = splitByParagraphs(text: resource.content, title: resource.title, maxChars: maxCharsPerChunk)

            for segment in segments {
                let segmentSize = segment.count
                if currentSize + segmentSize > maxCharsPerChunk && !currentMaterial.isEmpty {
                    // Flush current chunk
                    chunks.append(MaterialChunk(
                        resourceList: currentTitles.map { "- \($0)" }.joined(separator: "\n"),
                        material: currentMaterial
                    ))
                    currentMaterial = ""
                    currentTitles = []
                    currentSize = 0
                }
                if currentMaterial.isEmpty {
                    currentMaterial = segment
                } else {
                    currentMaterial += "\n\n---\n\n" + segment
                }
                if !currentTitles.contains(resource.title) {
                    currentTitles.append(resource.title)
                }
                currentSize += segmentSize
            }
        }

        // Flush remaining
        if !currentMaterial.isEmpty {
            chunks.append(MaterialChunk(
                resourceList: currentTitles.map { "- \($0)" }.joined(separator: "\n"),
                material: currentMaterial
            ))
        }

        return chunks.isEmpty
            ? [MaterialChunk(resourceList: "", material: "")]
            : chunks
    }

    /// Divide un recurso largo en segmentos por párrafos, respetando límites.
    private static func splitByParagraphs(text: String, title: String, maxChars: Int) -> [String] {
        let header = "### \(title)\n"
        let fullText = header + text

        if fullText.count <= maxChars {
            return [fullText]
        }

        // Dividir por párrafos (doble newline)
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var segments: [String] = []
        var current = header
        var partIndex = 1

        for paragraph in paragraphs {
            if current.count + paragraph.count + 2 > maxChars && current.count > header.count {
                segments.append(current)
                partIndex += 1
                current = "### \(title) (parte \(partIndex))\n"
            }
            current += paragraph + "\n\n"
        }
        if current.count > header.count {
            segments.append(current)
        }

        // Si un párrafo individual es más largo que maxChars, cortar por oraciones
        return segments.flatMap { segment -> [String] in
            if segment.count <= maxChars { return [segment] }
            return splitBySentences(segment: segment, maxChars: maxChars)
        }
    }

    /// Último recurso: corta por oraciones.
    private static func splitBySentences(segment: String, maxChars: Int) -> [String] {
        let sentences = segment.components(separatedBy: ". ")
        var results: [String] = []
        var current = ""
        for sentence in sentences {
            let piece = sentence.hasSuffix(".") ? sentence : sentence + "."
            if current.count + piece.count + 1 > maxChars && !current.isEmpty {
                results.append(current)
                current = ""
            }
            current += (current.isEmpty ? "" : " ") + piece
        }
        if !current.isEmpty { results.append(current) }
        return results
    }

    // MARK: - Evaluación

    static func evaluateStudentAnswer(
        question: String,
        correctAnswer: String,
        userAnswer: String?,
        cardType: FlashcardType,
        options: FlashcardOptions?
    ) async throws -> CreateAttemptDto {
        if !isAppleIntelligenceReady {
            let ready = await waitForModelReadiness(timeout: 5)
            if !ready {
                throw StudyAIError.modelUnavailable(unavailabilityReasonDescription())
            }
        }

        let instructions = Instructions {
            "Eres un tutor que evalúa respuestas de estudio en español."
            "Sé justo: respuestas parafraseadas correctas deben marcar isCorrect true."
            "errorTypeToken vacío si isCorrect; si no: conceptual, memoria, confusion o incompleto."
        }

        let session = LanguageModelSession(instructions: instructions)

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
        Respuesta del estudiante: \(userAnswer ?? "")
        """

        fmLog("evaluateAnswer", "→ prompt=\(prompt.count)chars")

        return try await executeGeneration(tag: "evaluateAnswer") {
            try await session.respond(to: prompt, generating: GeneratedAnswerEvaluation.self)
        } transform: { response in
            fmLog("evaluateAnswer", "✅ isCorrect=\(response.content.isCorrect)")
            let ev = response.content

            let errToken = ev.errorTypeToken.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let mappedError: ErrorType? = ev.isCorrect ? nil : ErrorType(rawValue: errToken)

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
    }

    // MARK: - Explicar más

    static func expandExplanation(
        question: String,
        correctAnswer: String,
        userAnswer: String?,
        feedbackSoFar: String?,
        resourceContext: String?
    ) async throws -> String {
        if !isAppleIntelligenceReady {
            let ready = await waitForModelReadiness(timeout: 5)
            if !ready {
                throw StudyAIError.modelUnavailable(unavailabilityReasonDescription())
            }
        }

        let instructions = Instructions {
            "Explicas conceptos a un estudiante en español con claridad y sin inventar fuera del contexto dado."
        }

        let session = LanguageModelSession(instructions: instructions)

        let ctx = (resourceContext ?? "").prefix(3_000)
        let prompt = """
        Pregunta: \(question)
        Respuesta esperada: \(correctAnswer)
        Respuesta del estudiante: \(userAnswer ?? "")
        Feedback previo: \(feedbackSoFar ?? "")
        Contexto del material: \(ctx)
        """

        fmLog("expandExplanation", "→ prompt=\(prompt.count)chars")

        return try await executeGeneration(tag: "expandExplanation") {
            try await session.respond(to: prompt, generating: ConceptDeepExplanation.self)
        } transform: { response in
            fmLog("expandExplanation", "✅ \(response.content.text.count)chars")
            return response.content.text
        }
    }

    // MARK: - Ejecución centralizada con reintentos

    /// Ejecuta una generación y mapea NSErrors opacos (como SensitiveContentAnalysis code 15)
    /// a nuestros StudyAIError legibles. Reintenta 1 vez en caso de `assetsUnavailable`.
    private static func executeGeneration<Content: Generable, Result>(
        tag: String,
        maxRetries: Int = 1,
        generation: () async throws -> LanguageModelSession.Response<Content>,
        transform: (LanguageModelSession.Response<Content>) throws -> Result
    ) async throws -> Result {
        var lastError: Error?
        for attempt in 0...maxRetries {
            if attempt > 0 {
                fmLog(tag, "🔄 Reintento \(attempt)/\(maxRetries) tras espera...")
                let ready = await waitForModelReadiness(timeout: 8)
                guard ready else { break }
            }
            do {
                let response = try await generation()
                return try transform(response)
            } catch let genErr as LanguageModelSession.GenerationError {
                fmLogGenerationError(tag, genErr)
                // Solo reintentar si los assets no estaban listos
                if case .assetsUnavailable = genErr, attempt < maxRetries {
                    lastError = translateGenerationError(genErr)
                    continue
                }
                throw translateGenerationError(genErr)
            } catch {
                // Capturar NSError opacos (e.g. SensitiveContentAnalysis, ModelManager)
                let nsErr = error as NSError
                fmLogNSError(tag, nsErr)
                if isModelNotReadyNSError(nsErr), attempt < maxRetries {
                    lastError = StudyAIError.modelAssetsNotReady
                    continue
                }
                throw mapNSError(nsErr)
            }
        }
        throw lastError ?? StudyAIError.generationFailed("Error desconocido tras reintentos")
    }

    /// Revisa la cadena de NSError para detectar ModelManagerError 1026 o SensitiveContentAnalysis 15.
    private static func isModelNotReadyNSError(_ error: NSError) -> Bool {
        if error.domain.contains("ModelManager") && error.code == 1026 { return true }
        if error.domain.contains("SensitiveContentAnalysis") { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isModelNotReadyNSError(underlying)
        }
        return false
    }

    /// Traduce NSError opacos a StudyAIError legibles.
    private static func mapNSError(_ error: NSError) -> StudyAIError {
        if isModelNotReadyNSError(error) {
            return .modelAssetsNotReady
        }
        return .generationFailed(error.localizedDescription)
    }

    // MARK: - Helpers privados

    private static func mapGeneratedItem(
        _ item: GeneratedFlashcardItem,
        titleToId: [String: UUID],
        fallbackResourceId: UUID?
    ) -> EditableFlashcard? {
        let q = item.question.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = item.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 4, a.count >= 2 else { return nil }

        let type: FlashcardType = item.cardKind == .multipleChoice ? .multipleChoice : .open
        let rid = titleToId[item.sourceResourceTitle] ?? fallbackResourceId
        guard let resourceId = rid else { return nil }

        let tags = item.conceptTags.prefix(3).filter { !$0.isEmpty }
        let conceptTags = tags.isEmpty ? [String(a.prefix(24))] : Array(tags)

        var options: FlashcardOptions?
        if type == .multipleChoice {
            let correct = item.mcCorrect.trimmingCharacters(in: .whitespacesAndNewlines)
            let dist = item.mcDistractors
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3)
            guard !dist.isEmpty else { return nil }
            options = FlashcardOptions(
                correct: correct.isEmpty ? a : correct,
                distractors: Array(dist)
            )
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

    private static func translateGenerationError(_ error: LanguageModelSession.GenerationError) -> StudyAIError {
        switch error {
        case .assetsUnavailable:
            return .modelAssetsNotReady
        case .exceededContextWindowSize:
            return .contextWindowExceeded
        case .guardrailViolation:
            return .guardrailViolation
        case .unsupportedLanguageOrLocale:
            return .unsupportedLanguage
        default:
            return .generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Logging

    private static func fmLog(_ fn: String, _ msg: String) {
        #if DEBUG
        print("[FM:\(fn)] \(msg)")
        #endif
    }

    private static func fmLogNSError(_ fn: String, _ error: NSError, depth: Int = 0) {
        #if DEBUG
        let indent = String(repeating: "  ", count: depth)
        print("[FM:\(fn)] \(indent)NSError domain:\(error.domain) code:\(error.code)")
        print("[FM:\(fn)] \(indent)  \(error.localizedDescription)")
        if error.domain.contains("ModelManager") && error.code == 1026 {
            print("[FM:\(fn)] \(indent)  ⚠️  Activos del modelo NO descargados")
            print("[FM:\(fn)] \(indent)     → Mac: Ajustes del Sistema → Apple Intelligence y Siri → espera descarga")
            print("[FM:\(fn)] \(indent)     → Simulador usa el modelo del Mac host (Apple Silicon requerido)")
        }
        if error.domain.contains("SensitiveContentAnalysis") {
            print("[FM:\(fn)] \(indent)  ⚠️  Filtro de contenido no listo — requiere descarga del modelo")
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            fmLogNSError(fn, underlying, depth: depth + 1)
        }
        #endif
    }

    private static func fmLogGenerationError(_ fn: String, _ error: LanguageModelSession.GenerationError) {
        #if DEBUG
        print("[FM:\(fn)] ❌ GenerationError:")
        switch error {
        case .assetsUnavailable(let ctx):
            print("[FM:\(fn)]   assetsUnavailable → \(ctx)")
            print("[FM:\(fn)]   ⚠️  Los activos del modelo no están descargados.")
            print("[FM:\(fn)]      Simulador: Settings → Privacy & Security → Sensitive Content Warning")
            print("[FM:\(fn)]      Dispositivo: Settings → Apple Intelligence & Siri → espera descarga")
        case .exceededContextWindowSize(let ctx):
            print("[FM:\(fn)]   exceededContextWindowSize → \(ctx)")
            print("[FM:\(fn)]   ⚠️  Reduce el tamaño del material o divide en recursos más pequeños.")
        case .guardrailViolation(let ctx):
            print("[FM:\(fn)]   guardrailViolation → \(ctx)")
        case .decodingFailure(let ctx):
            print("[FM:\(fn)]   decodingFailure → \(ctx)")
            print("[FM:\(fn)]   ⚠️  El modelo no pudo generar una respuesta con el schema correcto.")
        case .rateLimited(let ctx):
            print("[FM:\(fn)]   rateLimited → \(ctx)")
        case .refusal(let refusal, let ctx):
            print("[FM:\(fn)]   refusal → \(refusal) ctx:\(ctx)")
        case .concurrentRequests(let ctx):
            print("[FM:\(fn)]   concurrentRequests → \(ctx)")
        case .unsupportedGuide(let ctx):
            print("[FM:\(fn)]   unsupportedGuide → \(ctx)")
        case .unsupportedLanguageOrLocale(let ctx):
            print("[FM:\(fn)]   unsupportedLanguageOrLocale → \(ctx)")
        @unknown default:
            print("[FM:\(fn)]   unknown → \(error)")
        }
        #endif
    }
}

// MARK: - StudyAIError

enum StudyAIError: LocalizedError {
    case modelUnavailable(String)
    case modelAssetsNotReady
    case contextWindowExceeded
    case guardrailViolation
    case unsupportedLanguage
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let r):
            return "Apple Intelligence no está disponible: \(r)"
        case .modelAssetsNotReady:
            return "El modelo de IA aún no está listo. En el simulador activa Settings → Privacy & Security → Sensitive Content Warning y reinicia. En dispositivo ve a Ajustes → Apple Intelligence y espera la descarga completa."
        case .contextWindowExceeded:
            return "El material es demasiado largo. Divide el recurso en partes más pequeñas e inténtalo de nuevo."
        case .guardrailViolation:
            return "El contenido no puede procesarse por las políticas de seguridad del modelo."
        case .unsupportedLanguage:
            return "El idioma del contenido no está soportado por el modelo on-device."
        case .generationFailed(let reason):
            return "Error al generar: \(reason)"
        }
    }
}
