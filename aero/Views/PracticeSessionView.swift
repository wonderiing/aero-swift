import SwiftUI
import SwiftData

struct PracticeSessionView: View {
    @StateObject private var viewModel: PracticeSessionViewModel
    @StateObject private var speech = SpeechInputController()
    @StateObject private var tts = TextToSpeechManager()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("sessionStyle") private var sessionStyle: String = ""
    @AppStorage("accessibilityNeeds") private var accessibilityNeeds: String = ""
    @AppStorage("focusMode") private var focusMode: Bool = false

    init(study: SDStudy) {
        _viewModel = StateObject(wrappedValue: PracticeSessionViewModel(study: study))
    }

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var contentWidth: CGFloat {
        isLargeCanvas ? AeroAdaptiveLayout.maxRegularContentWidth : AeroAdaptiveLayout.maxCompactContentWidth
    }

    private var sessionStyleSet: Set<String> {
        Set(sessionStyle.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }
    private var needsSet: Set<String> {
        Set(accessibilityNeeds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    private var prefersAudio: Bool {
        sessionStyleSet.contains("prefer_audio") || needsSet.contains("dyslexia")
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
                VStack(spacing: 16) {
                    ProgressHeader(
                        current: viewModel.currentIndex + 1,
                        total: viewModel.flashcards.count,
                        isLargeCanvas: isLargeCanvas,
                        streak: (focusMode || needsSet.contains("adhd")) ? viewModel.consecutiveCorrectStreak : nil
                    )

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
                        speech: speech,
                        isLargeCanvas: isLargeCanvas,
                        prefersAudio: prefersAudio,
                        needs: needsSet,
                        tts: tts
                    )

                    BottomControls(viewModel: viewModel, isLargeCanvas: isLargeCanvas)
                }
                .padding(.horizontal, isLargeCanvas ? 24 : 20)
                .padding(.bottom, 16)
                .frame(maxWidth: contentWidth)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Sesión de Repaso")
        .navigationBarTitleDisplayMode(isLargeCanvas ? .automatic : .inline)
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
            tts.stop()
        }
    }
}

struct ProgressHeader: View {
    let current: Int
    let total: Int
    let isLargeCanvas: Bool
    let streak: Int?

    var body: some View {
        VStack(spacing: 12) {
            Text("Evaluación actual")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("Pregunta \(current) de \(total)")
                    .font(isLargeCanvas ? .title3 : .headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.aeroNavy)
                Spacer()
                if let streak, streak >= 2 {
                    Text("🔥 \(streak)")
                        .font(isLargeCanvas ? .title3 : .headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Racha \(streak)")
                }
                Text("\(Int(Double(current - 1) / Double(max(total, 1)) * 100))%")
                    .font(isLargeCanvas ? .title3 : .headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.aeroNavy)
            }
            ProgressView(value: Double(current - 1), total: Double(max(total, 1)))
                .tint(Color.aeroMint)
                .scaleEffect(x: 1, y: 2)
        }
        .padding(.top, 4)
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
    let isLargeCanvas: Bool
    let prefersAudio: Bool
    let needs: Set<String>
    @ObservedObject var tts: TextToSpeechManager
    @Environment(\.colorScheme) private var colorScheme

    private var isDyslexia: Bool { needs.contains("dyslexia") }
    private var questionInk: Color { colorScheme == .light ? Color.aeroNavy : Color.primary }
    private var lineSpacing: CGFloat { isDyslexia ? 7 : 4 }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Question section
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Label(card.type == .open ? "Pregunta abierta" : "Opción múltiple",
                              systemImage: card.type == .open ? "text.bubble" : "list.bullet.circle")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(card.type == .open ? Color.aeroNavy : Color.aeroLavender)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background((card.type == .open ? Color.aeroNavy : Color.aeroLavender).opacity(0.12))
                            .clipShape(.rect(cornerRadius: 10))

                        Spacer()

                        if prefersAudio {
                            Button {
                                tts.speak(card.question)
                            } label: {
                                Label("Audio", systemImage: "speaker.wave.2.fill")
                                    .labelStyle(.iconOnly)
                                    .font(.title3)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Reproducir audio de la pregunta")
                        }
                    }

                    Text(card.question)
                        .font(isLargeCanvas ? .largeTitle : .title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(questionInk)
                        .lineSpacing(lineSpacing)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                if isShowingAnswer {
                    answerSection
                } else {
                    inputSection
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(colorScheme == .dark ? Color(white: 0.13) : Color.aeroCardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.08), radius: 16, y: 7)
            )
        }
        .scrollBounceBehavior(.basedOnSize)
        .onChange(of: card.id) {
            tts.stop()
            speech.stop()
        }
    }

    @ViewBuilder
    private var answerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // For MC cards always show the model answer; for open cards only show it if incorrect
            if card.type == .multipleChoice {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Respuesta correcta")
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                        .textCase(.uppercase)
                    Text(card.answer)
                        .font(.title3)
                        .lineSpacing(lineSpacing)
                        .foregroundStyle(.primary)
                }
            }

            if let ev = evaluation {
                // Result badge
                if ev.isCorrect {
                    let isPartial = ev.errorType == .incompleto || !(ev.missingConcepts ?? []).isEmpty
                    Label(isPartial ? "Correcto — incompleto" : "Correcto",
                          systemImage: isPartial ? "checkmark.seal.fill" : "checkmark.circle.fill")
                        .foregroundStyle(isPartial ? Color.teal : Color.green)
                        .font(.title3)
                        .fontWeight(.bold)
                } else {
                    Label("Incorrecto", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title3)
                        .fontWeight(.bold)
                }

                // Show model answer for open cards only when wrong
                if card.type == .open && !ev.isCorrect {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Respuesta correcta")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(card.answer)
                            .font(.title3)
                            .lineSpacing(lineSpacing)
                            .foregroundStyle(.primary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 12))
                }

                // Missing concepts for partial correct
                if let missing = ev.missingConcepts, !missing.isEmpty {
                    Text("Te faltó mencionar: \(missing.joined(separator: ", ")).")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                // Feedback
                if let fb = ev.feedback, !fb.isEmpty {
                    Text(fb)
                        .font(.body)
                        .lineSpacing(lineSpacing)
                        .foregroundStyle(.secondary)
                }

                if usedAppleIntelligence {
                    Label("Evaluado con Foundation Models", systemImage: "apple.intelligence")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 12) {
                    Button(action: onExplainMore) {
                        if isExpandingExplanation {
                            ProgressView().scaleEffect(0.9)
                        } else {
                            Label("Explicar más", systemImage: "text.book.closed")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        tts.speak(card.answer)
                    } label: {
                        Label("Leer respuesta", systemImage: "speaker.wave.2.fill")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel("Leer respuesta correcta en voz alta")
                }

                if let more = expandedExplanation, !more.isEmpty {
                    Text(more)
                        .font(.body)
                        .lineSpacing(lineSpacing)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.03))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tu respuesta")
                .font(.callout)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if card.type == .open {
                TextEditor(text: $userAnswer)
                    .font(isLargeCanvas ? .title2 : .title3)
                    .frame(minHeight: isLargeCanvas ? 220 : 160)
                    .padding(14)
                    .background(Color.aeroSecondaryBackground)
                    .clipShape(.rect(cornerRadius: 14))

                HStack(spacing: 12) {
                    Button {
                        Task {
                            let ok = await speech.requestAuthorization()
                            guard ok else { return }
                            if speech.isRecording {
                                speech.stop()
                            } else {
                                speech.start { text in
                                    Task { @MainActor in
                                        userAnswer = text
                                    }
                                }
                            }
                        }
                    } label: {
                        Label(speech.isRecording ? "Detener" : "Dictar",
                              systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(speech.isRecording ? .red : Color.aeroNavy)

                    if speech.authorizationDenied {
                        Text("Activa micrófono en Ajustes.")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(shuffledOptions, id: \.self) { opt in
                        Button {
                            selectedMCOption = opt
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: selectedMCOption == opt ? "largecircle.fill.circle" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(selectedMCOption == opt ? Color.aeroNavy : Color.secondary)
                                Text(opt)
                                    .font(.title3)
                                    .fontWeight(selectedMCOption == opt ? .medium : .regular)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .background(selectedMCOption == opt ? Color.aeroNavy.opacity(0.10) : Color.aeroSecondaryBackground)
                            .clipShape(.rect(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(selectedMCOption == opt ? Color.aeroNavy.opacity(0.4) : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: selectedMCOption)
                    }
                }
            }
        }
        .padding(28)
    }
}

struct BottomControls: View {
    @ObservedObject var viewModel: PracticeSessionViewModel
    let isLargeCanvas: Bool

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
                .controlSize(isLargeCanvas ? .large : .regular)
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
                .controlSize(isLargeCanvas ? .large : .regular)
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
    ProgressHeader(current: 2, total: 5, isLargeCanvas: false, streak: 3)
        .padding()
}
#endif
