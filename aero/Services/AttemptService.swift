import Foundation

class AttemptService {
    static let shared = AttemptService()
    private let client = APIClient.shared
    
    func create(flashcardId: UUID, dto: CreateAttemptDto) async throws -> Attempt {
        try await client.request(endpoint: "/flashcards/\(flashcardId)/attempts", method: "POST", body: dto)
    }
    
    func listForStudy(studyId: UUID) async throws -> StudyAttemptsResponse {
        try await client.request(endpoint: "/studies/\(studyId)/attempts")
    }
    
    func getGaps(studyId: UUID) async throws -> GapsResponse {
        try await client.request(endpoint: "/studies/\(studyId)/gaps")
    }
}
