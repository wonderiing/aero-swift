import SwiftUI
import Combine

@MainActor
final class StudyDetailViewModel: ObservableObject {
    let study: Study
    @Published var resources: [Resource] = []
    @Published var flashcards: [Flashcard] = []
    @Published var reviewQueue: [Flashcard] = []
    @Published var gaps: GapsResponse?
    @Published var attemptsSummary: StudyAttemptsResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var showingAddResource = false
    @Published var showingGenerateFlashcards = false
    @Published var resourceTitle = ""
    @Published var resourceContent = ""
    @Published var resourceSourceName: String?
    
    private let resourceService = ResourceService.shared
    private let flashcardService = FlashcardService.shared
    private let attemptService = AttemptService.shared
    
    init(study: Study) {
        self.study = study
    }
    
    func fetchContent() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let resourcesRes = try resourceService.list(studyId: study.id)
            async let flashcardsRes = try flashcardService.list(studyId: study.id)
            async let reviewQueueRes = try flashcardService.getReviewQueue(studyId: study.id)
            async let gapsRes = try attemptService.getGaps(studyId: study.id)
            async let attemptsRes = try attemptService.listForStudy(studyId: study.id)
            
            self.resources = try await resourcesRes
            self.flashcards = try await flashcardsRes
            self.reviewQueue = try await reviewQueueRes
            self.gaps = try await gapsRes
            self.attemptsSummary = try await attemptsRes
            
        } catch {
            errorMessage = "Error al cargar el estudio: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func createResource() async {
        guard !resourceTitle.isEmpty && !resourceContent.isEmpty else { return }
        
        isLoading = true
        
        do {
            let dto = CreateResourceDto(title: resourceTitle, content: resourceContent, sourceName: resourceSourceName)
            _ = try await resourceService.create(studyId: study.id, dto: dto)
            await fetchContent()
            showingAddResource = false
            resourceTitle = ""
            resourceContent = ""
            resourceSourceName = nil
        } catch {
            errorMessage = "Error al agregar recurso: \(error.localizedDescription)"
        }
        
        isLoading = false
    }

    func updateResource(id: UUID, title: String, content: String) async throws {
        let dto = UpdateResourceDto(title: title, content: content)
        _ = try await resourceService.update(id: id, dto: dto)
        await fetchContent()
    }

    func saveFlashcardBatch(_ dtos: [CreateFlashcardDto]) async throws {
        _ = try await flashcardService.createBatch(studyId: study.id, dtos: dtos)
        await fetchContent()
    }

    #if DEBUG
    /// Datos de ejemplo para `#Preview`.
    @MainActor
    static func previewMock(
        resources: [Resource] = [
            Resource(
                id: UUID(),
                title: "Fotosíntesis",
                content: "La fotosíntesis es el proceso por el cual las plantas convierten luz en energía química en los cloroplastos. Libera oxígeno.",
                sourceName: nil,
                createdAt: Date()
            )
        ]
    ) -> StudyDetailViewModel {
        let study = Study(id: UUID(), title: "Biología (preview)", description: "Vista previa de Xcode", createdAt: Date())
        let vm = StudyDetailViewModel(study: study)
        vm.resources = resources
        return vm
    }

    @MainActor
    static func previewWithProgress() -> StudyDetailViewModel {
        let vm = previewMock()
        vm.gaps = GapsResponse(
            study_id: vm.study.id,
            total_attempts: 12,
            gaps: [
                ConceptGap(
                    concept: "fase oscura",
                    error_rate: 0.55,
                    total_attempts: 6,
                    errors: 3,
                    dominant_error_type: .conceptual,
                    trend: "estable",
                    last_seen: Date()
                )
            ],
            strong_concepts: [
                StrongConcept(concept: "cloroplasto", error_rate: 0.12, total_attempts: 10)
            ]
        )
        vm.attemptsSummary = StudyAttemptsResponse(total: 12, correct: 8, accuracy: 2.0 / 3.0, attempts: [])
        vm.flashcards = [
            Flashcard(
                id: UUID(),
                question: "¿Dónde ocurre?",
                answer: "En el estroma.",
                type: .open,
                options: nil,
                conceptTags: ["estroma"],
                nextReviewAt: nil,
                easeFactor: 2.5,
                intervalDays: 1,
                createdAt: Date()
            )
        ]
        return vm
    }
    #endif
}
