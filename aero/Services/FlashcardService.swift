import Foundation

class FlashcardService {
    static let shared = FlashcardService()
    private let client = APIClient.shared
    
    func list(studyId: UUID, resourceId: UUID? = nil) async throws -> [Flashcard] {
        var endpoint = "/studies/\(studyId)/flashcards"
        if let resId = resourceId {
            endpoint += "?resource_id=\(resId)"
        }
        return try await client.request(endpoint: endpoint)
    }
    
    func getReviewQueue(studyId: UUID) async throws -> [Flashcard] {
        try await client.request(endpoint: "/studies/\(studyId)/flashcards/review-queue")
    }
    
    func create(studyId: UUID, dto: CreateFlashcardDto) async throws -> Flashcard {
        try await client.request(endpoint: "/studies/\(studyId)/flashcards", method: "POST", body: dto)
    }
    
    func createBatch(studyId: UUID, dtos: [CreateFlashcardDto]) async throws -> [Flashcard] {
        try await client.request(endpoint: "/studies/\(studyId)/flashcards/batch", method: "POST", body: dtos)
    }
}
