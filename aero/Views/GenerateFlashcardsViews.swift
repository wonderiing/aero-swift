import SwiftUI
import FoundationModels

// MARK: - Generation Progress Overlay

struct GenerationProgressOverlay: View {
    let progress: CGFloat
    let statusText: String

    @State private var pulse = false

    private var iconName: String {
        switch progress {
        case ..<0.15: return "doc.text.magnifyingglass"
        case ..<0.45: return "brain.head.profile"
        case ..<0.75: return "list.bullet.rectangle"
        case ..<0.95: return "checkmark.shield"
        default:      return "sparkles"
        }
    }

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.indigo.opacity(0.15), .purple.opacity(0.05), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 130, height: 130)
                    .scaleEffect(pulse ? 1.12 : 0.95)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.indigo, .purple, .indigo],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                Image(systemName: iconName)
                    .font(.system(size: 34))
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo, .purple],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(spacing: 10) {
                Text(statusText)
                    .font(.headline)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: statusText)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 6)

                        Capsule()
                            .fill(
                                LinearGradient(colors: [.indigo, .purple],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: max(0, geo.size.width * progress), height: 6)
                    }
                }
                .frame(height: 6)
                .frame(maxWidth: 220)

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Generate Flashcards Sheet

struct GenerateFlashcardsSheet: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIds: Set<UUID> = []
    @State private var depth: IntelligentStudyAssistant.Depth = .medium
    @State private var drafts: [EditableFlashcard] = []
    @State private var navigateReview = false
    @State private var isGenerating = false
    @State private var generationError: String?

    // Progress state driven by real chunk callbacks
    @State private var generationProgress: CGFloat = 0
    @State private var generationStatus: String = "Preparando..."

    private var canGenerate: Bool {
        let aiOk = IntelligentStudyAssistant.isAppleIntelligenceReady
            || IntelligentStudyAssistant.unavailabilityReason == .modelNotReady
        return aiOk && !selectedIds.isEmpty && !isGenerating
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    Section {
                        if IntelligentStudyAssistant.isAppleIntelligenceReady {
                            Label("Apple Intelligence activa (on-device)", systemImage: "apple.intelligence")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                let reason = IntelligentStudyAssistant.unavailabilityReason
                                if reason == .modelNotReady {
                                    Label("Modelo descargándose...", systemImage: "arrow.down.circle")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                    Text("El modelo de Apple Intelligence se está descargando. Ve a Ajustes → Apple Intelligence y Siri y espera a que termine. Si estás en el simulador, la descarga ocurre en tu Mac host (requiere Apple Silicon).")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Label("Apple Intelligence no disponible", systemImage: "exclamationmark.triangle.fill")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                    Text(IntelligentStudyAssistant.unavailabilityReasonDescription())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Motor de IA")
                    }

                    Section {
                        Picker("Cantidad", selection: $depth) {
                            Text("Pocas (~6)").tag(IntelligentStudyAssistant.Depth.low)
                            Text("Media (~12)").tag(IntelligentStudyAssistant.Depth.medium)
                            Text("Muchas (~18)").tag(IntelligentStudyAssistant.Depth.high)
                        }
                    } header: {
                        Text("Cantidad orientativa")
                    }

                    Section {
                        if viewModel.resources.isEmpty {
                            Text("Añade al menos un recurso con texto.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(viewModel.resources) { r in
                                Toggle(isOn: Binding(
                                    get: { selectedIds.contains(r.id) },
                                    set: { on in
                                        if on { selectedIds.insert(r.id) } else { selectedIds.remove(r.id) }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(r.title).font(.headline)
                                        Text(String(r.content.prefix(80)) + (r.content.count > 80 ? "…" : ""))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Recursos")
                    }

                    if let generationError {
                        Section {
                            Text(generationError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .allowsHitTesting(!isGenerating)
                .blur(radius: isGenerating ? 4 : 0)

                // Progress overlay
                if isGenerating {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    GenerationProgressOverlay(
                        progress: generationProgress,
                        statusText: generationStatus
                    )
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isGenerating)
            .animation(.easeInOut(duration: 0.5), value: generationProgress)
            .navigationTitle("Generar flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { IntelligentStudyAssistant.prewarm() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .disabled(isGenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await runGeneration() }
                    } label: {
                        Text("Generar con IA")
                    }
                    .disabled(!canGenerate)
                }
            }
            .navigationDestination(isPresented: $navigateReview) {
                ReviewGeneratedFlashcardsView(
                    viewModel: viewModel,
                    drafts: $drafts,
                    onFinish: {
                        navigateReview = false
                        dismiss()
                    }
                )
            }
        }
    }

    private func runGeneration() async {
        isGenerating = true
        generationError = nil
        generationProgress = 0.05
        generationStatus = "Analizando material..."

        let selected = viewModel.resources.filter { selectedIds.contains($0.id) }
        let payload = selected.map { (id: $0.id, title: $0.title, content: $0.content) }

        do {
            let result = try await IntelligentStudyAssistant.generateFlashcardsFromResources(
                resources: payload,
                depth: depth,
                onProgress: { progress in
                    Task { @MainActor in
                        let total = max(1, progress.totalChunks)
                        let completed = progress.completedChunks

                        // Map chunk progress to 0.05...0.90 range
                        let realProgress = 0.05 + 0.85 * (Double(completed) / Double(total))
                        generationProgress = CGFloat(realProgress)

                        if completed == 0 {
                            generationStatus = total > 1
                                ? "Generando parte 1 de \(total)..."
                                : "Generando flashcards..."
                        } else if completed < total {
                            generationStatus = "Generando parte \(completed + 1) de \(total)..."
                        } else {
                            generationStatus = "Finalizando..."
                        }
                    }
                }
            )

            // Snap to 100%
            generationProgress = 1.0
            generationStatus = "Listo!"
            try? await Task.sleep(for: .milliseconds(500))

            drafts = result
            isGenerating = false

            if result.isEmpty {
                generationError = "No se generó ninguna tarjeta. Prueba añadiendo más texto al recurso."
            } else {
                navigateReview = true
            }
        } catch {
            generationError = error.localizedDescription
            isGenerating = false
        }
    }
}

// MARK: - Review Generated Flashcards

struct ReviewGeneratedFlashcardsView: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    @Binding var drafts: [EditableFlashcard]
    var onFinish: () -> Void

    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(.red).font(.caption)
                }
            }
            ForEach($drafts) { $card in
                Section {
                    Toggle("Incluir al guardar", isOn: $card.isIncluded)
                    TextField("Pregunta", text: $card.question, axis: .vertical)
                    TextField("Respuesta", text: $card.answer, axis: .vertical)
                    TextField("Tags (separados por coma)", text: Binding(
                        get: { card.conceptTags.joined(separator: ", ") },
                        set: {
                            card.conceptTags = $0
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
                        }
                    ))
                } header: {
                    Text(card.type == .open ? "Abierta" : "Opción múltiple")
                }
            }
            .onDelete { drafts.remove(atOffsets: $0) }
        }
        .navigationTitle("Revisar antes de guardar")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar todas") {
                    saveBatch()
                }
                .disabled(isSaving)
            }
        }
    }

    private func saveBatch() {
        isSaving = true
        errorMessage = nil
        let included = drafts.filter(\.isIncluded)
        guard !included.isEmpty else {
            errorMessage = "Incluye al menos una tarjeta."
            isSaving = false
            return
        }
        viewModel.saveFlashcardBatch(included.map { $0.toDto() })
        isSaving = false
        onFinish()
    }
}

#if DEBUG
#Preview("Generar flashcards") {
    GenerateFlashcardsSheet(viewModel: StudyDetailViewModel.previewMock())
}

#Preview("Progress overlay") {
    ZStack {
        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
        GenerationProgressOverlay(progress: 0.65, statusText: "Generando parte 2 de 3...")
    }
}

#Preview("Revisar borrador") {
    NavigationStack {
        ReviewGeneratedFlashcardsView(
            viewModel: StudyDetailViewModel.previewMock(),
            drafts: .constant([
                EditableFlashcard(
                    resourceId: UUID(),
                    question: "¿Qué es la fotosíntesis?",
                    answer: "Proceso en cloroplastos.",
                    type: .open,
                    options: nil,
                    conceptTags: ["fotosíntesis"]
                )
            ]),
            onFinish: {}
        )
    }
}
#endif
