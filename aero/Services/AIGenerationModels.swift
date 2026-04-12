import Foundation
import FoundationModels

// MARK: - Flashcards

/// Tipo de flashcard como enum constrained: el modelo solo puede generar estos dos valores.
@Generable
enum GeneratedCardKind: String, CaseIterable {
    case open
    case multipleChoice = "multiple_choice"
}

@Generable(description: "Lote de flashcards pedagógicas basadas en el material de estudio")
struct GeneratedFlashcardPack {
    @Guide(description: "Lista de flashcards generadas", .minimumCount(8), .maximumCount(30))
    var cards: [GeneratedFlashcardItem]
}

/// Lote pequeño para generación chunked (material largo dividido en partes).
@Generable(description: "Lote pequeño de flashcards de un fragmento de material")
struct GeneratedFlashcardChunk {
    @Guide(description: "Flashcards generadas de este fragmento", .minimumCount(3), .maximumCount(8))
    var cards: [GeneratedFlashcardItem]
}

@Generable
struct GeneratedFlashcardItem {
    @Guide(description: "Pregunta en español que teste comprensión profunda (comparar, explicar causa-efecto, aplicar, predecir). Basada solo en el material. Clara y directa.")
    var question: String

    @Guide(description: "Respuesta didáctica: máximo 3 frases, incluye el por qué o mecanismo, no solo el dato.")
    var answer: String

    @Guide(description: "~60% open, ~40% multiple_choice. Alterna tipos.")
    var cardKind: GeneratedCardKind

    @Guide(description: "Solo multiple_choice: respuesta correcta concisa (8-12 palabras). Open: vacío.")
    var mcCorrect: String

    @Guide(description: "Solo multiple_choice: 3 distractores plausibles, misma longitud que mcCorrect. Open: vacío.", .maximumCount(3))
    var mcDistractors: [String]

    @Guide(description: "1-3 términos clave del material", .minimumCount(1), .maximumCount(3))
    var conceptTags: [String]

    @Guide(description: "Título exacto del recurso de origen de la lista RECURSOS")
    var sourceResourceTitle: String
}

// MARK: - Evaluación de respuesta

/// Veredicto rápido: solo determina si la respuesta es correcta/incorrecta.
/// No incluye feedback para mantener la latencia baja.
@Generable(description: "Veredicto de la respuesta del estudiante")
struct GeneratedAnswerVerdict {
    @Guide(description: "true si demuestra comprensión del tema. false si es irrelevante, evasiva o errónea.")
    var isCorrect: Bool

    @Guide(description: "'incompleto' solo si isCorrect=true pero faltan ideas. 'conceptual'/'confusion' si isCorrect=false. Vacío si correcta.")
    var errorTypeToken: String

    @Guide(description: "Conceptos que faltan (solo si incompleto)", .maximumCount(4))
    var missingConcepts: [String]

    @Guide(description: "Conceptos erróneos (solo si isCorrect=false)", .maximumCount(4))
    var incorrectConcepts: [String]

    @Guide(description: "Confianza 0-1", .minimum(0), .maximum(1))
    var confidenceScore: Double
}

/// Feedback explicativo generado de forma lazy (solo cuando el usuario lo pide).
@Generable(description: "Feedback didáctico sobre la respuesta del estudiante")
struct GeneratedAnswerFeedback {
    @Guide(description: "Feedback breve y didáctico en español: explica por qué la respuesta es correcta o incorrecta y qué debería mejorar.")
    var feedback: String
}

// MARK: - Anki Cards

@Generable(description: "Lote de tarjetas Anki estilo memoria (frente/dorso) basadas en el material de estudio")
struct GeneratedAnkiPack {
    @Guide(description: "Lista de tarjetas Anki generadas", .minimumCount(8), .maximumCount(32))
    var cards: [GeneratedAnkiItem]
}

@Generable(description: "Lote pequeño de tarjetas Anki de un fragmento de material")
struct GeneratedAnkiChunk {
    @Guide(description: "Tarjetas Anki de este fragmento", .minimumCount(3), .maximumCount(10))
    var cards: [GeneratedAnkiItem]
}

@Generable
struct GeneratedAnkiItem {
    @Guide(description: "Frente: máximo 12 palabras, atómico (un concepto). Varía formato: definición, mecanismo, causa-efecto, cloze.")
    var front: String

    @Guide(description: "Dorso: respuesta directa en 1-2 frases (15-35 palabras). No repitas la pregunta.")
    var back: String

    @Guide(description: "1-3 etiquetas del tema", .minimumCount(1), .maximumCount(3))
    var tags: [String]

    @Guide(description: "Título exacto del recurso de origen de la lista RECURSOS")
    var sourceResourceTitle: String
}

// MARK: - Ampliar explicación

@Generable(description: "Explicación ampliada para el estudiante")
struct ConceptDeepExplanation {
    @Guide(description: "Explicación más profunda en español, sin inventar fuera del contexto dado")
    var text: String
}

// MARK: - Recursos de refuerzo por lagunas

@Generable(description: "Apuntes de estudio para corregir lagunas de conocimiento")
struct GeneratedGapResourcePack {
    @Guide(description: "Entre 1 y 5 recursos: prioriza uno por laguna distinta cuando haya varias", .minimumCount(1), .maximumCount(5))
    var resources: [GeneratedGapResourceItem]
}

@Generable
struct GeneratedGapResourceItem {
    @Guide(description: "Título breve (máx 70 chars)")
    var title: String

    @Guide(description: "Markdown: explica el concepto, por qué se falla y un ejemplo del material. 200-900 palabras.")
    var content: String

    @Guide(description: "Laguna que cubre (de la lista LAGUNAS)")
    var gapConcept: String
}
