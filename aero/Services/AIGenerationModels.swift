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
    @Guide(description: """
    true solo si la respuesta muestra comprensión sustantiva del tema de la pregunta (aunque sea breve o informal).
    false si: (a) ignora el enunciado o es irrelevante/evasiva; (b) es texto aleatorio, broma o slang sin contenido (p. ej. "nvm", "random", "no sé" sin desarrollar); (c) error conceptual.
    NO marques true por ser "amable": una respuesta que no trata el tema es false, no "incompleto".
    """)
    var isCorrect: Bool

    @Guide(description: "Usa 'incompleto' SOLO cuando isCorrect=true y la respuesta SÍ aborda el tema pero faltan ideas clave. NUNCA uses 'incompleto' si isCorrect=false. Para evasivas o fuera de tema usa 'conceptual' o 'confusion'. Deja vacío si la respuesta es totalmente correcta.")
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
    @Guide(description: """
    Frente de la tarjeta (pregunta o término): máximo 12 palabras, inequívoco, atómico (un solo concepto).
    Varía el formato: definición inversa, mecanismo, causa-efecto, clasificación, comparación, o cloze implícito.
    El estudiante debe poder decir en segundos si sabe o no sabe la respuesta.
    """)
    var front: String

    @Guide(description: """
    Dorso de la tarjeta (respuesta): empieza con la respuesta directa en 1 frase (15-35 palabras).
    Si el concepto es abstracto, añade una segunda frase con un ejemplo concreto o analogía del material.
    NUNCA repitas la pregunta. NUNCA más de 2 frases.
    """)
    var back: String

    @Guide(description: "1 a 3 etiquetas conceptuales precisas que identifican el tema de esta tarjeta", .minimumCount(1), .maximumCount(3))
    var tags: [String]

    @Guide(description: "Copia exacta del título del recurso de origen tal como aparece en la lista RECURSOS")
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
    @Guide(description: "Título breve y descriptivo (máximo 70 caracteres)")
    var title: String

    @Guide(description: """
    Contenido en Markdown (## secciones, listas con guiones, **negritas**).
    Explica el concepto, por qué suele fallarse y un ejemplo breve tomado del material.
    Entre 200 y 900 palabras. No cites fuentes externas ni inventes datos fuera del material.
    """)
    var content: String

    @Guide(description: "Qué laguna cubre (palabras clave tomadas de la lista LAGUNAS)")
    var gapConcept: String
}
