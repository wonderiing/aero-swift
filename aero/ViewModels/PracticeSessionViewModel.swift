import SwiftUI
import SwiftData
import Combine

@MainActor
final class PracticeSessionViewModel: ObservableObject {
    let study: SDStudy
    @Published var flashcards: [SDFlashcard] = []
    @Published var currentIndex = 0
    @Published var isShowingAnswer = false
    @Published var userAnswer = ""
    @Published var selectedMCOption: String?
    @Published var shuffledOptions: [String] = []
    @Published var isLoading = false
    @Published var isSessionFinished = false

    @Published var evaluationResult: SDAttempt?
    @Published var isEvaluating = false

    @Published var sessionCorrectCount = 0
    @Published var sessionAnsweredCount = 0

    @Published var expandedExplanation: String?
    @Published var isExpandingExplanation = false
    @Published var lastEvaluationUsedAppleIntelligence = false

    var modelContext: ModelContext?

    init(study: SDStudy) {
        self.study = study
    }

    func startSession() {
        isLoading = true
        sessionCorrectCount = 0
        sessionAnsweredCount = 0

        let now = Date()
        let queue = study.flashcards
            .filter { $0.nextReviewAt <= now }
            .sorted { $0.nextReviewAt < $1.nextReviewAt }

        let analysis = GapAnalysis.compute(flashcards: study.flashcards)
        flashcards = prioritizeQueue(queue, gaps: analysis)
        currentIndex = 0
        prepareCurrentCard()
        isLoading = false
    }

    private func prioritizeQueue(_ queue: [SDFlashcard], gaps: GapAnalysis) -> [SDFlashcard] {
        let weakSet = Set(gaps.gaps.map { $0.concept.lowercased() })
        let scored = queue.map { card -> (SDFlashcard, Int) in
            let hits = card.conceptTags.filter { weakSet.contains($0.lowercased()) }.count
            return (card, hits)
        }
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }

    func prepareCurrentCard() {
        userAnswer = ""
        selectedMCOption = nil
        evaluationResult = nil
        isShowingAnswer = false
        expandedExplanation = nil
        lastEvaluationUsedAppleIntelligence = false
        guard currentIndex < flashcards.count else {
            shuffledOptions = []
            return
        }
        let card = flashcards[currentIndex]
        if card.type == .multipleChoice, let o = card.options {
            shuffledOptions = ([o.correct] + o.distractors).shuffled()
        } else {
            shuffledOptions = []
        }
    }

    var canSubmit: Bool {
        guard currentIndex < flashcards.count else { return false }
        let card = flashcards[currentIndex]
        switch card.type {
        case .open:
            return !userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .multipleChoice:
            return selectedMCOption != nil
        }
    }

    func submitAnswer() async {
        guard let ctx = modelContext, currentIndex < flashcards.count else { return }
        let currentCard = flashcards[currentIndex]

        isEvaluating = true
        lastEvaluationUsedAppleIntelligence = false

        let dto: CreateAttemptDto
        if IntelligentStudyAssistant.isAppleIntelligenceReady {
            do {
                dto = try await IntelligentStudyAssistant.evaluateStudentAnswer(
                    question: currentCard.question,
                    correctAnswer: currentCard.answer,
                    userAnswer: answerTextForEvaluation(card: currentCard),
                    cardType: currentCard.type,
                    options: currentCard.options
                )
                lastEvaluationUsedAppleIntelligence = true
            } catch {
                dto = AnswerEvaluationService.evaluate(
                    question: currentCard.question,
                    correctAnswer: currentCard.answer,
                    userAnswer: currentCard.type == .open ? userAnswer : nil,
                    selectedMultipleChoice: selectedMCOption,
                    cardType: currentCard.type,
                    options: currentCard.options
                )
            }
        } else {
            dto = AnswerEvaluationService.evaluate(
                question: currentCard.question,
                correctAnswer: currentCard.answer,
                userAnswer: currentCard.type == .open ? userAnswer : nil,
                selectedMultipleChoice: selectedMCOption,
                cardType: currentCard.type,
                options: currentCard.options
            )
        }

        // Save attempt + update SM-2
        let attempt = SDAttempt(dto: dto, flashcard: currentCard)
        ctx.insert(attempt)

        let quality = currentCard.sm2Quality(isCorrect: dto.isCorrect, confidence: dto.confidenceScore ?? 0)
        currentCard.updateSM2(quality: quality)

        do {
            try ctx.save()
            evaluationResult = attempt
            sessionAnsweredCount += 1
            if dto.isCorrect { sessionCorrectCount += 1 }
            isShowingAnswer = true
        } catch {
            evaluationResult = nil
        }

        isEvaluating = false
    }

    private func answerTextForEvaluation(card: SDFlashcard) -> String? {
        switch card.type {
        case .open: return userAnswer
        case .multipleChoice: return selectedMCOption
        }
    }

    func explainMore() async {
        guard currentIndex < flashcards.count else { return }
        let card = flashcards[currentIndex]
        isExpandingExplanation = true
        defer { isExpandingExplanation = false }

        if IntelligentStudyAssistant.isAppleIntelligenceReady {
            do {
                expandedExplanation = try await IntelligentStudyAssistant.expandExplanation(
                    question: card.question,
                    correctAnswer: card.answer,
                    userAnswer: answerTextForEvaluation(card: card),
                    feedbackSoFar: evaluationResult?.feedback,
                    resourceContext: nil
                )
            } catch {
                expandedExplanation = "No se pudo generar más detalle: \(error.localizedDescription)"
            }
        } else {
            expandedExplanation = "Activa Apple Intelligence en este dispositivo para ampliar la explicación con el modelo on-device."
        }
    }

    func nextCard() {
        if currentIndex + 1 < flashcards.count {
            currentIndex += 1
            prepareCurrentCard()
        } else {
            isSessionFinished = true
        }
    }
}
