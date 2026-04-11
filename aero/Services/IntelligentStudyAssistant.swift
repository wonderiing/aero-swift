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
            case .low:    return 8
            case .medium: return 16
            case .high:   return 24
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
        // El modelo usa ~1.5 tokens/char en español. Instructions + schema (condensado) + output
        // consumen ~2600 tokens, dejando ~1500 tokens ≈ ~1000 chars para material.
        // Usamos 1800 chars como límite por chunk (ajustado tras condensar @Guide).
        let maxCharsPerChunk = 1_800
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

        // ── Fill passes: lotes de 6, máximo 4 intentos ──
        // Lotes un poco más grandes reducen llamadas totales; 4 intentos bastan
        // para alcanzar el target sin degradar tiempos.
        let allMaterial = chunks.map { $0.material }.joined(separator: "\n\n---\n\n")
        let allTitles = chunks.flatMap { $0.resourceList.components(separatedBy: "\n") }
            .filter { $0.hasPrefix("- ") }.joined(separator: "\n")
        let combinedChunk = MaterialChunk(
            resourceList: allTitles.isEmpty ? (chunks.first?.resourceList ?? "") : allTitles,
            material: String(allMaterial.prefix(3_000))
        )
        var fillAttempt = 0
        let batchSize = 6
        while allCards.count < target && fillAttempt < 4 {
            fillAttempt += 1
            let needed = target - allCards.count
            let thisBatch = min(needed, batchSize)
            fmLog("generateFlashcards", "  📋 fill \(fillAttempt) — pidiendo \(thisBatch) (faltan \(needed) de \(target))")
            do {
                let more = try await generateChunk(
                    chunk: combinedChunk,
                    cardsTarget: thisBatch,
                    titleToId: titleToId,
                    fallbackResourceId: resources.first?.id,
                    chunkIndex: 0,
                    totalChunks: 2
                )
                let existingQs = Set(allCards.map { String($0.question.lowercased().prefix(50)) })
                let unique = more.filter { !existingQs.contains(String($0.question.lowercased().prefix(50))) }
                if unique.isEmpty { break }
                allCards.append(contentsOf: unique)
                fmLog("generateFlashcards", "  fill \(fillAttempt) → +\(unique.count) (total: \(allCards.count)/\(target))")
            } catch {
                fmLog("generateFlashcards", "  ⚠️ fill \(fillAttempt) falló: \(error.localizedDescription)")
                break
            }
        }

        allCards = Array(allCards.prefix(target))
        fmLog("generateFlashcards", "✅ Final: \(allCards.count)/\(target) tarjetas")
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
        let rawNeeds = UserDefaults.standard.string(forKey: "accessibilityNeeds") ?? ""
        let needs = Set(rawNeeds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })

        let instructions = Instructions {
            "Eres un docente experto en diseño instruccional. Tu objetivo es crear flashcards que desarrollen comprensión profunda, no memorización superficial."
            "REGLAS DE CALIDAD:"
            "1. Basa cada pregunta en una idea central del material. Si la idea no está en el texto, no la uses."
            "2. Las preguntas abiertas ('open') deben pedir al estudiante que explique, relacione, compare, aplique o prediga. Nunca preguntar solo definiciones."
            "3. OPCIÓN MÚLTIPLE — mcCorrect y mcDistractors deben tener la MISMA LONGITUD (~8-12 palabras máximo) y misma estructura gramatical. mcCorrect es el INCISO CORTO correcto, NO la explicación larga de 'answer'. Los distractores son plausibles: errores típicos de estudiantes, inversiones de causa-efecto, datos casi correctos. Todos los incisos: mayúscula inicial, sin punto final."
            "4. La respuesta modelo debe ser didáctica: incluye el 'por qué' o el mecanismo, no solo el dato."
            "OBLIGATORIO: mezcla cardKind. Al menos el 50% deben ser 'open'. Alterna explícitamente entre tipos; nunca generes solo 'multiple_choice'."
            "sourceResourceTitle debe ser copia exacta del título del recurso en la lista RECURSOS."
            if needs.contains("dyslexia") {
                "IMPORTANTE (Dislexia): las preguntas deben ser cortas y directas. Evita oraciones compuestas largas."
            }
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

    // MARK: - Generación de tarjetas Anki

    static func generateAnkiCardsFromResources(
        resources: [(id: UUID, title: String, content: String)],
        depth: Depth,
        onProgress: (@Sendable (GenerationProgress) -> Void)? = nil
    ) async throws -> [EditableAnkiCard] {
        if !isAppleIntelligenceReady {
            fmLog("generateAnki", "⏳ Modelo no listo, esperando hasta 10s...")
            let ready = await waitForModelReadiness(timeout: 10)
            if !ready { throw StudyAIError.modelUnavailable(unavailabilityReasonDescription()) }
        }

        let target = depth.approximateCardCount
        let titleToId = Dictionary(uniqueKeysWithValues: resources.map { ($0.title, $0.id) })
        let maxCharsPerChunk = 1_800
        let chunks = buildMaterialChunks(resources: resources, maxCharsPerChunk: maxCharsPerChunk)
        let cardsPerChunk = max(2, target / max(1, chunks.count))

        fmLog("generateAnki", "→ depth=\(depth.rawValue) target=\(target) chunks=\(chunks.count)")

        var allCards: [EditableAnkiCard] = []
        var firstError: Error?

        for (idx, chunk) in chunks.enumerated() {
            onProgress?(GenerationProgress(completedChunks: idx, totalChunks: chunks.count))
            let cardsForChunk = (idx == chunks.count - 1) ? max(2, target - allCards.count) : cardsPerChunk
            do {
                let cards = try await generateAnkiChunk(
                    chunk: chunk,
                    cardsTarget: cardsForChunk,
                    titleToId: titleToId,
                    fallbackResourceId: resources.first?.id,
                    chunkIndex: idx,
                    totalChunks: chunks.count
                )
                allCards.append(contentsOf: cards)
                fmLog("generateAnki", "  chunk \(idx+1)/\(chunks.count) → \(cards.count) tarjetas (acumulado: \(allCards.count))")
            } catch {
                fmLog("generateAnki", "  ⚠️ chunk \(idx+1) falló: \(error.localizedDescription)")
                if firstError == nil { firstError = error }
            }
        }

        onProgress?(GenerationProgress(completedChunks: chunks.count, totalChunks: chunks.count))
        if allCards.isEmpty, let err = firstError { throw err }

        // Fill passes Anki — lotes de 6, máximo 4 intentos
        let ankiAllMaterial = chunks.map { $0.material }.joined(separator: "\n\n---\n\n")
        let ankiAllTitles = chunks.flatMap { $0.resourceList.components(separatedBy: "\n") }
            .filter { $0.hasPrefix("- ") }.joined(separator: "\n")
        let ankiCombinedChunk = MaterialChunk(
            resourceList: ankiAllTitles.isEmpty ? (chunks.first?.resourceList ?? "") : ankiAllTitles,
            material: String(ankiAllMaterial.prefix(3_000))
        )
        var fillAttempt = 0
        let ankiBatchSize = 6
        while allCards.count < target && fillAttempt < 4 {
            fillAttempt += 1
            let needed = target - allCards.count
            let thisBatch = min(needed, ankiBatchSize)
            fmLog("generateAnki", "  📋 fill \(fillAttempt) — pidiendo \(thisBatch) (faltan \(needed) de \(target))")
            do {
                let more = try await generateAnkiChunk(
                    chunk: ankiCombinedChunk,
                    cardsTarget: thisBatch,
                    titleToId: titleToId,
                    fallbackResourceId: resources.first?.id,
                    chunkIndex: 0,
                    totalChunks: 2
                )
                let existingQs = Set(allCards.map { String($0.front.lowercased().prefix(50)) })
                let unique = more.filter { !existingQs.contains(String($0.front.lowercased().prefix(50))) }
                if unique.isEmpty { break }
                allCards.append(contentsOf: unique)
                fmLog("generateAnki", "  fill \(fillAttempt) → +\(unique.count) (total: \(allCards.count)/\(target))")
            } catch { break }
        }

        // Recortar al número exacto pedido
        allCards = Array(allCards.prefix(target))
        fmLog("generateAnki", "✅ Final: \(allCards.count)/\(target) tarjetas Anki")
        return allCards
    }

    private static func generateAnkiChunk(
        chunk: MaterialChunk,
        cardsTarget: Int,
        titleToId: [String: UUID],
        fallbackResourceId: UUID?,
        chunkIndex: Int,
        totalChunks: Int
    ) async throws -> [EditableAnkiCard] {
        let instructions = Instructions {
            "Eres un experto en aprendizaje espaciado estilo Anki con dominio en didáctica y ciencias cognitivas."
            "PRINCIPIO FUNDAMENTAL: cada tarjeta debe pasar el 'test del buen Anki': el estudiante debe poder decir en <1 segundo si sabe o no sabe la respuesta al leer el frente."
            ""
            "REGLAS DEL FRENTE (pregunta/término):"
            "1. ATOMICIDAD: cubre exactamente UN concepto o hecho. Nunca 'A y B'."
            "2. CLARIDAD: máximo 12 palabras. La pregunta es inequívoca — solo hay una respuesta correcta posible."
            "3. VARIEDAD DE FORMATOS — rota entre estos estilos:"
            "   • Definición inversa: '¿Qué es [término]?' (solo si el término es técnico fundamental)"
            "   • Mecanismo: '¿Cómo [proceso] produce [resultado]?'"
            "   • Causa-efecto: '¿Qué provoca [fenómeno]?'"
            "   • Clasificación: '¿A qué categoría pertenece [concepto]?'"
            "   • Cloze implícito: '[Enunciado con espacio en blanco implícito]' → el dorso completa"
            "   • Comparación: '¿En qué se diferencia [A] de [B]?' (una diferencia clave)"
            "4. NUNCA preguntas ambiguas que admitan múltiples respuestas válidas."
            ""
            "REGLAS DEL DORSO (respuesta):"
            "1. RESPUESTA DIRECTA primero: la información que el estudiante necesita recordar, en 1 frase."
            "2. CONTEXTO MÍNIMO: si el concepto es abstracto, añade una segunda frase con un ejemplo concreto o analogía breve del propio material."
            "3. FÓRMULA OPCIONAL: si aplica (ciencias, matemáticas), incluye la fórmula o estructura clave."
            "4. NUNCA repitas la pregunta en la respuesta. NUNCA añadas explicaciones largas."
            "5. Longitud ideal: 15-40 palabras."
            ""
            "PRIORIZACIÓN DEL CONTENIDO:"
            "— Definiciones de términos técnicos centrales"
            "— Mecanismos o procesos explicados en el texto"
            "— Relaciones causales importantes"
            "— Números, fechas o datos cuantitativos significativos"
            "— NUNCA: datos triviales, ejemplos decorativos, información periférica"
            ""
            "sourceResourceTitle debe ser copia exacta del título del recurso en la lista RECURSOS."
        }

        let session = LanguageModelSession(instructions: instructions)

        let prompt: String
        if totalChunks == 1 {
            prompt = """
            RECURSOS:
            \(chunk.resourceList)

            Genera \(cardsTarget) tarjetas Anki (frente/dorso) a partir del siguiente material.

            MATERIAL:
            \(chunk.material)
            """
        } else {
            prompt = """
            RECURSOS:
            \(chunk.resourceList)

            Fragmento \(chunkIndex + 1) de \(totalChunks). Genera \(cardsTarget) tarjetas Anki de este fragmento.

            MATERIAL:
            \(chunk.material)
            """
        }

        fmLog("generateAnkiChunk", "  chunk \(chunkIndex+1)/\(totalChunks) → prompt=\(prompt.count)chars target=\(cardsTarget)")

        if totalChunks == 1 {
            return try await executeGeneration(tag: "generateAnkiChunk[\(chunkIndex)]") {
                try await session.respond(to: prompt, generating: GeneratedAnkiPack.self)
            } transform: { response in
                response.content.cards.compactMap {
                    mapGeneratedAnkiItem($0, titleToId: titleToId, fallbackResourceId: fallbackResourceId)
                }
            }
        } else {
            return try await executeGeneration(tag: "generateAnkiChunk[\(chunkIndex)]") {
                try await session.respond(to: prompt, generating: GeneratedAnkiChunk.self)
            } transform: { response in
                response.content.cards.compactMap {
                    mapGeneratedAnkiItem($0, titleToId: titleToId, fallbackResourceId: fallbackResourceId)
                }
            }
        }
    }

    private static func mapGeneratedAnkiItem(
        _ item: GeneratedAnkiItem,
        titleToId: [String: UUID],
        fallbackResourceId: UUID?
    ) -> EditableAnkiCard? {
        let front = item.front.trimmingCharacters(in: .whitespacesAndNewlines)
        let back = item.back.trimmingCharacters(in: .whitespacesAndNewlines)
        guard front.count >= 3, back.count >= 2 else { return nil }
        let rid = titleToId[item.sourceResourceTitle] ?? fallbackResourceId
        guard let resourceId = rid else { return nil }
        let tags = item.tags.prefix(3).filter { !$0.isEmpty }
        return EditableAnkiCard(
            resourceId: resourceId,
            front: front,
            back: back,
            tags: tags.isEmpty ? [String(front.prefix(20))] : Array(tags)
        )
    }

    // MARK: - Generación desde lagunas de conocimiento

    /// Genera flashcards enfocadas en los conceptos débiles detectados por el gap analysis.
    static func generateFlashcardsFromGaps(
        gaps: [ConceptGap],
        resources: [(id: UUID, title: String, content: String)],
        onProgress: (@Sendable (GenerationProgress) -> Void)? = nil
    ) async throws -> [EditableFlashcard] {
        guard !gaps.isEmpty else { return [] }

        if !isAppleIntelligenceReady {
            fmLog("generateFromGaps", "⏳ Modelo no listo, esperando hasta 10s...")
            let ready = await waitForModelReadiness(timeout: 10)
            if !ready {
                throw StudyAIError.modelUnavailable(unavailabilityReasonDescription())
            }
        }

        let conceptList = gaps.prefix(5).map { gap -> String in
            var line = "- \(gap.concept) (tasa de error: \(Int(gap.error_rate * 100))%"
            if let errorType = gap.dominant_error_type {
                line += ", tipo de error: \(errorType.rawValue)"
            }
            line += ")"
            return line
        }.joined(separator: "\n")

        let titleToId = Dictionary(uniqueKeysWithValues: resources.map { ($0.title, $0.id) })
        let maxCharsPerChunk = 1_800
        let chunks = buildMaterialChunks(resources: resources, maxCharsPerChunk: maxCharsPerChunk)

        fmLog("generateFromGaps", "→ \(gaps.prefix(5).count) lagunas, chunks=\(chunks.count)")

        var allCards: [EditableFlashcard] = []
        var firstError: Error?

        for (idx, chunk) in chunks.enumerated() {
            onProgress?(GenerationProgress(completedChunks: idx, totalChunks: chunks.count))
            do {
                let cards = try await generateChunkForGaps(
                    chunk: chunk,
                    conceptList: conceptList,
                    titleToId: titleToId,
                    fallbackResourceId: resources.first?.id,
                    chunkIndex: idx,
                    totalChunks: chunks.count
                )
                allCards.append(contentsOf: cards)
            } catch {
                fmLog("generateFromGaps", "  ⚠️ chunk \(idx+1) falló: \(error.localizedDescription)")
                if firstError == nil { firstError = error }
            }
        }

        onProgress?(GenerationProgress(completedChunks: chunks.count, totalChunks: chunks.count))

        if allCards.isEmpty, let err = firstError { throw err }
        fmLog("generateFromGaps", "✅ Total: \(allCards.count) tarjetas para lagunas")
        return allCards
    }

    private static func generateChunkForGaps(
        chunk: MaterialChunk,
        conceptList: String,
        titleToId: [String: UUID],
        fallbackResourceId: UUID?,
        chunkIndex: Int,
        totalChunks: Int
    ) async throws -> [EditableFlashcard] {
        let instructions = Instructions {
            "Eres un tutor experto en refuerzo de aprendizaje. Tu objetivo es crear flashcards para CORREGIR lagunas de conocimiento específicas del estudiante."
            "REGLAS:"
            "1. Cada tarjeta debe abordar directamente uno de los conceptos débiles listados."
            "2. Prioriza preguntas que ataquen el tipo de error del estudiante: si el error es 'conceptual', pregunta por el mecanismo o definición correcta; si es 'confusion', compara conceptos; si es 'incompleto', pide elaborar el concepto completo."
            "3. Mezcla tipos: al menos 50% abiertas ('open'). Las preguntas deben invitar a razonar, no solo a recordar."
            "4. La respuesta modelo debe ser didáctica y corregir directamente el error típico."
            "5. sourceResourceTitle debe ser copia exacta del título del recurso en la lista RECURSOS."
        }

        let session = LanguageModelSession(instructions: instructions)

        let prompt: String
        if totalChunks == 1 {
            prompt = """
            RECURSOS:
            \(chunk.resourceList)

            LAGUNAS DE CONOCIMIENTO DEL ESTUDIANTE (conceptos que necesita reforzar):
            \(conceptList)

            Genera 6 flashcards a partir del material, enfocadas en corregir las lagunas listadas.

            MATERIAL:
            \(chunk.material)
            """
        } else {
            prompt = """
            RECURSOS:
            \(chunk.resourceList)

            LAGUNAS DE CONOCIMIENTO DEL ESTUDIANTE (conceptos que necesita reforzar):
            \(conceptList)

            Fragmento \(chunkIndex + 1) de \(totalChunks). Genera 3 flashcards de este fragmento que aborden las lagunas.

            MATERIAL:
            \(chunk.material)
            """
        }

        return try await executeGeneration(tag: "generateGapChunk[\(chunkIndex)]") {
            try await session.respond(to: prompt, generating: GeneratedFlashcardChunk.self)
        } transform: { response in
            response.content.cards.compactMap {
                mapGeneratedItem($0, titleToId: titleToId, fallbackResourceId: fallbackResourceId)
            }
        }
    }

    // MARK: - Recursos de estudio desde lagunas

    /// Genera uno o más recursos (apuntes) enfocados en las lagunas, para guardar como `SDResource`.
    static func generateResourcesFromGaps(
        gaps: [ConceptGap],
        resources: [(id: UUID, title: String, content: String)],
        onProgress: (@Sendable (GenerationProgress) -> Void)? = nil
    ) async throws -> [GeneratedGapResourceDraft] {
        guard !gaps.isEmpty else { return [] }

        if !isAppleIntelligenceReady {
            fmLog("generateGapResources", "⏳ Modelo no listo, esperando hasta 10s...")
            let ready = await waitForModelReadiness(timeout: 10)
            if !ready {
                throw StudyAIError.modelUnavailable(unavailabilityReasonDescription())
            }
        }

        let conceptList = gaps.prefix(5).map { gap -> String in
            var line = "- \(gap.concept) (tasa de error: \(Int(gap.error_rate * 100))%"
            if let errorType = gap.dominant_error_type {
                line += ", tipo de error: \(errorType.rawValue)"
            }
            line += ")"
            return line
        }.joined(separator: "\n")

        let resourceList = resources.map { "- \($0.title)" }.joined(separator: "\n")
        let combinedMaterial: String
        if resources.isEmpty {
            combinedMaterial = "(No hay texto de recursos; elabora apuntes coherentes solo a partir de los nombres de lagunas y buenas prácticas pedagógicas generales.)"
        } else {
            let full = resources.map { "### \($0.title)\n\($0.content)" }.joined(separator: "\n\n---\n\n")
            combinedMaterial = String(full.prefix(4_500))
        }

        onProgress?(GenerationProgress(completedChunks: 0, totalChunks: 1))

        let instructions = Instructions {
            "Eres un docente que redacta materiales de estudio claros en español."
            "Tu objetivo es crear RECURSOS (apuntes) que ayuden a cerrar lagunas concretas del estudiante."
            "REGLAS:"
            "1. Basa el contenido en el MATERIAL DE REFERENCIA. No inventes hechos ni citas que no aparezcan o no se deduzcan del texto."
            "2. Cada recurso debe atacar al menos una laguna de la lista; indica en gapConcept cuál."
            "3. Tono didáctico: definición → intuición → error típico → ejemplo breve (del material)."
            "4. Usa Markdown con ## para secciones y listas donde mejore la lectura."
            "5. Si varias lagunas están relacionadas, puedes fusionarlas en un solo recurso, pero prioriza claridad."
        }

        let session = LanguageModelSession(instructions: instructions)
        let prompt = """
        RECURSOS DEL ESTUDIO (títulos):
        \(resourceList)

        LAGUNAS DE CONOCIMIENTO A REFORZAR:
        \(conceptList)

        MATERIAL DE REFERENCIA (prioridad para el contenido):
        \(combinedMaterial)

        Genera entre 1 y 5 recursos de apuntes. Si hay varias lagunas, intenta cubrir las más críticas primero (mayor tasa de error).
        """

        let drafts = try await executeGeneration(tag: "generateGapResources") {
            try await session.respond(to: prompt, generating: GeneratedGapResourcePack.self)
        } transform: { response in
            response.content.resources.compactMap { mapGeneratedGapResourceItem($0) }
        }

        onProgress?(GenerationProgress(completedChunks: 1, totalChunks: 1))
        fmLog("generateGapResources", "✅ \(drafts.count) recurso(s) generado(s)")
        return drafts
    }

    private static func mapGeneratedGapResourceItem(_ item: GeneratedGapResourceItem) -> GeneratedGapResourceDraft? {
        let t = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let g = item.gapConcept.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 3, c.count >= 80 else { return nil }
        return GeneratedGapResourceDraft(
            title: t,
            content: c,
            gapConcept: g.isEmpty ? String(t.prefix(48)) : g,
            isIncluded: true
        )
    }

    // MARK: - Evaluación

    static func evaluateStudentAnswer(
        question: String,
        correctAnswer: String,
        userAnswer: String?,
        cardType: FlashcardType,
        options: FlashcardOptions?
    ) async throws -> CreateAttemptDto {
        // ── Atajo MC: evaluación determinista, sin IA ──
        // Opción múltiple no necesita modelo — la respuesta es correcta o no.
        if cardType == .multipleChoice, let opts = options {
            let result = AnswerEvaluationService.evaluate(
                question: question,
                correctAnswer: correctAnswer,
                userAnswer: nil,
                selectedMultipleChoice: userAnswer,
                cardType: .multipleChoice,
                options: opts
            )
            fmLog("evaluateAnswer", "→ MC determinista (sin IA) isCorrect=\(result.isCorrect)")
            return result
        }

        // ── Atajo open: respuestas que claramente no intentan contestar ──
        if cardType == .open, let canned = AnswerEvaluationService.openAnswerIfClearlyNonAttempt(userAnswer: userAnswer) {
            fmLog("evaluateAnswer", "→ canned non-attempt (sin IA)")
            return canned
        }

        if !isAppleIntelligenceReady {
            let ready = await waitForModelReadiness(timeout: 5)
            if !ready {
                throw StudyAIError.modelUnavailable(unavailabilityReasonDescription())
            }
        }

        let rawNeeds = UserDefaults.standard.string(forKey: "accessibilityNeeds") ?? ""
        let needs = Set(rawNeeds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })

        let instructions = Instructions {
            "Eres un tutor justo que evalúa respuestas de estudio en español."
            "Evalúas si el estudiante demuestra comprensión del tema de la pregunta, no si copió la redacción modelo."
            "CRÍTICO — respuestas que NO cuentan como intento válido: texto sin relación con la pregunta, broma, relleno, slang evasivo (p. ej. \"nvm\", \"random\", \"lo que sea\"), o negaciones sin explicar (p. ej. solo \"no sé\" / \"ni idea\" sin ningún contenido sobre el tema). En todos esos casos: isCorrect=false, errorTypeToken=conceptual (o confusion si aplica), NUNCA uses incompleto."
            "incompleto SOLO cuando isCorrect=true: la respuesta SÍ trata el tema de la pregunta pero le faltan matices o ideas importantes. Si no trata el tema, no es incompleto — es incorrecta."
            "JERARQUÍA DE EVALUACIÓN (aplica en este orden):"
            "0. ¿La respuesta ignora el enunciado, es irrelevante o es evasiva sin sustancia? → isCorrect=false, errorTypeToken=conceptual."
            "1. ¿Afirma algo claramente erróneo sobre el tema? → isCorrect=false, errorTypeToken=conceptual o confusion."
            "2. ¿Aborda el tema y es razonablemente correcta pero le faltan ideas clave? → isCorrect=true, errorTypeToken=incompleto, missingConcepts."
            "3. ¿Aborda el tema y es adecuada? → isCorrect=true, errorTypeToken vacío."
            "Si dudas entre \"no intentó responder\" e \"incompleto\", elige \"no intentó\" (isCorrect=false). Sé exigente con la relevancia."
            "El feedback siempre constructivo y en español: si es incorrecta o irrelevante, di con claridad que debe responder al contenido de la pregunta."
            if needs.contains("adhd") {
                "IMPORTANTE (TDAH): el feedback breve y directo. Si la respuesta sí aborda el tema, puedes empezar con algo que hizo bien. Si es irrelevante o evasiva, no inventes elogios: di qué se pedía y anima a intentarlo."
            }
            if needs.contains("autism") {
                "IMPORTANTE (Autismo): usa lenguaje directo y concreto. Evita metáforas, sarcasmo o lenguaje ambiguo. Di exactamente qué faltó."
            }
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

        Criterio: si la respuesta no intenta responder al tema de la pregunta (irrelevante, evasiva o sin sustancia), isCorrect=false; no uses "incompleto" salvo que sí aborde el tema pero le falte profundidad.
        """

        fmLog("evaluateAnswer", "→ prompt=\(prompt.count)chars")

        return try await executeGeneration(tag: "evaluateAnswer") {
            try await session.respond(to: prompt, generating: GeneratedAnswerVerdict.self)
        } transform: { response in
            fmLog("evaluateAnswer", "✅ isCorrect=\(response.content.isCorrect)")
            let ev = response.content

            var errToken = ev.errorTypeToken.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            // Coherencia: "incompleto" solo con respuestas marcadas como correctas.
            if errToken == ErrorType.incompleto.rawValue, !ev.isCorrect {
                errToken = ErrorType.conceptual.rawValue
            }
            let mappedError: ErrorType? = errToken.isEmpty ? nil : ErrorType(rawValue: errToken)

            return CreateAttemptDto(
                userAnswer: userAnswer,
                isCorrect: ev.isCorrect,
                errorType: mappedError,
                missingConcepts: ev.missingConcepts,
                incorrectConcepts: ev.incorrectConcepts,
                feedback: nil,
                confidenceScore: min(1, max(0, ev.confidenceScore))
            )
        }
    }

    // MARK: - Feedback lazy (generado solo si el usuario lo pide)

    static func generateAnswerFeedback(
        question: String,
        correctAnswer: String,
        userAnswer: String?,
        isCorrect: Bool,
        errorType: String?
    ) async throws -> String {
        if !isAppleIntelligenceReady {
            let ready = await waitForModelReadiness(timeout: 5)
            if !ready {
                throw StudyAIError.modelUnavailable(unavailabilityReasonDescription())
            }
        }

        let rawNeeds = UserDefaults.standard.string(forKey: "accessibilityNeeds") ?? ""
        let needs = Set(rawNeeds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })

        let instructions = Instructions {
            "Eres un tutor que explica brevemente por qué una respuesta de estudio es correcta o incorrecta."
            "El feedback debe ser breve (2-4 frases), didáctico y en español."
            if needs.contains("adhd") {
                "IMPORTANTE (TDAH): sé directo y conciso. Si algo estuvo bien, menciona primero eso."
            }
            if needs.contains("autism") {
                "IMPORTANTE (Autismo): usa lenguaje directo y concreto. Sin metáforas ni ambigüedad."
            }
        }

        let session = LanguageModelSession(instructions: instructions)

        let verdict = isCorrect ? "CORRECTA" : "INCORRECTA"
        let errorHint = errorType.map { " (tipo de error: \($0))" } ?? ""
        let prompt = """
        Pregunta: \(question)
        Respuesta modelo: \(correctAnswer)
        Respuesta del estudiante: \(userAnswer ?? "")
        Veredicto: \(verdict)\(errorHint)

        Explica brevemente por qué la respuesta es \(verdict.lowercased()) y qué debería recordar el estudiante.
        """

        fmLog("generateAnswerFeedback", "→ prompt=\(prompt.count)chars")

        return try await executeGeneration(tag: "generateAnswerFeedback") {
            try await session.respond(to: prompt, generating: GeneratedAnswerFeedback.self)
        } transform: { response in
            fmLog("generateAnswerFeedback", "✅ \(response.content.feedback.count)chars")
            return response.content.feedback
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
        var resolvedType = type
        if type == .multipleChoice {
            let correct = item.mcCorrect.trimmingCharacters(in: .whitespacesAndNewlines)
            let dist = item.mcDistractors
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3)
            if dist.isEmpty {
                // Sin distractores → convertir a open en vez de descartar
                resolvedType = .open
            } else {
                let distArray = Array(dist)
                let rawCorrect = correct.isEmpty ? a : correct
                options = FlashcardOptions(
                    correct: normalizeOptionText(rawCorrect),
                    distractors: distArray.map { normalizeOptionText($0) }
                )
            }
        }

        return EditableFlashcard(
            resourceId: resourceId,
            question: q,
            answer: a,
            type: resolvedType,
            options: options,
            conceptTags: conceptTags
        )
    }

    /// Capitaliza primera letra, quita punto final.
    private static func normalizeOptionText(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasSuffix(".") { t = String(t.dropLast()) }
        guard let first = t.first else { return t }
        return first.uppercased() + t.dropFirst()
    }

    /// Recorta la respuesta correcta si es desproporcionadamente más larga que los distractores.
    /// Evita que sea obvia visualmente por su longitud.
    private static func balanceMCOption(_ correct: String, against distractors: [String]) -> String {
        guard !distractors.isEmpty else { return correct }
        let avgDistWords = max(1, distractors.map { $0.split(separator: " ").count }.reduce(0, +) / distractors.count)
        let correctWords = correct.split(separator: " ")
        if correctWords.count > Int(Double(avgDistWords) * 2.2) && avgDistWords > 3 {
            return correctWords.prefix(avgDistWords + 3).joined(separator: " ")
        }
        return correct
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
