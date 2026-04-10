import Foundation
import SwiftData

// MARK: - Study

@Model
final class SDStudy {
    @Attribute(.unique) var id: UUID
    var title: String
    var desc: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SDResource.study)
    var resources: [SDResource] = []

    @Relationship(deleteRule: .cascade, inverse: \SDFlashcard.study)
    var flashcards: [SDFlashcard] = []

    init(title: String, desc: String) {
        self.id = UUID()
        self.title = title
        self.desc = desc
        self.createdAt = Date()
    }
}

// MARK: - Resource

@Model
final class SDResource {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var sourceName: String?
    var createdAt: Date

    var study: SDStudy?

    init(title: String, content: String, sourceName: String? = nil, study: SDStudy) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.sourceName = sourceName
        self.createdAt = Date()
        self.study = study
    }
}

// MARK: - Flashcard

@Model
final class SDFlashcard {
    @Attribute(.unique) var id: UUID
    var question: String
    var answer: String
    var typeRaw: String         // "open" or "multiple_choice"
    var optionsCorrect: String? // MC correct answer
    var optionsDistractors: [String]? // MC distractors
    var conceptTags: [String]
    var createdAt: Date

    // SM-2 spaced repetition fields
    var nextReviewAt: Date
    var easeFactor: Double
    var intervalDays: Int
    var repetitions: Int

    var study: SDStudy?
    var resource: SDResource?

    @Relationship(deleteRule: .cascade, inverse: \SDAttempt.flashcard)
    var attempts: [SDAttempt] = []

    var type: FlashcardType {
        get { typeRaw == "multiple_choice" ? .multipleChoice : .open }
        set { typeRaw = newValue == .multipleChoice ? "multiple_choice" : "open" }
    }

    var options: FlashcardOptions? {
        guard type == .multipleChoice,
              let correct = optionsCorrect,
              let dist = optionsDistractors, !dist.isEmpty else { return nil }
        return FlashcardOptions(correct: correct, distractors: dist)
    }

    init(
        question: String,
        answer: String,
        type: FlashcardType,
        options: FlashcardOptions? = nil,
        conceptTags: [String],
        study: SDStudy,
        resource: SDResource?
    ) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.typeRaw = type == .multipleChoice ? "multiple_choice" : "open"
        self.optionsCorrect = options?.correct
        self.optionsDistractors = options?.distractors
        self.conceptTags = conceptTags
        self.createdAt = Date()
        self.nextReviewAt = Date()
        self.easeFactor = 2.5
        self.intervalDays = 0
        self.repetitions = 0
        self.study = study
        self.resource = resource
    }

    /// SM-2 algorithm: update schedule after an attempt.
    /// Quality: 0-5 (0=complete blackout, 5=perfect)
    func updateSM2(quality: Int) {
        let q = min(5, max(0, quality))
        let newEF = max(1.3, easeFactor + (0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02)))

        if q < 3 {
            // Reset
            repetitions = 0
            intervalDays = 0
        } else {
            repetitions += 1
            switch repetitions {
            case 1: intervalDays = 1
            case 2: intervalDays = 6
            default: intervalDays = Int(round(Double(intervalDays) * easeFactor))
            }
        }
        easeFactor = newEF
        nextReviewAt = Calendar.current.date(byAdding: .day, value: max(1, intervalDays), to: Date()) ?? Date()
    }

    /// Map isCorrect + confidence to SM-2 quality 0-5.
    func sm2Quality(isCorrect: Bool, confidence: Double) -> Int {
        if !isCorrect { return confidence > 0.3 ? 2 : 1 }
        if confidence > 0.9 { return 5 }
        if confidence > 0.65 { return 4 }
        return 3
    }
}

// MARK: - Attempt

@Model
final class SDAttempt {
    @Attribute(.unique) var id: UUID
    var userAnswer: String?
    var isCorrect: Bool
    var errorTypeRaw: String?
    var missingConcepts: [String]?
    var incorrectConcepts: [String]?
    var feedback: String?
    var confidenceScore: Double
    var answeredAt: Date

    var flashcard: SDFlashcard?

    var errorType: ErrorType? {
        get { errorTypeRaw.flatMap { ErrorType(rawValue: $0) } }
        set { errorTypeRaw = newValue?.rawValue }
    }

    init(
        dto: CreateAttemptDto,
        flashcard: SDFlashcard
    ) {
        self.id = UUID()
        self.userAnswer = dto.userAnswer
        self.isCorrect = dto.isCorrect
        self.errorTypeRaw = dto.errorType?.rawValue
        self.missingConcepts = dto.missingConcepts
        self.incorrectConcepts = dto.incorrectConcepts
        self.feedback = dto.feedback
        self.confidenceScore = dto.confidenceScore ?? 0
        self.answeredAt = Date()
        self.flashcard = flashcard
    }
}

// MARK: - Gap Analysis (computed, not persisted)

struct GapAnalysis {
    let studyId: UUID
    let totalAttempts: Int
    let gaps: [ConceptGap]
    let strongConcepts: [StrongConcept]

    static func compute(flashcards: [SDFlashcard]) -> GapAnalysis {
        var conceptStats: [String: (total: Int, errors: Int, lastSeen: Date?, errorTypes: [ErrorType])] = [:]

        for card in flashcards {
            for attempt in card.attempts {
                for tag in card.conceptTags {
                    let key = tag.lowercased()
                    var stat = conceptStats[key] ?? (0, 0, nil, [])
                    stat.total += 1
                    if !attempt.isCorrect {
                        stat.errors += 1
                        if let et = attempt.errorType { stat.errorTypes.append(et) }
                    }
                    if stat.lastSeen == nil || attempt.answeredAt > stat.lastSeen! {
                        stat.lastSeen = attempt.answeredAt
                    }
                    conceptStats[key] = stat
                }
            }
        }

        let totalAttempts = flashcards.flatMap(\.attempts).count
        var gaps: [ConceptGap] = []
        var strong: [StrongConcept] = []

        for (concept, stat) in conceptStats where stat.total >= 2 {
            let errorRate = Double(stat.errors) / Double(stat.total)
            let dominantError = stat.errorTypes.isEmpty ? nil : Dictionary(grouping: stat.errorTypes, by: { $0 }).max(by: { $0.value.count < $1.value.count })?.key

            if errorRate > 0.3 {
                gaps.append(ConceptGap(
                    concept: concept,
                    error_rate: errorRate,
                    total_attempts: stat.total,
                    errors: stat.errors,
                    dominant_error_type: dominantError,
                    trend: "estable",
                    last_seen: stat.lastSeen
                ))
            } else {
                strong.append(StrongConcept(
                    concept: concept,
                    error_rate: errorRate,
                    total_attempts: stat.total
                ))
            }
        }

        gaps.sort { $0.error_rate > $1.error_rate }
        strong.sort { $0.error_rate < $1.error_rate }

        return GapAnalysis(
            studyId: flashcards.first?.study?.id ?? UUID(),
            totalAttempts: totalAttempts,
            gaps: gaps,
            strongConcepts: strong
        )
    }
}
