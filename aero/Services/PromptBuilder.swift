import Foundation

/// Construye instrucciones para Foundation Models según `accessibilityNeeds` (CSV).
enum PromptBuilder {
    enum Role: Sendable {
        case flashcardGeneration
        case ankiGeneration
        case gapGeneration
        case evaluation
        case expandExplanation
    }

    /// Un solo bloque de texto (p. ej. depuración); la app usa principalmente `instructionFragments`.
    static func buildSystemPrompt(needsCSV: String, role: Role) -> String {
        instructionFragments(for: AccessibilityNeeds(needsCSV), role: role).joined(separator: "\n")
    }

    static func instructionFragments(for needs: AccessibilityNeeds, role: Role) -> [String] {
        switch role {
        case .flashcardGeneration:
            return generationFlashcardFragments(needs)
        case .ankiGeneration:
            return generationAnkiFragments(needs)
        case .gapGeneration:
            return generationGapFragments(needs)
        case .evaluation:
            return evaluationFragments(needs)
        case .expandExplanation:
            return expandExplanationFragments(needs)
        }
    }

    // MARK: - Generación

    private static func generationFlashcardFragments(_ needs: AccessibilityNeeds) -> [String] {
        var lines: [String] = []
        if needs.hasADHD {
            lines.append(contentsOf: [
                "PERFIL TDAH — generación de preguntas:",
                "- Preguntas breves y directas; una sola idea por pregunta.",
                "- Evita párrafos largos en el enunciado."
            ])
        }
        if needs.hasAutism {
            lines.append(contentsOf: [
                "PERFIL TEA — generación de preguntas:",
                "- Lenguaje literal y concreto en los enunciados.",
                "- Sin humor, ironía, metáforas ni expresiones ambiguas."
            ])
        }
        if needs.hasDyslexia {
            lines.append(contentsOf: [
                "PERFIL DISLEXIA — generación de preguntas:",
                "- Cada pregunta debe tener como máximo 15 palabras.",
                "- Una sola idea por pregunta.",
                "- Sin oraciones subordinadas ni cláusulas compuestas.",
                "- Vocabulario directo y cotidiano."
            ])
        }
        return lines
    }

    private static func generationAnkiFragments(_ needs: AccessibilityNeeds) -> [String] {
        var lines = generationFlashcardFragments(needs)
        if needs.hasDyslexia {
            lines.append("PERFIL DISLEXIA — Anki: el frente de cada tarjeta debe ser extra corto (ideal ≤10 palabras) y sin rodeos.")
        }
        return lines
    }

    private static func generationGapFragments(_ needs: AccessibilityNeeds) -> [String] {
        generationFlashcardFragments(needs)
    }

    // MARK: - Evaluación

    private static func evaluationFragments(_ needs: AccessibilityNeeds) -> [String] {
        var lines: [String] = []
        if needs.hasADHD {
            lines.append(contentsOf: [
                "El usuario tiene TDAH. Reglas estrictas para el feedback:",
                "- Máximo 2 oraciones en el feedback.",
                "- Si hay varios errores, reporta solo el más importante.",
                "- Comienza siempre reconociendo algo que el estudiante hizo bien antes de señalar errores.",
                "- Lenguaje energético y directo; nunca neutro o plano.",
                "- Nunca uses listas de varios puntos ni viñetas en el feedback."
            ])
        }
        if needs.hasAutism {
            lines.append(contentsOf: [
                "El usuario está en el espectro autista. Reglas estrictas:",
                "- Lenguaje completamente literal y concreto.",
                "- Nunca uses metáforas, sarcasmo, ironía o expresiones idiomáticas.",
                "- El feedback debe seguir exactamente este formato (mismas etiquetas y orden):",
                "  Estado: Correcto / Incorrecto / Parcial",
                "  Mencionaste: [conceptos correctos o vacío]",
                "  Faltó: [conceptos omitidos o vacío]",
                "  Incorrecto: [conceptos erróneos o vacío]",
                "  Próxima vez recuerda: [una sola oración concreta]",
                "- Primero el resultado (Estado), luego el detalle.",
                "- No te desvíes de este formato aunque el contenido cambie."
            ])
        }
        if needs.hasDyslexia {
            lines.append(contentsOf: [
                "El usuario tiene dislexia. Reglas estrictas:",
                "- El feedback debe tener como máximo 2 oraciones cortas.",
                "- Vocabulario simple y directo.",
                "- Nunca uses oraciones compuestas ni subordinadas.",
                "- Una sola idea por oración."
            ])
        }
        return lines
    }

    // MARK: - Ampliar explicación

    private static func expandExplanationFragments(_ needs: AccessibilityNeeds) -> [String] {
        var lines: [String] = []
        if needs.hasADHD {
            lines.append("PERFIL TDAH: la explicación ampliada debe ser breve (como mucho un párrafo corto) y ir al grano.")
        }
        if needs.hasAutism {
            lines.append("PERFIL TEA: usa solo lenguaje literal; define términos; evita analogías abstractas salvo que sean indispensables y sean explícitas.")
        }
        if needs.hasDyslexia {
            lines.append("PERFIL DISLEXIA: frases muy cortas; vocabulario simple; evita subordinadas; un solo concepto por frase.")
        }
        return lines
    }
}
