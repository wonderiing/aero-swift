import Foundation

class ResourceService {
    static let shared = ResourceService()
    private let client = APIClient.shared
    
    func list(studyId: UUID) async throws -> [Resource] {
        try await client.request(endpoint: "/studies/\(studyId)/resources")
    }
    
    func create(studyId: UUID, dto: CreateResourceDto) async throws -> Resource {
        try await client.request(endpoint: "/studies/\(studyId)/resources", method: "POST", body: dto)
    }
    
    func get(id: UUID) async throws -> Resource {
        try await client.request(endpoint: "/resources/\(id)")
    }
    
    func update(id: UUID, dto: UpdateResourceDto) async throws -> Resource {
        try await client.request(endpoint: "/resources/\(id)", method: "PATCH", body: dto)
    }
}
