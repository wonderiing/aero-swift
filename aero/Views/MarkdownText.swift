import SwiftUI

/// Interpreta Markdown del sistema (`AttributedString`) para mostrarlo en `Text`.
enum AeroMarkdown {
    fileprivate static let parseOptions = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .full,
        failurePolicy: .returnPartiallyParsedIfPossible
    )

    /// Texto sin marcas de Markdown (útil para vistas previas en listas).
    static func plainText(from markdown: String) -> String {
        guard let attributed = try? AttributedString(
            markdown: markdown,
            options: Self.parseOptions
        ) else {
            return stripMarkdownFallback(markdown)
        }
        return String(attributed.characters)
    }

    /// Cuando el parser falla del todo, quita al menos encabezados y énfasis comunes.
    private static func stripMarkdownFallback(_ s: String) -> String {
        var t = s
        t = t.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"__([^_]+)__"#, with: "$1", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct AeroMarkdownText: View {
    let markdown: String

    var body: some View {
        Group {
            if let attributed = try? AttributedString(
                markdown: markdown,
                options: AeroMarkdown.parseOptions
            ) {
                Text(attributed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(markdown)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
