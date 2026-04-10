import SwiftUI
import SwiftData

struct PracticeSessionView: View {
    @StateObject private var viewModel: PracticeSessionViewModel
    @StateObject private var speech = SpeechInputController()
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    init(study: SDStudy) {
        _viewModel = StateObject(wrappedValue: PracticeSessionViewModel(study: study))
    }

    var body: some View {
        ZStack {
            AeroAppBackground()

            if viewModel.isLoading {
                ProgressView("Preparando sesión...")
            } else if viewModel.isSessionFinished {
                SessionCompleteView(
                    correct: viewModel.sessionCorrectCount,
                    total: viewModel.sessionAnsweredCount,
                    action: { dismiss() }
                )
            } else if viewModel.flashcards.isEmpty {
                NoCardsView(action: { dismiss() })
            } else {
                VStack(spacing: 20) {
                    ProgressHeader(current: viewModel.currentIndex + 1, total: viewModel.flashcards.count)

                    FlashcardView(
                        card: viewModel.flashcards[viewModel.currentIndex],
                        isShowingAnswer: viewModel.isShowingAnswer,
                        userAnswer: $viewModel.userAnswer,
                        shuffledOptions: viewModel.shuffledOptions,
                        selectedMCOption: $viewModel.selectedMCOption,
                        evaluation: viewModel.evaluationResult,
                        usedAppleIntelligence: viewModel.lastEvaluationUsedAppleIntelligence,
                        expandedExplanation: viewModel.expandedExplanation,
                        isExpandingExplanation: viewModel.isExpandingExplanation,
                        onExplainMore: {
                            Task { await viewModel.explainMore() }
                        },
                        speech: speech
                    )

                    Spacer()

                    BottomControls(viewModel: viewModel)
                }
                .padding()
            }
        }
        .navigationTitle("Sesión de Repaso")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Salir") { dismiss() }
            }
        }
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.startSession()
        }
        .onDisappear {
            speech.stop()
        }
    }
}

struct ProgressHeader: View {
    let current: Int
    let total: Int

    var body: some View {
        AeroSurfaceCard {
            VStack(spacing: 8) {
                HStack {
                    Text("Tarjeta \(current) de \(total)")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(Double(current - 1) / Double(max(total, 1)) * 100))%")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                }

                ProgressView(value: Double(current - 1), total: Double(max(total, 1)))
                    .tint(.indigo)
            }
        }
    }
}

struct FlashcardView: View {
    let card: SDFlashcard
    let isShowingAnswer: Bool
    @Binding var userAnswer: String
    let shuffledOptions: [String]
    @Binding var selectedMCOption: String?
    let evaluation: SDAttempt?
    let usedAppleIntelligence: Bool
    let expandedExplanation: String?
    let isExpandingExplanation: Bool
    let onExplainMore: () -> Void
    @ObservedObject var speech: SpeechInputController

    var body: some View {
        AeroSurfaceCard {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PREGUNTA")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.indigo)

                    Text(card.question)
                        .font(.title3)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(24)

                Divider()

                if isShowingAnswer {
                    answerSection
                } else {
                    inputSection
                }
            }
        }
    }

    @ViewBuilder
    private var answerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RESPUESTA MODELO")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.green)

            Text(card.answer)
                .font(.body)
                .foregroundColor(.primary)

            if let ev = evaluation {
                if ev.isCorrect {
                    Label("Correcto", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                } else {
                    Label("A revisar", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.subheadline)
                }

                if usedAppleIntelligence {
                    Label("Evaluación con Foundation Models", systemImage: "apple.intelligence")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let fb = ev.feedback {
                    Text(fb)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                if !ev.isCorrect, let err = ev.errorType {
                    Text("Tipo de error: \(errorTypeLabel(err))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(action: onExplainMore) {
                    if isExpandingExplanation {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else {
                        Label("Explicar más", systemImage: "text.book.closed")
                    }
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)

                if let more = expandedExplanation, !more.isEmpty {
                    Text(more)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .padding(.top, 8)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.05))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func errorTypeLabel(_ t: ErrorType) -> String {
        switch t {
        case .conceptual: return "conceptual"
        case .memoria: return "memoria"
        case .confusion: return "confusión"
        case .incompleto: return "incompleto"
        }
    }

    @ViewBuilder
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TU RESPUESTA")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)

            if card.type == .open {
                TextEditor(text: $userAnswer)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(.rect(cornerRadius: 8))

                HStack {
                    Button {
                        Task {
                            let ok = await speech.requestAuthorization()
                            guard ok else { return }
                            if speech.isRecording {
                                speech.stop()
                            } else {
                                speech.start { text in
                                    userAnswer = text
                                }
                            }
                        }
                    } label: {
                        Label(speech.isRecording ? "Detener" : "Dictar", systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)

                    if speech.authorizationDenied {
                        Text("Activa micrófono y reconocimiento de voz en Ajustes.")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(shuffledOptions, id: \.self) { opt in
                        Button {
                            selectedMCOption = opt
                        } label: {
                            HStack {
                                Image(systemName: selectedMCOption == opt ? "largecircle.fill.circle" : "circle")
                                Text(opt)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(12)
                            .background(selectedMCOption == opt ? Color.blue.opacity(0.12) : Color(uiColor: .systemGray6))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(24)
        .background(Color.white)
    }
}

struct BottomControls: View {
    @ObservedObject var viewModel: PracticeSessionViewModel

    var body: some View {
        VStack {
            if viewModel.isShowingAnswer {
                Button(action: viewModel.nextCard) {
                    HStack {
                        Text("Siguiente Tarjeta")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                }
                .buttonStyle(AeroPrimaryButtonStyle())
            } else {
                Button {
                    Task { await viewModel.submitAnswer() }
                } label: {
                    HStack {
                        if viewModel.isEvaluating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(IntelligentStudyAssistant.isAppleIntelligenceReady ? "Enviar (IA on-device)" : "Enviar respuesta")
                            Image(systemName: IntelligentStudyAssistant.isAppleIntelligenceReady ? "apple.intelligence" : "paperplane.fill")
                        }
                    }
                    .font(.headline)
                }
                .buttonStyle(AeroPrimaryButtonStyle(disabled: !viewModel.canSubmit || viewModel.isEvaluating))
                .disabled(!viewModel.canSubmit || viewModel.isEvaluating)
            }
        }
    }
}

struct SessionCompleteView: View {
    let correct: Int
    let total: Int
    let action: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 100))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("¡Sesión completada!")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Has respondido \(total) tarjetas. Aciertos: \(correct). El algoritmo SM-2 actualizará tus próximos repasos.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: action) {
                Text("Volver al estudio")
                    .fontWeight(.bold)
                    .font(.headline)
            }
            .buttonStyle(AeroPrimaryButtonStyle())
            .padding(.horizontal, 40)
        }
    }
}

struct NoCardsView: View {
    let action: () -> Void

    var body: some View {
        AeroSurfaceCard {
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundStyle(.indigo.opacity(0.35))
                Text("¡Estás al día!")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("No tienes flashcards pendientes de repaso para este estudio ahora.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Volver", action: action)
                    .buttonStyle(.bordered)
            }
        }
    }
}

#if DEBUG
#Preview("Progreso sesión") {
    SessionCompleteView(correct: 4, total: 6, action: {})
}

#Preview("Sin tarjetas") {
    NoCardsView(action: {})
}

#Preview("Cabecera progreso") {
    ProgressHeader(current: 2, total: 5)
        .padding()
}
#endif
