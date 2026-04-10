import Foundation

struct Resource: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let title: String
    let content: String
    let sourceName: String?
    let createdAt: Date?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Resource, rhs: Resource) -> Bool {
        lhs.id == rhs.id
    }
}

struct CreateResourceDto: Codable, Sendable {
    let title: String
    let content: String
    let sourceName: String?
}

struct UpdateResourceDto: Codable, Sendable {
    let title: String?
    let content: String?
}
