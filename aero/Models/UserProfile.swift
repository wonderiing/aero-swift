import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var sessionStyle: [String]
    var accessibilityNeeds: [String]
    var createdAt: Date
    var updatedAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.sessionStyle = []
        self.accessibilityNeeds = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

