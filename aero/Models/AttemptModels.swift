import Foundation

enum ErrorType: String, Codable, Sendable {
    case conceptual
    case memoria
    case confusion
    case incompleto
}

struct AttemptFlashcard: Codable, Sendable {
    let id: UUID
    let question: String
    let conceptTags: [String]
}

struct Attempt: Codable, Identifiable, Sendable {
    let id: UUID
    let userAnswer: String?
    let isCorrect: Bool
    let errorType: ErrorType?
    let missingConcepts: [String]?
    let incorrectConcepts: [String]?
    let feedback: String?
    let confidenceScore: Double?
    let answeredAt: Date?
    let flashcard: AttemptFlashcard?
}

struct CreateAttemptDto: Codable, Sendable {
    let userAnswer: String?
    let isCorrect: Bool
    let errorType: ErrorType?
    let missingConcepts: [String]?
    let incorrectConcepts: [String]?
    let feedback: String?
    let confidenceScore: Double?
}

struct StudyAttemptsResponse: Codable, Sendable {
    let total: Int
    let correct: Int
    let accuracy: Double
    let attempts: [Attempt]
}
