import SwiftUI

// MARK: - Anki Session View

struct AnkiSessionView: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var queue: [SDAnkiCard]
    @State private var isFreeSession: Bool
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var isFinished = false
    @State private var sessionStats = SessionStats()

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }

    init(viewModel: StudyDetailViewModel) {
        self.viewModel = viewModel
        let due = viewModel.ankiReviewQueue
        if due.isEmpty {
            // No hay tarjetas pendientes por SM-2: sesión libre con todas las tarjetas
            _queue = State(initialValue: viewModel.ankiCards.shuffled())
            _isFreeSession = State(initialValue: true)
        } else {
            _queue = State(initialValue: due)
            _isFreeSession = State(initialValue: false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.08, blue: 0.38), Color(red: 0.22, green: 0.08, blue: 0.42)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if isFinished || queue.isEmpty {
                    AnkiFinishedView(stats: sessionStats, onDismiss: { dismiss() })
                } else {
                    VStack(spacing: 0) {
                    AnkiProgressHeader(
                        current: currentIndex + 1,
                        total: queue.count,
                        stats: sessionStats,
                        isFreeSession: isFreeSession,
                        isLargeCanvas: isLargeCanvas
                    )
                        .padding(.horizontal, isLargeCanvas ? 32 : 20)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                        Spacer(minLength: 0)

                        AnkiFlipCard(
                            card: queue[currentIndex],
                            isFlipped: $isFlipped,
                            isLargeCanvas: isLargeCanvas
                        )
                        .padding(.horizontal, isLargeCanvas ? 48 : 20)

                        Spacer(minLength: 0)

                        if isFlipped {
                            AnkiRatingButtons(isLargeCanvas: isLargeCanvas) { quality in
                                rateCard(quality: quality)
                            }
                            .padding(.horizontal, isLargeCanvas ? 48 : 20)
                            .padding(.bottom, isLargeCanvas ? 40 : 28)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            Button {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    isFlipped = true
                                }
                            } label: {
                                Text("Ver respuesta")
                                    .font(isLargeCanvas ? .title3 : .headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, isLargeCanvas ? 18 : 16)
                                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal, isLargeCanvas ? 48 : 20)
                            .padding(.bottom, isLargeCanvas ? 40 : 28)
                            .transition(.opacity)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isFlipped)
                }
            }
            .navigationTitle(isFreeSession ? "Repaso libre" : "Flashcards pendientes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func rateCard(quality: Int) {
        let card = queue[currentIndex]
        viewModel.updateAnkiSM2(card: card, quality: quality)
        sessionStats.record(quality: quality)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if currentIndex + 1 < queue.count {
                currentIndex += 1
                isFlipped = false
            } else {
                isFinished = true
            }
        }
    }
}

// MARK: - Flip Card

private struct AnkiFlipCard: View {
    let card: SDAnkiCard
    @Binding var isFlipped: Bool
    let isLargeCanvas: Bool

    var body: some View {
        ZStack {
            // Front face
            AnkiCardFace(text: card.front, label: "PREGUNTA", color: .white, textColor: Color(red: 0.12, green: 0.08, blue: 0.38), isLargeCanvas: isLargeCanvas)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            // Back face
            AnkiCardFace(text: card.back, label: "RESPUESTA", color: Color(red: 0.28, green: 0.22, blue: 0.92), textColor: .white, tags: card.tags, isLargeCanvas: isLargeCanvas)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: isLargeCanvas ? 600 : .infinity)
        .frame(height: isLargeCanvas ? 300 : 240)
        .onTapGesture {
            if !isFlipped {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isFlipped = true
                }
            }
        }
    }
}

private struct AnkiCardFace: View {
    let text: String
    let label: String
    let color: Color
    let textColor: Color
    var tags: [String] = []
    let isLargeCanvas: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .kerning(1.5)
                .foregroundStyle(textColor.opacity(0.5))

            Spacer()

            Text(text)
                .font(isLargeCanvas ? .title2 : .title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.75)

            Spacer()

            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(textColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(textColor.opacity(0.7))
                    }
                }
            }
        }
        .padding(isLargeCanvas ? 36 : 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(color)
                .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        )
    }
}

// MARK: - Rating Buttons

private struct AnkiRatingButtons: View {
    let isLargeCanvas: Bool
    let onRate: (Int) -> Void

    private let ratings: [(label: String, icon: String, quality: Int, color: Color)] = [
        ("De nuevo", "xmark.circle.fill", 1, .red),
        ("Difícil", "minus.circle.fill", 3, .orange),
        ("Bien", "checkmark.circle.fill", 4, .green),
        ("Perfecto", "star.circle.fill", 5, Color(red: 0.4, green: 0.2, blue: 0.9))
    ]

    var body: some View {
        VStack(spacing: 10) {
            Text("¿Qué tan bien lo recordaste?")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: isLargeCanvas ? 12 : 8) {
                ForEach(ratings, id: \.quality) { rating in
                    Button {
                        onRate(rating.quality)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: rating.icon)
                                .font(isLargeCanvas ? .title2 : .title3)
                                .foregroundStyle(rating.color)
                            Text(rating.label)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isLargeCanvas ? 14 : 12)
                        .background(rating.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(rating.color.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: false)
                }
            }
        }
    }
}

// MARK: - Progress Header

private struct AnkiProgressHeader: View {
    let current: Int
    let total: Int
    let stats: SessionStats
    let isFreeSession: Bool
    let isLargeCanvas: Bool

    var progress: Double { total > 0 ? Double(current - 1) / Double(total) : 0 }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(current) / \(total)")
                        .font(isLargeCanvas ? .headline : .subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    if isFreeSession {
                        Text("Repaso libre · SM-2 actualizado igualmente")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer()
                HStack(spacing: 12) {
                    Label("\(stats.easy + stats.perfect)", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.green)
                    Label("\(stats.hard)", systemImage: "minus.circle.fill")
                        .font(.caption).foregroundStyle(.orange)
                    Label("\(stats.again)", systemImage: "xmark.circle.fill")
                        .font(.caption).foregroundStyle(.red)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15)).frame(height: 5)
                    Capsule()
                        .fill(LinearGradient(
                            colors: isFreeSession ? [.teal, .indigo] : [.indigo, .purple],
                            startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 5)
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - Finished View

private struct AnkiFinishedView: View {
    let stats: SessionStats
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.indigo.opacity(0.3), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            VStack(spacing: 8) {
                Text("¡Sesión completada!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Has repasado todas las tarjetas pendientes.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 24) {
                StatBadge(value: stats.easy + stats.perfect, label: "Correctas", color: .green)
                StatBadge(value: stats.hard, label: "Difíciles", color: .orange)
                StatBadge(value: stats.again, label: "De nuevo", color: .red)
            }

            Button(action: onDismiss) {
                Text("Volver")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(red: 0.12, green: 0.08, blue: 0.38))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 40)
        }
        .padding(32)
    }
}

private struct StatBadge: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Session Stats

struct SessionStats {
    var again = 0
    var hard = 0
    var easy = 0
    var perfect = 0

    mutating func record(quality: Int) {
        switch quality {
        case 1, 2: again += 1
        case 3: hard += 1
        case 4: easy += 1
        default: perfect += 1
        }
    }
}
