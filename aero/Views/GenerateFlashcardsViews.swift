import SwiftUI

struct GenerateFlashcardsSheet: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIds: Set<UUID> = []
    @State private var depth: FlashcardGenerationService.Depth = .medium
    @State private var drafts: [EditableFlashcard] = []
    @State private var navigateReview = false
    @State private var isGenerating = false
    @State private var generationNotice: String?
    @State private var generationError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if IntelligentStudyAssistant.isAppleIntelligenceReady {
                        Label("Apple Intelligence activa (on-device)", systemImage: "apple.intelligence")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Apple Intelligence no disponible", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(IntelligentStudyAssistant.unavailabilityReasonDescription())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Se usará generación básica sin modelo de lenguaje.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("IA")
                }

                Section {
                    Picker("Profundidad", selection: $depth) {
                        Text("Pocas").tag(FlashcardGenerationService.Depth.low)
                        Text("Media").tag(FlashcardGenerationService.Depth.medium)
                        Text("Muchas").tag(FlashcardGenerationService.Depth.high)
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
                                    Text(r.title)
                                        .font(.headline)
                                    Text(String(r.content.prefix(80)) + (r.content.count > 80 ? "…" : ""))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Recursos (contenido subido)")
                }

                if let generationNotice {
                    Section {
                        Text(generationNotice)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if let generationError {
                    Section {
                        Text(generationError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Generar flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await runGeneration() }
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Text("Generar con IA")
                        }
                    }
                    .disabled(selectedIds.isEmpty || isGenerating)
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
        generationNotice = nil
        let selected = viewModel.resources.filter { selectedIds.contains($0.id) }
        let payload = selected.map { (id: $0.id, title: $0.title, content: $0.content) }

        var result: [EditableFlashcard] = []
        if IntelligentStudyAssistant.isAppleIntelligenceReady {
            do {
                result = try await IntelligentStudyAssistant.generateFlashcardsFromResources(
                    resources: payload,
                    depth: depth
                )
                generationNotice = "Generadas con Foundation Models a partir de los recursos seleccionados."
            } catch {
                generationError = error.localizedDescription
                result = heuristicDrafts(payload: payload)
                if !result.isEmpty {
                    generationNotice = (generationNotice ?? "") + " Se completó con generación heurística de respaldo."
                }
            }
        } else {
            result = heuristicDrafts(payload: payload)
            generationNotice = "Generación heurística (sin Apple Intelligence)."
        }

        drafts = result
        isGenerating = false
        navigateReview = !result.isEmpty
        if result.isEmpty {
            generationError = (generationError ?? "No se pudo generar ninguna tarjeta. Añade más texto al recurso.")
        }
    }

    private func heuristicDrafts(payload: [(id: UUID, title: String, content: String)]) -> [EditableFlashcard] {
        var out: [EditableFlashcard] = []
        for item in payload {
            out.append(contentsOf: FlashcardGenerationService.generateDrafts(
                from: item.content,
                resourceId: item.id,
                depth: depth
            ))
        }
        return out
    }
}

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
                            card.conceptTags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
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
                    Task { await saveBatch() }
                }
                .disabled(isSaving)
            }
        }
    }

    private func saveBatch() async {
        isSaving = true
        errorMessage = nil
        let included = drafts.filter(\.isIncluded)
        guard !included.isEmpty else {
            errorMessage = "Incluye al menos una tarjeta."
            isSaving = false
            return
        }
        let dtos = included.map { $0.toDto() }
        do {
            try await viewModel.saveFlashcardBatch(dtos)
            onFinish()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

#if DEBUG
#Preview("Generar flashcards") {
    GenerateFlashcardsSheet(viewModel: StudyDetailViewModel.previewMock())
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
