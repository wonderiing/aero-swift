import SwiftUI
import SwiftData
import Combine

@MainActor
final class StudyDetailViewModel: ObservableObject {
    let study: SDStudy
    @Published var resources: [SDResource] = []
    @Published var flashcards: [SDFlashcard] = []
    @Published var reviewQueue: [SDFlashcard] = []
    @Published var ankiCards: [SDAnkiCard] = []
    @Published var ankiReviewQueue: [SDAnkiCard] = []
    @Published var gapAnalysis: GapAnalysis?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var showingAddResource = false
    @Published var showingGenerateFlashcards = false
    @Published var showingCreateFlashcardManual = false
    @Published var showingGenerateFromGaps = false
    @Published var showingGenerateAnkiCards = false
    @Published var resourceTitle = ""
    @Published var resourceContent = ""
    @Published var resourceSourceName: String?

    var modelContext: ModelContext?

    init(study: SDStudy) {
        self.study = study
    }

    func fetchContent() {
        resources = study.resources.sorted { ($0.createdAt) > ($1.createdAt) }
        flashcards = study.flashcards.sorted { ($0.createdAt) > ($1.createdAt) }
        reviewQueue = study.flashcards.filter { $0.nextReviewAt <= Date() }
            .sorted { $0.nextReviewAt < $1.nextReviewAt }
        ankiCards = study.ankiCards.sorted { ($0.createdAt) > ($1.createdAt) }
        ankiReviewQueue = study.ankiCards.filter { $0.nextReviewAt <= Date() }
            .sorted { $0.nextReviewAt < $1.nextReviewAt }
        gapAnalysis = GapAnalysis.compute(flashcards: study.flashcards, ankiCards: study.ankiCards)
    }

    func createResource() {
        guard let ctx = modelContext,
              !resourceTitle.isEmpty && !resourceContent.isEmpty else { return }

        isLoading = true
        let resource = SDResource(title: resourceTitle, content: resourceContent, sourceName: resourceSourceName, study: study)
        ctx.insert(resource)

        do {
            try ctx.save()
            showingAddResource = false
            resourceTitle = ""
            resourceContent = ""
            resourceSourceName = nil
            fetchContent()
        } catch {
            errorMessage = "Error al agregar recurso: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func updateResource(id: UUID, title: String, content: String) {
        guard let ctx = modelContext else { return }
        if let resource = study.resources.first(where: { $0.id == id }) {
            resource.title = title
            resource.content = content
            do {
                try ctx.save()
                fetchContent()
            } catch {
                errorMessage = "Error al actualizar recurso: \(error.localizedDescription)"
            }
        }
    }

    func createFlashcardManually(
        question: String,
        answer: String,
        tags: [String],
        resourceId: UUID,
        type: FlashcardType,
        options: FlashcardOptions?
    ) -> Bool {
        guard let ctx = modelContext else { return false }
        let resource = study.resources.first { $0.id == resourceId }

        let card = SDFlashcard(
            question: question,
            answer: answer,
            type: type,
            options: options,
            conceptTags: tags,
            study: study,
            resource: resource
        )
        ctx.insert(card)

        do {
            try ctx.save()
            fetchContent()
            return true
        } catch {
            errorMessage = "Error al crear flashcard: \(error.localizedDescription)"
            return false
        }
    }

    func deleteFlashcard(id: UUID) {
        guard let ctx = modelContext,
              let card = study.flashcards.first(where: { $0.id == id }) else { return }
        ctx.delete(card)
        do {
            try ctx.save()
            fetchContent()
        } catch {
            errorMessage = "Error al eliminar flashcard: \(error.localizedDescription)"
        }
    }

    func saveFlashcardBatch(_ dtos: [CreateFlashcardDto]) {
        guard let ctx = modelContext else { return }

        let resourceMap = Dictionary(uniqueKeysWithValues: study.resources.map { ($0.id, $0) })

        for dto in dtos {
            let card = SDFlashcard(
                question: dto.question,
                answer: dto.answer,
                type: dto.type ?? .open,
                options: dto.options,
                conceptTags: dto.conceptTags,
                study: study,
                resource: resourceMap[dto.resourceId]
            )
            ctx.insert(card)
        }

        do {
            try ctx.save()
            fetchContent()
        } catch {
            errorMessage = "Error al guardar flashcards: \(error.localizedDescription)"
        }
    }

    // MARK: - Anki Cards

    func saveAnkiCardBatch(_ cards: [EditableAnkiCard]) {
        guard let ctx = modelContext else { return }
        let resourceMap = Dictionary(uniqueKeysWithValues: study.resources.map { ($0.id, $0) })
        for card in cards {
            let anki = SDAnkiCard(
                front: card.front,
                back: card.back,
                tags: card.tags,
                study: study,
                resource: resourceMap[card.resourceId]
            )
            ctx.insert(anki)
        }
        do {
            try ctx.save()
            fetchContent()
        } catch {
            errorMessage = "Error al guardar flashcards: \(error.localizedDescription)"
        }
    }

    func deleteAnkiCard(id: UUID) {
        guard let ctx = modelContext,
              let card = study.ankiCards.first(where: { $0.id == id }) else { return }
        ctx.delete(card)
        do {
            try ctx.save()
            fetchContent()
        } catch {
            errorMessage = "Error al eliminar flashcard: \(error.localizedDescription)"
        }
    }

    func updateAnkiSM2(card: SDAnkiCard, quality: Int) {
        guard let ctx = modelContext else { return }
        card.updateSM2(quality: quality)
        do {
            try ctx.save()
            fetchContent()
        } catch {
            errorMessage = "Error al actualizar repaso: \(error.localizedDescription)"
        }
    }

    // MARK: - Attempts (used by practice session)

    func recordAttempt(flashcard: SDFlashcard, dto: CreateAttemptDto) -> SDAttempt? {
        guard let ctx = modelContext else { return nil }

        let attempt = SDAttempt(dto: dto, flashcard: flashcard)
        ctx.insert(attempt)

        // Update SM-2
        let quality = flashcard.sm2Quality(isCorrect: dto.isCorrect, confidence: dto.confidenceScore ?? 0)
        flashcard.updateSM2(quality: quality)

        do {
            try ctx.save()
            return attempt
        } catch {
            errorMessage = "Error al guardar intento: \(error.localizedDescription)"
            return nil
        }
    }

    #if DEBUG
    @MainActor
    static func previewMock(
        resources: [SDResource]? = nil
    ) -> StudyDetailViewModel {
        let study = SDStudy(title: "Biología (preview)", desc: "Vista previa de Xcode")
        let vm = StudyDetailViewModel(study: study)
        return vm
    }

    @MainActor
    static func previewWithProgress() -> StudyDetailViewModel {
        let vm = previewMock()
        return vm
    }
    #endif
}
