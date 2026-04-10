import Foundation

enum ErrorType: String, Codable, Sendable {
    case conceptual
    case memoria
    case confusion
    case incompleto
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
