import Foundation

struct ConceptGap: Sendable, Identifiable {
    /// Clave estable (etiqueta en minúsculas o id de tarjeta); puede diferir del texto mostrado.
    let id: String
    let concept: String
    let error_rate: Double
    let total_attempts: Int
    let errors: Int
    let dominant_error_type: ErrorType?
    let trend: String
    let last_seen: Date?
}

struct StrongConcept: Sendable, Identifiable {
    var id: String { concept }
    let concept: String
    let error_rate: Double
    let total_attempts: Int
}
