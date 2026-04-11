import Foundation

enum FlashcardType: String, Sendable {
    case open
    case multipleChoice
}

extension FlashcardType: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self).replacingOccurrences(of: "-", with: "_")
        switch raw {
        case "open": self = .open
        case "multiple_choice": self = .multipleChoice
        default:
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unknown flashcard type: \(raw)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .open: try c.encode("open")
        case .multipleChoice: try c.encode("multiple_choice")
        }
    }
}

struct FlashcardOptions: Codable, Sendable {
    let correct: String
    let distractors: [String]
}

struct CreateFlashcardDto: Codable, Sendable {
    var question: String
    var answer: String
    var conceptTags: [String]
    let resourceId: UUID
    var type: FlashcardType?
    var options: FlashcardOptions?
}

/// Editable wrapper for Anki cards before saving
struct EditableAnkiCard: Identifiable {
    let id = UUID()
    var resourceId: UUID
    var front: String
    var back: String
    var tags: [String]
    var isIncluded: Bool = true
}

/// Editable wrapper used during the review-before-save flow
struct EditableFlashcard: Identifiable {
    let id = UUID()
    var resourceId: UUID
    var question: String
    var answer: String
    var type: FlashcardType
    var options: FlashcardOptions?
    var conceptTags: [String]
    var isIncluded: Bool = true

    func toDto() -> CreateFlashcardDto {
        CreateFlashcardDto(
            question: question,
            answer: answer,
            conceptTags: conceptTags,
            resourceId: resourceId,
            type: type,
            options: options
        )
    }
}

/// Borrador de recurso generado por IA a partir de lagunas (revisión antes de guardar).
struct GeneratedGapResourceDraft: Identifiable {
    let id = UUID()
    var title: String
    var content: String
    /// Tema / laguna que cubre (metadato para la revisión).
    var gapConcept: String
    var isIncluded: Bool = true
}
