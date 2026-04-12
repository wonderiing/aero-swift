import Foundation
import SwiftData

// MARK: - Study

@Model
final class SDStudy {
    @Attribute(.unique) var id: UUID
    var title: String
    var desc: String
    var createdAt: Date
    /// Imagen de portada elegida por el usuario. Se guarda fuera del SQLite (.externalStorage).
    @Attribute(.externalStorage) var coverImageData: Data?

    @Relationship(deleteRule: .cascade, inverse: \SDResource.study)
    var resources: [SDResource] = []

    @Relationship(deleteRule: .cascade, inverse: \SDFlashcard.study)
    var flashcards: [SDFlashcard] = []

    @Relationship(deleteRule: .cascade, inverse: \SDAnkiCard.study)
    var ankiCards: [SDAnkiCard] = []

    @Relationship(deleteRule: .cascade, inverse: \SDStudyBoard.study)
    var board: SDStudyBoard?

    init(title: String, desc: String) {
        self.id = UUID()
        self.title = title
        self.desc = desc
        self.createdAt = Date()
        self.coverImageData = nil
    }
}

// MARK: - Study board (pizarra tipo canvas por estudio)

@Model
final class SDStudyBoard {
    @Attribute(.unique) var id: UUID
    /// JSON `BoardDocument`
    var documentJSON: String
    var updatedAt: Date

    var study: SDStudy?

    init(documentJSON: String = "", study: SDStudy) {
        self.id = UUID()
        self.documentJSON = documentJSON
        self.updatedAt = Date()
        self.study = study
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

// MARK: - Anki Card

@Model
final class SDAnkiCard {
    @Attribute(.unique) var id: UUID
    var front: String
    var back: String
    var tags: [String]
    var createdAt: Date

    // SM-2 spaced repetition
    var nextReviewAt: Date
    var easeFactor: Double
    var intervalDays: Int
    var repetitions: Int

    /// Historial de calificaciones SM-2 (1-5). Usado para calcular lagunas de conocimiento.
    var ratingHistory: [Int] = []

    var study: SDStudy?
    var resource: SDResource?

    init(front: String, back: String, tags: [String], study: SDStudy, resource: SDResource?) {
        self.id = UUID()
        self.front = front
        self.back = back
        self.tags = tags
        self.createdAt = Date()
        self.nextReviewAt = Date()
        self.easeFactor = 2.5
        self.intervalDays = 0
        self.repetitions = 0
        self.ratingHistory = []
        self.study = study
        self.resource = resource
    }

    func updateSM2(quality: Int) {
        let q = min(5, max(0, quality))
        ratingHistory.append(q)
        let newEF = max(1.3, easeFactor + (0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02)))
        if q < 3 {
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

    /// Tasa de error Anki: proporción de calificaciones < 3 (De nuevo / muy difícil).
    var ankiErrorRate: Double {
        guard !ratingHistory.isEmpty else { return 0 }
        let failures = ratingHistory.filter { $0 < 3 }.count
        return Double(failures) / Double(ratingHistory.count)
    }

    /// true si la tarjeta ha sido calificada como difícil de forma recurrente.
    var isStruggling: Bool {
        ratingHistory.count >= 2 && ankiErrorRate > 0.3
    }
}

// MARK: - Gap Analysis (computed, not persisted)

struct GapAnalysis {
    let studyId: UUID
    let totalAttempts: Int
    let errorTypeBreakdown: [(type: ErrorType, count: Int)]
    let gaps: [ConceptGap]
    let strongConcepts: [StrongConcept]

    // Anki-specific stats
    let ankiTotalReviews: Int
    let ankiGaps: [ConceptGap]
    let ankiStrongConcepts: [StrongConcept]

    private static func shortQuestionLabel(_ question: String) -> String {
        let t = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "Sin pregunta" }
        return t.count > 72 ? String(t.prefix(69)) + "…" : t
    }

    static func compute(flashcards: [SDFlashcard], ankiCards: [SDAnkiCard] = []) -> GapAnalysis {
        /// Agregación por etiqueta de concepto o, si no hay etiquetas, por tarjeta (una laguna por pregunta).
        struct ConceptAgg {
            var displayLabel: String
            var total: Int
            var errors: Int
            var lastSeen: Date?
            var errorTypes: [ErrorType]
        }

        var conceptStats: [String: ConceptAgg] = [:]
        var errorTypeCounts: [ErrorType: Int] = [:]

        for card in flashcards {
            let attempts = card.attempts
            guard !attempts.isEmpty else { continue }

            let bucketKeys: [(key: String, label: String)] = {
                if !card.conceptTags.isEmpty {
                    return card.conceptTags.map { ($0.lowercased(), $0) }
                }
                let label = Self.shortQuestionLabel(card.question)
                return [(card.id.uuidString, label)]
            }()

            for attempt in attempts {
                if !attempt.isCorrect, let et = attempt.errorType {
                    errorTypeCounts[et, default: 0] += 1
                }

                for (aggKey, label) in bucketKeys {
                    var stat = conceptStats[aggKey] ?? ConceptAgg(
                        displayLabel: label,
                        total: 0,
                        errors: 0,
                        lastSeen: nil,
                        errorTypes: []
                    )
                    stat.total += 1
                    if !attempt.isCorrect {
                        stat.errors += 1
                        if let et = attempt.errorType { stat.errorTypes.append(et) }
                    }
                    if stat.lastSeen == nil || attempt.answeredAt > stat.lastSeen! {
                        stat.lastSeen = attempt.answeredAt
                    }
                    stat.displayLabel = label
                    conceptStats[aggKey] = stat
                }
            }
        }

        let totalAttempts = flashcards.flatMap(\.attempts).count
        var gaps: [ConceptGap] = []
        var strong: [StrongConcept] = []

        for (aggKey, stat) in conceptStats {
            guard stat.total >= 1 else { continue }
            let errorRate = Double(stat.errors) / Double(stat.total)
            let dominantError = stat.errorTypes.isEmpty ? nil : Dictionary(grouping: stat.errorTypes, by: { $0 }).max(by: { $0.value.count < $1.value.count })?.key

            if stat.errors >= 1 {
                let severity: GapSeverity = stat.errors == 1 ? .warning : .fault
                gaps.append(ConceptGap(
                    id: aggKey,
                    concept: stat.displayLabel,
                    error_rate: errorRate,
                    total_attempts: stat.total,
                    errors: stat.errors,
                    dominant_error_type: dominantError,
                    trend: "estable",
                    last_seen: stat.lastSeen,
                    severity: severity
                ))
            } else if stat.total >= 3, stat.errors == 0 {
                strong.append(StrongConcept(
                    concept: stat.displayLabel,
                    error_rate: errorRate,
                    total_attempts: stat.total
                ))
            }
        }

        gaps.sort { $0.error_rate > $1.error_rate }
        strong.sort { $0.error_rate < $1.error_rate }

        let breakdown = errorTypeCounts
            .sorted { $0.value > $1.value }
            .map { (type: $0.key, count: $0.value) }

        // ── Anki gaps ──
        var ankiConceptStats: [String: (total: Int, failures: Int)] = [:]
        for card in ankiCards where !card.ratingHistory.isEmpty {
            let failures = card.ratingHistory.filter { $0 < 3 }.count
            for tag in card.tags {
                let key = tag.lowercased()
                var stat = ankiConceptStats[key] ?? (0, 0)
                stat.total += card.ratingHistory.count
                stat.failures += failures
                ankiConceptStats[key] = stat
            }
        }

        var ankiGaps: [ConceptGap] = []
        var ankiStrong: [StrongConcept] = []
        let ankiTotalReviews = ankiCards.reduce(0) { $0 + $1.ratingHistory.count }

        for (concept, stat) in ankiConceptStats {
            let errorRate = Double(stat.failures) / Double(stat.total)
            // Laguna: al menos 1 fallo (advertencia si 1, fallo si 2+)
            if stat.failures >= 1 {
                let severity: GapSeverity = stat.failures == 1 ? .warning : .fault
                ankiGaps.append(ConceptGap(
                    id: concept,
                    concept: concept,
                    error_rate: errorRate,
                    total_attempts: stat.total,
                    errors: stat.failures,
                    dominant_error_type: nil,
                    trend: "estable",
                    last_seen: nil,
                    severity: severity
                ))
            // Dominado: al menos 5 repasos sin ningún fallo
            } else if stat.total >= 5 && stat.failures == 0 {
                ankiStrong.append(StrongConcept(
                    concept: concept,
                    error_rate: errorRate,
                    total_attempts: stat.total
                ))
            }
            // Entre medias: en progreso, no se muestra en ninguna lista todavía
        }
        ankiGaps.sort { $0.error_rate > $1.error_rate }
        ankiStrong.sort { $0.error_rate < $1.error_rate }

        return GapAnalysis(
            studyId: flashcards.first?.study?.id ?? ankiCards.first?.study?.id ?? UUID(),
            totalAttempts: totalAttempts,
            errorTypeBreakdown: breakdown,
            gaps: gaps,
            strongConcepts: strong,
            ankiTotalReviews: ankiTotalReviews,
            ankiGaps: ankiGaps,
            ankiStrongConcepts: ankiStrong
        )
    }

    /// Lagunas para UI y generación IA: primero el análisis estadístico; si está vacío, lista explícita
    /// por tarjeta (etiquetas o extracto de pregunta) con al menos un fallo; si no hay examen, usa lagunas Anki.
    static func reinforcementGaps(flashcards: [SDFlashcard], ankiCards: [SDAnkiCard] = []) -> [ConceptGap] {
        let base = compute(flashcards: flashcards, ankiCards: ankiCards)
        if !base.gaps.isEmpty { return base.gaps }

        var fromExam: [ConceptGap] = []
        for card in flashcards {
            let attempts = card.attempts
            let wrongs = attempts.filter { !$0.isCorrect }.count
            guard wrongs >= 1 else { continue }
            let total = max(1, attempts.count)
            let rate = Double(wrongs) / Double(total)
            let wrongAttempts = attempts.filter { !$0.isCorrect }
            let errTypes = wrongAttempts.compactMap(\.errorType)
            let dominant = errTypes.isEmpty ? nil : Dictionary(grouping: errTypes, by: { $0 }).max(by: { $0.value.count < $1.value.count })?.key

            let label: String
            let tags = card.conceptTags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if tags.isEmpty {
                label = shortQuestionLabel(card.question)
            } else {
                label = tags.joined(separator: " · ")
            }

            let severity: GapSeverity = wrongs == 1 ? .warning : .fault
            fromExam.append(ConceptGap(
                id: "exam-\(card.id.uuidString)",
                concept: label,
                error_rate: rate,
                total_attempts: total,
                errors: wrongs,
                dominant_error_type: dominant,
                trend: "estable",
                last_seen: attempts.map(\.answeredAt).max(),
                severity: severity
            ))
        }
        if !fromExam.isEmpty {
            return fromExam.sorted { $0.error_rate > $1.error_rate }
        }
        return base.ankiGaps
    }
}
