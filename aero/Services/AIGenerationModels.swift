import Foundation
import FoundationModels

// MARK: - Flashcards (generación desde recursos)

@Generable(description: "Lote de flashcards basadas únicamente en el material de estudio proporcionado")
struct GeneratedFlashcardPack {
    @Guide(
        description: "Mezcla ~50% preguntas abiertas y ~50% opción múltiple; máximo 3 etiquetas por tarjeta",
        .maximumCount(28),
        .minimumCount(2)
    )
    var cards: [GeneratedFlashcardItem]
}

@Generable
struct GeneratedFlashcardItem {
    @Guide(description: "Pregunta clara en español, tipo examen")
    var question: String
    @Guide(description: "Respuesta correcta completa, fiel al material")
    var answer: String
    @Guide(description: "Solo los valores: open o multiple_choice")
    var cardKind: String
    @Guide(description: "Si cardKind es multiple_choice, texto de la opción correcta; si no, vacío")
    var mcCorrect: String?
    @Guide(description: "Exactamente tres distractores plausibles para multiple_choice; vacío si es open", .maximumCount(3))
    var mcDistractors: [String]
    @Guide(description: "Conceptos clave, 1 a 3", .maximumCount(3), .minimumCount(1))
    var conceptTags: [String]
    @Guide(description: "Debe coincidir exactamente con uno de los títulos de recurso listados en el prompt")
    var sourceResourceTitle: String
}

// MARK: - Evaluación de respuesta (práctica)

@Generable(description: "Evaluación de la respuesta del estudiante frente a la flashcard")
struct GeneratedAnswerEvaluation {
    var isCorrect: Bool
    @Guide(description: "Si isCorrect es true, cadena vacía. Si no: conceptual, memoria, confusion o incompleto")
    var errorTypeToken: String
    @Guide(description: "Conceptos importantes que faltaron", .maximumCount(6))
    var missingConcepts: [String]
    @Guide(description: "Conceptos incorrectos o confundidos", .maximumCount(6))
    var incorrectConcepts: [String]
    @Guide(description: "Retroalimentación breve y didáctica en español")
    var feedback: String
    @Guide(description: "Confianza en la evaluación", .minimum(0), .maximum(1))
    var confidenceScore: Double
}

// MARK: - Ampliar explicación ("Explicar más")

@Generable(description: "Explicación ampliada para el estudiante")
struct ConceptDeepExplanation {
    @Guide(description: "Explicación más profunda en español, sin inventar fuera del contexto dado")
    var text: String
}
