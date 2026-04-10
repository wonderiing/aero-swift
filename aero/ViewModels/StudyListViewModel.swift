import SwiftUI
import SwiftData
import Combine

struct StudyRowModel: Identifiable {
    let study: SDStudy
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

    var modelContext: ModelContext?

    func fetchStudies() {
        guard let ctx = modelContext else { return }
        isLoading = true
        errorMessage = nil

        do {
            let descriptor = FetchDescriptor<SDStudy>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            let studies = try ctx.fetch(descriptor)
            let now = Date()
            rows = studies.map { study in
                let pending = study.flashcards.filter { $0.nextReviewAt <= now }.count
                let allAttempts = study.flashcards.flatMap(\.attempts)
                let total = allAttempts.count
                let correct = allAttempts.filter(\.isCorrect).count
                let accuracy: Double? = total > 0 ? Double(correct) / Double(total) : nil
                let lastPractice = allAttempts.map(\.answeredAt).max()

                return StudyRowModel(
                    study: study,
                    pendingReviewCount: pending,
                    accuracy: accuracy,
                    lastPractice: lastPractice
                )
            }
        } catch {
            errorMessage = "Error al cargar estudios: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @discardableResult
    func createStudy() -> Bool {
        guard let ctx = modelContext,
              !newStudyTitle.isEmpty && !newStudyDescription.isEmpty else { return false }

        let study = SDStudy(title: newStudyTitle, desc: newStudyDescription)
        ctx.insert(study)

        do {
            try ctx.save()
        } catch {
            errorMessage = "Error al crear estudio: \(error.localizedDescription)"
            return false
        }

        newStudyTitle = ""
        newStudyDescription = ""
        fetchStudies()
        return true
    }

    func deleteStudy(id: UUID) {
        guard let ctx = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<SDStudy>(predicate: #Predicate { $0.id == id })
            if let study = try ctx.fetch(descriptor).first {
                ctx.delete(study)
                try ctx.save()
                fetchStudies()
            }
        } catch {
            errorMessage = "Error al eliminar estudio: \(error.localizedDescription)"
        }
    }
}
