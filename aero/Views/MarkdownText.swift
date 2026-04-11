import SwiftUI

/// Interpreta Markdown del sistema (`AttributedString`) para mostrarlo en `Text`.
/// SwiftUI no aplica sola el estilo visual de encabezados: se asignan fuentes según `PresentationIntent`.
enum AeroMarkdown {
    fileprivate static let parseOptions = AttributedString.MarkdownParsingOptions(
        allowsExtendedAttributes: true,
        interpretedSyntax: .full,
        failurePolicy: .returnPartiallyParsedIfPossible
    )

    /// Texto sin marcas de Markdown (útil para vistas previas en listas).
    static func plainText(from markdown: String) -> String {
        let normalized = normalizeMarkdown(markdown)
        guard let attributed = try? AttributedString(
            markdown: normalized,
            options: Self.parseOptions
        ) else {
            return stripMarkdownFallback(normalized)
        }
        return String(attributed.characters)
    }

    /// Atribuido listo para `Text`: parseo + estilos de bloque (p. ej. encabezados).
    static func attributedForDisplay(from markdown: String) -> AttributedString {
        let normalized = normalizeMarkdown(markdown)
        guard var output = try? AttributedString(
            markdown: normalized,
            options: parseOptions
        ) else {
            return AttributedString(stripMarkdownFallback(normalized))
        }
        applyHeadingFonts(to: &output)
        return output
    }

    /// Ajustes tolerantes a texto de IA/PDF: saltos de línea, `##Título` → `## Título`, cercas ``` desbalanceadas.
    private static func normalizeMarkdown(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if let regex = try? NSRegularExpression(pattern: "^(#{1,6})([^\\s#\\n])", options: .anchorsMatchLines) {
            let range = NSRange(t.startIndex..., in: t)
            t = regex.stringByReplacingMatches(in: t, options: [], range: range, withTemplate: "$1 $2")
        }
        t = closeUnbalancedCodeFences(t)
        return t
    }

    private static func closeUnbalancedCodeFences(_ s: String) -> String {
        let segments = s.components(separatedBy: "```")
        if segments.count % 2 == 0 { return s }
        return s + "\n```\n"
    }

    private static func applyHeadingFonts(to output: inout AttributedString) {
        for (intentBlock, intentRange) in output.runs[AttributeScopes.FoundationAttributes.PresentationIntentAttribute.self]
            .reversed()
        {
            guard let intentBlock else { continue }
            for intent in intentBlock.components {
                switch intent.kind {
                case .header(level: let level):
                    switch level {
                    case 1:
                        output[intentRange].font = .system(.title).bold()
                    case 2:
                        output[intentRange].font = .system(.title2).bold()
                    case 3:
                        output[intentRange].font = .system(.title3).bold()
                    case 4:
                        output[intentRange].font = .system(.headline).bold()
                    case 5:
                        output[intentRange].font = .system(.subheadline).bold()
                    default:
                        output[intentRange].font = .system(.caption).bold()
                    }
                    if intentRange.lowerBound != output.startIndex {
                        output.characters.insert(contentsOf: "\n", at: intentRange.lowerBound)
                    }
                default:
                    break
                }
            }
        }
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
        Text(AeroMarkdown.attributedForDisplay(from: markdown))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
