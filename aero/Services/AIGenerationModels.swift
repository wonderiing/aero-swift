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
    @Guide(description: "Lista de flashcards generadas", .minimumCount(2), .maximumCount(28))
    var cards: [GeneratedFlashcardItem]
}

/// Lote pequeño para generación chunked (material largo dividido en partes).
@Generable(description: "Lote pequeño de flashcards de un fragmento de material")
struct GeneratedFlashcardChunk {
    @Guide(description: "Flashcards generadas de este fragmento", .minimumCount(1), .maximumCount(6))
    var cards: [GeneratedFlashcardItem]
}

@Generable
struct GeneratedFlashcardItem {
    @Guide(description: "Pregunta variada en español. VARÍA el estilo entre: comparación (¿En qué se diferencia X de Y?), causa-efecto (¿Por qué ocurre X?), aplicación (¿Qué pasaría si…?), proceso (¿Cuáles son los pasos de…?), función (¿Para qué sirve…?), relación (¿Cómo se relaciona X con Y?), clasificación (¿A qué categoría pertenece…?). EVITA repetir '¿Qué es X?' más de una vez en el lote.")
    var question: String

    @Guide(description: "Respuesta correcta y concisa, máximo 2 frases")
    var answer: String

    /// Tipo de tarjeta (constrained por el enum — el modelo no puede generar otro valor).
    var cardKind: GeneratedCardKind

    @Guide(description: "Solo para multiple_choice: respuesta correcta breve. Para open: string vacío.")
    var mcCorrect: String

    @Guide(description: "Solo para multiple_choice: exactamente 3 distractores plausibles del mismo dominio. Para open: lista vacía.", .maximumCount(3))
    var mcDistractors: [String]

    @Guide(description: "1 a 3 términos técnicos reales del material", .minimumCount(1), .maximumCount(3))
    var conceptTags: [String]

    @Guide(description: "Copia exacta del título del recurso de origen tal como aparece en la lista RECURSOS")
    var sourceResourceTitle: String
}

// MARK: - Evaluación de respuesta

@Generable(description: "Evaluación de la respuesta del estudiante")
struct GeneratedAnswerEvaluation {
    var isCorrect: Bool

    @Guide(description: "Si isCorrect es true: string vacío. Si no: uno de — conceptual, memoria, confusion, incompleto")
    var errorTypeToken: String

    @Guide(description: "Conceptos importantes que faltaron en la respuesta", .maximumCount(6))
    var missingConcepts: [String]

    @Guide(description: "Conceptos incorrectos o confundidos", .maximumCount(6))
    var incorrectConcepts: [String]

    @Guide(description: "Retroalimentación breve y didáctica en español")
    var feedback: String

    @Guide(description: "Confianza en la evaluación entre 0 y 1", .minimum(0), .maximum(1))
    var confidenceScore: Double
}

// MARK: - Ampliar explicación

@Generable(description: "Explicación ampliada para el estudiante")
struct ConceptDeepExplanation {
    @Guide(description: "Explicación más profunda en español, sin inventar fuera del contexto dado")
    var text: String
}
