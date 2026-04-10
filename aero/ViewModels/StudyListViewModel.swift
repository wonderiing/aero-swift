import SwiftUI
import Combine

struct StudyRowModel: Identifiable, Sendable {
    let study: Study
    var pendingReviewCount: Int = 0
    var accuracy: Double?
    var lastPractice: Date?

    var id: UUID { study.id }
}

@MainActor
final class StudyListViewModel: ObservableObject {
    @Published var rows: [StudyRowModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingCreateStudy = false

    @Published var newStudyTitle = ""
    @Published var newStudyDescription = ""

    private let studyService = StudyService.shared
    private let flashcardService = FlashcardService.shared
    private let attemptService = AttemptService.shared

    func fetchStudies() async {
        isLoading = true
        errorMessage = nil

        do {
            let studies = try await studyService.listAll()
            rows = studies.map { StudyRowModel(study: $0) }
        } catch {
            errorMessage = "Error al cargar estudios: \(error.localizedDescription)"
        }

        isLoading = false
        await enrichRows()
    }

    private func enrichRows() async {
        let fc = flashcardService
        let att = attemptService
        let snapshot = rows
        var map: [UUID: (Int, Double?, Date?)] = [:]
        await withTaskGroup(of: (UUID, Int, Double?, Date?).self) { group in
            for row in snapshot {
                let studyId = row.study.id
                group.addTask {
                    async let queueCount = (try? await fc.getReviewQueue(studyId: studyId))?.count ?? 0
                    async let attempts = try? await att.listForStudy(studyId: studyId)
                    let q = await queueCount
                    let a = await attempts
                    let last = a?.attempts.compactMap(\.answeredAt).max()
                    return (studyId, q, a?.accuracy, last)
                }
            }
            for await item in group {
                map[item.0] = (item.1, item.2, item.3)
            }
        }
        for i in rows.indices {
            let id = rows[i].study.id
            if let e = map[id] {
                rows[i].pendingReviewCount = e.0
                rows[i].accuracy = e.1
                rows[i].lastPractice = e.2
            }
        }
    }

    @discardableResult
    func createStudy() async -> Bool {
        guard !newStudyTitle.isEmpty && !newStudyDescription.isEmpty else { return false }

        isLoading = true
        errorMessage = nil

        do {
            let dto = CreateStudyDto(title: newStudyTitle, description: newStudyDescription)
            _ = try await studyService.create(dto: dto)
            await fetchStudies()
            newStudyTitle = ""
            newStudyDescription = ""
            isLoading = false
            return true
        } catch {
            errorMessage = "Error al crear estudio: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    func deleteStudy(id: UUID) async {
        do {
            try await studyService.delete(id: id)
            await fetchStudies()
        } catch {
            errorMessage = "Error al eliminar estudio: \(error.localizedDescription)"
        }
    }
}
