import Foundation

class StudyService {
    static let shared = StudyService()
    private let client = APIClient.shared
    
    func list(limit: Int = 10, offset: Int = 0) async throws -> [Study] {
        try await client.request(endpoint: "/studies?limit=\(limit)&offset=\(offset)")
    }

    /// Recupera todos los estudios sin depender de query params opcionales.
    func listAll(pageSize: Int = 50) async throws -> [Study] {
        _ = pageSize // reservado para compatibilidad futura si el backend reintroduce paginacion.
        return try await client.request(endpoint: "/studies")
    }
    
    func create(dto: CreateStudyDto) async throws -> Study {
        try await client.request(endpoint: "/studies", method: "POST", body: dto)
    }
    
    func get(id: UUID) async throws -> Study {
        try await client.request(endpoint: "/studies/\(id)")
    }
    
    func delete(id: UUID) async throws {
        try await client.requestEmpty(endpoint: "/studies/\(id)")
    }
}
