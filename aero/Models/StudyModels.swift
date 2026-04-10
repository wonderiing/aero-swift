import Foundation

struct Study: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let createdAt: Date?
}

struct CreateStudyDto: Codable, Sendable {
    let title: String
    let description: String
}
