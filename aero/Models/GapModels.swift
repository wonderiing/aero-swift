import Foundation

struct ConceptGap: Codable, Sendable, Identifiable {
    var id: String { concept }
    let concept: String
    let error_rate: Double
    let total_attempts: Int
    let errors: Int
    let dominant_error_type: ErrorType?
    let trend: String
    let last_seen: Date?
}

struct StrongConcept: Codable, Sendable, Identifiable {
    var id: String { concept }
    let concept: String
    let error_rate: Double
    let total_attempts: Int
}

struct GapsResponse: Codable, Sendable {
    let study_id: UUID
    let total_attempts: Int
    let gaps: [ConceptGap]
    let strong_concepts: [StrongConcept]
}
