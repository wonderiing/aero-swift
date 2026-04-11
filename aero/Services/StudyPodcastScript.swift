import Foundation

/// Construye un guion continuo a partir de los recursos del estudio (texto plano, sin Markdown).
enum StudyPodcastScript {
    /// Límite aproximado para evitar síntesis excesiva (caracteres).
    static let maxCharacters = 55_000

    static func build(studyTitle: String, resources: [SDResource]) -> String {
        let sorted = resources.sorted { $0.createdAt < $1.createdAt }
        var parts: [String] = []

        parts.append(
            "Bienvenidos al repaso en audio del tema \(studyTitle), en Aero. "
                + "A continuación escucharás un resumen por secciones, según tus materiales."
        )

        for (index, r) in sorted.enumerated() {
            let plain = AeroMarkdown.plainText(from: r.content)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !plain.isEmpty else { continue }
            parts.append("Sección \(index + 1): \(r.title).")
            parts.append(plain)
        }

        parts.append("Has llegado al final del repaso de \(studyTitle). ¡Hasta la próxima!")

        var full = parts.joined(separator: "\n\n")
        if full.count > maxCharacters {
            let endNote = "\n\n… Contenido limitado por longitud. Añade menos texto por recurso o divide el tema en varios estudios para escucharlo completo."
            let take = maxCharacters - endNote.count
            if take > 0 {
                full = String(full.prefix(take)) + endNote
            }
        }

        return full
    }

    static func estimatedMinutes(forScript script: String) -> Int {
        let words = max(1, script.split { $0.isWhitespace || $0.isNewline }.count)
        let minutes = Double(words) / 140.0
        return max(1, Int(ceil(minutes)))
    }
}
