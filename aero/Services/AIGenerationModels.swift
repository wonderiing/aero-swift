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
    @Guide(description: """
    Pregunta pedagógica en español. Reglas ESTRICTAS:
    1. Cada pregunta debe testear comprensión profunda, NO memorización de definiciones. Prohibido el patrón '¿Qué es X?' salvo una vez por lote.
    2. VARÍA el estilo en cada tarjeta: comparación (¿En qué se diferencia X de Y?), causa-efecto (¿Por qué ocurre X? / ¿Qué consecuencia tiene…?), aplicación (¿Cómo aplicarías X en el contexto Y?), proceso (¿Cuáles son los pasos de…?), error común (¿Por qué es incorrecto pensar que…?), relación (¿Cómo influye X en Y?), predicción (¿Qué pasaría si se elimina X?).
    3. La pregunta debe poder responderse SOLO con el material proporcionado.
    4. Redacción clara, directa y sin ambigüedad.
    """)
    var question: String

    @Guide(description: "Respuesta modelo completa: explica el concepto con suficiente detalle para que un estudiante entienda por qué es correcto. Máximo 3 frases. Incluye el 'por qué' o el 'mecanismo', no solo el dato.")
    var answer: String

    /// Tipo de tarjeta (constrained por el enum — el modelo no puede generar otro valor).
    @Guide(description: "Tipo de tarjeta. DEBES variar: aproximadamente 60% deben ser 'open' (pregunta abierta, requiere elaborar la respuesta) y 40% 'multiple_choice' (concepto concreto con opciones). Nunca generes solo un tipo; alterna de forma explícita.")
    var cardKind: GeneratedCardKind

    @Guide(description: "Solo para multiple_choice: la respuesta correcta, formulada como frase completa y concisa. Para open: string vacío.")
    var mcCorrect: String

    @Guide(description: "Solo para multiple_choice: exactamente 3 distractores plausibles del mismo dominio. Cada distractor debe ser incorrecto pero creíble (errores típicos de estudiantes, confusiones frecuentes). Para open: lista vacía.", .maximumCount(3))
    var mcDistractors: [String]

    @Guide(description: "1 a 3 términos técnicos clave del material que cubre esta tarjeta", .minimumCount(1), .maximumCount(3))
    var conceptTags: [String]

    @Guide(description: "Copia exacta del título del recurso de origen tal como aparece en la lista RECURSOS")
    var sourceResourceTitle: String
}

// MARK: - Evaluación de respuesta

@Generable(description: "Evaluación de la respuesta del estudiante")
struct GeneratedAnswerEvaluation {
    @Guide(description: "true si el estudiante demuestra comprensión del concepto central, aunque la respuesta sea breve, informal o incompleta. false SOLO si la respuesta contiene un error conceptual activo o es completamente irrelevante.")
    var isCorrect: Bool

    @Guide(description: "Usa 'incompleto' cuando isCorrect=true pero faltan ideas clave. Usa 'conceptual', 'memoria' o 'confusion' cuando isCorrect=false. Deja vacío si la respuesta es totalmente correcta.")
    var errorTypeToken: String

    @Guide(description: "Solo cuando errorTypeToken='incompleto': lista de conceptos o ideas que el estudiante no mencionó pero eran relevantes.", .maximumCount(4))
    var missingConcepts: [String]

    @Guide(description: "Solo cuando isCorrect=false: lista de afirmaciones incorrectas o conceptos confundidos en la respuesta.", .maximumCount(4))
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
