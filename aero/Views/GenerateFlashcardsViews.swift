import SwiftUI
import FoundationModels

// MARK: - UI Building Blocks

private enum AeroLayout {
    static let maxContentWidthCompact: CGFloat = 560
    static let maxContentWidthRegular: CGFloat = 860
    static let cardCornerRadius: CGFloat = 18
}

fileprivate struct AeroTypeScale {
    let title: Font
    let sectionHeader: Font
    let body: Font
    let secondary: Font
    let pill: Font
    let editorLabel: Font

    static func make(isLargeCanvas: Bool) -> AeroTypeScale {
        if isLargeCanvas {
            return AeroTypeScale(
                title: .title2,
                sectionHeader: .title3.weight(.semibold),
                body: .body,
                secondary: .callout,
                pill: .callout.weight(.semibold),
                editorLabel: .callout.weight(.semibold)
            )
        } else {
            return AeroTypeScale(
                title: .headline,
                sectionHeader: .headline,
                body: .body,
                secondary: .caption,
                pill: .caption.weight(.semibold),
                editorLabel: .caption.weight(.semibold)
            )
        }
    }
}

private struct AeroBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.indigo.opacity(0.18),
                    Color.purple.opacity(0.10),
                    .aeroGroupedBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle glow blobs
            Circle()
                .fill(Color.indigo.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 28)
                .offset(x: -140, y: -220)

            Circle()
                .fill(Color.purple.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 32)
                .offset(x: 170, y: -140)
        }
    }
}

private struct AeroCard<Content: View>: View {
    let content: Content
    let isLargeCanvas: Bool

    init(isLargeCanvas: Bool = false, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.isLargeCanvas = isLargeCanvas
    }

    var body: some View {
        content
            .padding(.vertical, isLargeCanvas ? 14 : 10)
            .padding(.horizontal, isLargeCanvas ? 16 : 12)
            .background(
                RoundedRectangle(cornerRadius: AeroLayout.cardCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AeroLayout.cardCornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
            )
    }
}

private struct SectionHeader<Trailing: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var trailing: () -> Trailing
    let typeScale: AeroTypeScale

    init(_ title: String, systemImage: String, typeScale: AeroTypeScale, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.systemImage = systemImage
        self.typeScale = typeScale
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(typeScale.sectionHeader)
                .labelStyle(.titleAndIcon)
                .symbolRenderingMode(.hierarchical)

            Spacer(minLength: 8)

            trailing()
        }
        .textCase(nil)
        .foregroundStyle(.primary)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

private struct CountPill: View {
    let count: Int
    let typeScale: AeroTypeScale
    var body: some View {
        Text("\(count) seleccionado\(count == 1 ? "" : "s")")
            .font(typeScale.pill)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            .contentTransition(.numericText())
    }
}

private struct ResourceSelectionRow: View {
    let title: String
    let preview: String
    @Binding var isSelected: Bool
    let typeScale: AeroTypeScale
    let isLargeCanvas: Bool

    @State private var highlight = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(typeScale.sectionHeader)
                .foregroundStyle(isSelected ? Color.indigo : Color.secondary)
                .symbolRenderingMode(.hierarchical)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(typeScale.body.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.95)

                Text(preview)
                    .font(typeScale.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isSelected)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.indigo)
                .controlSize(isLargeCanvas ? .large : .regular)
        }
        .padding(.vertical, isLargeCanvas ? 10 : 6)
        .padding(.horizontal, isLargeCanvas ? 14 : 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.indigo.opacity(0.08) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isSelected ? Color.indigo.opacity(0.22) : Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .scaleEffect(highlight ? 0.985 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSelected)
        .onChange(of: isSelected) { _, newValue in
            if newValue {
                highlight = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    highlight = false
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Seleccionado" : "No seleccionado")
        .accessibilityHint("Activa el interruptor para incluir este recurso.")
    }
}

// MARK: - Generation Progress Overlay

fileprivate struct GenerationProgressOverlay: View {
    let progress: CGFloat
    let statusText: String
    let typeScale: AeroTypeScale

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
                    .font(typeScale.sectionHeader)
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
                    .font(typeScale.pill)
                    .foregroundStyle(.secondary)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

    private var isLargeCanvas: Bool {
        #if os(macOS)
        return true
        #else
        return UIDevice.current.userInterfaceIdiom == .pad || horizontalSizeClass == .regular
        #endif
    }

    private var typeScale: AeroTypeScale { .make(isLargeCanvas: isLargeCanvas) }

    private var maxContentWidth: CGFloat {
        isLargeCanvas ? AeroLayout.maxContentWidthRegular : AeroLayout.maxContentWidthCompact
    }

    private var resourcePreviewLength: Int {
        isLargeCanvas ? 200 : 120
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AeroBackground()

                List {
                    Section {
                        AeroCard(isLargeCanvas: isLargeCanvas) {
                            if IntelligentStudyAssistant.isAppleIntelligenceReady {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: "apple.intelligence")
                                        .font(typeScale.sectionHeader)
                                        .foregroundStyle(
                                            LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Apple Intelligence activa")
                                            .font(typeScale.sectionHeader)
                                        Text("Generación on-device (más rápida y privada).")
                                            .font(typeScale.secondary)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 8)
                                    Text("OK")
                                        .font(typeScale.pill)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.14), in: Capsule())
                                        .foregroundStyle(.green)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    let reason = IntelligentStudyAssistant.unavailabilityReason
                                    if reason == .modelNotReady {
                                        Label("Modelo descargándose…", systemImage: "arrow.down.circle")
                                            .font(typeScale.sectionHeader)
                                            .foregroundStyle(.orange)
                                        Text("Ve a Ajustes → Apple Intelligence y Siri y espera a que termine. En simulador, la descarga ocurre en tu Mac host (requiere Apple Silicon).")
                                            .font(typeScale.secondary)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Label("Apple Intelligence no disponible", systemImage: "exclamationmark.triangle.fill")
                                            .font(typeScale.sectionHeader)
                                            .foregroundStyle(.red)
                                        Text(IntelligentStudyAssistant.unavailabilityReasonDescription())
                                            .font(typeScale.secondary)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                    } header: {
                        SectionHeader("Motor de IA", systemImage: "cpu", typeScale: typeScale) { EmptyView() }
                    }

                    Section {
                        AeroCard(isLargeCanvas: isLargeCanvas) {
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(typeScale.sectionHeader)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Cantidad orientativa")
                                        .font(typeScale.sectionHeader)
                                    Picker("Cantidad", selection: $depth) {
                                        Text("Pocas").tag(IntelligentStudyAssistant.Depth.low)
                                        Text("Media").tag(IntelligentStudyAssistant.Depth.medium)
                                        Text("Muchas").tag(IntelligentStudyAssistant.Depth.high)
                                    }
                                    .pickerStyle(.segmented)
                                    .controlSize(isLargeCanvas ? .large : .regular)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } header: {
                        SectionHeader("Ajustes", systemImage: "gearshape", typeScale: typeScale) { EmptyView() }
                    } footer: {
                        Text(depth == .low ? "Ideal para un repaso rápido." : (depth == .medium ? "Equilibrado para estudiar." : "Más cobertura, tarda un poco más."))
                            .font(typeScale.secondary)
                    }

                    Section {
                        ForEach(viewModel.resources) { r in
                            ResourceSelectionRow(
                                title: r.title,
                                preview: String(r.content.prefix(resourcePreviewLength)) + (r.content.count > resourcePreviewLength ? "…" : ""),
                                isSelected: Binding(
                                    get: { selectedIds.contains(r.id) },
                                    set: { on in
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                            if on { selectedIds.insert(r.id) } else { selectedIds.remove(r.id) }
                                        }
                                    }
                                ),
                                typeScale: typeScale,
                                isLargeCanvas: isLargeCanvas
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        SectionHeader("Recursos", systemImage: "books.vertical", typeScale: typeScale) {
                            CountPill(count: selectedIds.count, typeScale: typeScale)
                        }
                    } footer: {
                        Text("Selecciona 1 o más recursos. Cuanto mejor sea el texto, mejores serán las tarjetas.")
                            .font(typeScale.secondary)
                    }

                    if let generationError {
                        Section {
                            AeroCard(isLargeCanvas: isLargeCanvas) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "xmark.octagon.fill")
                                        .foregroundStyle(.red)
                                        .font(typeScale.sectionHeader)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("No se pudo generar")
                                            .font(typeScale.sectionHeader)
                                        Text(generationError)
                                            .font(typeScale.secondary)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity, alignment: .center)
                .overlay {
                    if viewModel.resources.isEmpty {
                        ContentUnavailableView(
                            "Sin recursos",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Añade al menos un recurso con texto para generar flashcards.")
                        )
                        .padding(.horizontal, 24)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    // Bottom primary action (modern “sticky” CTA)
                    VStack(spacing: 10) {
                        Button {
                            Task { await runGeneration() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: canGenerate ? "sparkles" : "sparkles.slash")
                                    .symbolRenderingMode(.hierarchical)
                                Text(isGenerating ? "Generando…" : "Generar flashcards")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(depth == .low ? "~6" : (depth == .medium ? "~12" : "~18"))
                                    .font(typeScale.secondary)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(canGenerate ? AnyShapeStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.gray.opacity(0.25)))
                            )
                            .foregroundStyle(canGenerate ? .white : .secondary)
                            .shadow(color: canGenerate ? .purple.opacity(0.25) : .clear, radius: 16, y: 8)
                        }
                        .disabled(!canGenerate)
                        .controlSize(isLargeCanvas ? .large : .regular)
                    }
                    .padding(.horizontal, isLargeCanvas ? 24 : 16)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .background(.ultraThinMaterial)
                    .frame(maxWidth: maxContentWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .allowsHitTesting(!isGenerating)
                .blur(radius: isGenerating ? 4 : 0)
                .sensoryFeedback(.selection, trigger: selectedIds.count)

                // Progress overlay
                if isGenerating {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    GenerationProgressOverlay(
                        progress: generationProgress,
                        statusText: generationStatus,
                        typeScale: typeScale
                    )
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .navigationTitle("Generar flashcards")
            .navigationBarTitleDisplayMode(isLargeCanvas ? .automatic : .inline)
            .onAppear { IntelligentStudyAssistant.prewarm() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .disabled(isGenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    // Keep an accessible top action too (especially on iPad / keyboard)
                    Button {
                        Task { await runGeneration() }
                    } label: {
                        Label("Generar", systemImage: "sparkles")
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isLargeCanvas: Bool {
        #if os(macOS)
        return true
        #else
        return UIDevice.current.userInterfaceIdiom == .pad || horizontalSizeClass == .regular
        #endif
    }

    private var typeScale: AeroTypeScale { .make(isLargeCanvas: isLargeCanvas) }

    private var maxContentWidth: CGFloat {
        isLargeCanvas ? AeroLayout.maxContentWidthRegular : AeroLayout.maxContentWidthCompact
    }

    var body: some View {
        ZStack {
            AeroBackground()

            List {
                if let errorMessage {
                    Section {
                        AeroCard(isLargeCanvas: isLargeCanvas) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .font(typeScale.sectionHeader)
                                    .accessibilityHidden(true)
                                Text(errorMessage)
                                    .font(typeScale.secondary)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }

                ForEach($drafts) { $card in
                    Section {
                        AeroCard(isLargeCanvas: isLargeCanvas) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: card.type == .open ? "text.bubble" : "list.bullet.circle")
                                        .foregroundStyle(
                                            LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                        .symbolRenderingMode(.hierarchical)
                                        .accessibilityHidden(true)
                                    Text(card.type == .open ? "Abierta" : "Opción múltiple")
                                        .font(typeScale.sectionHeader)
                                    Spacer()
                                    Toggle("Incluir", isOn: $card.isIncluded)
                                        .labelsHidden()
                                        .tint(.indigo)
                                        .controlSize(isLargeCanvas ? .large : .regular)
                                }

                                FlashcardEditorFields(
                                    card: $card,
                                    typeScale: typeScale,
                                    isLargeCanvas: isLargeCanvas
                                )
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .onDelete { drafts.remove(atOffsets: $0) }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Revisar y guardar")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar todas") {
                    saveBatch()
                }
                .disabled(isSaving)
                .controlSize(isLargeCanvas ? .large : .regular)
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

private struct FlashcardEditorFields: View {
    @Binding var card: EditableFlashcard
    let typeScale: AeroTypeScale
    let isLargeCanvas: Bool

    var body: some View {
        Group {
            if isLargeCanvas {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pregunta")
                            .font(typeScale.editorLabel)
                            .foregroundStyle(.secondary)
                        TextField("Pregunta", text: $card.question, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Respuesta")
                            .font(typeScale.editorLabel)
                            .foregroundStyle(.secondary)
                        TextField("Respuesta", text: $card.answer, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                        TextField("Tags (coma)", text: Binding(
                            get: { card.conceptTags.joined(separator: ", ") },
                            set: {
                                card.conceptTags = $0
                                    .split(separator: ",")
                                    .map { $0.trimmingCharacters(in: .whitespaces) }
                                    .filter { !$0.isEmpty }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Pregunta", text: $card.question, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    TextField("Respuesta", text: $card.answer, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    TextField("Tags (coma)", text: Binding(
                        get: { card.conceptTags.joined(separator: ", ") },
                        set: {
                            card.conceptTags = $0
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Generar flashcards") {
    GenerateFlashcardsSheet(viewModel: StudyDetailViewModel.previewMock())
}

#Preview("Progress overlay") {
    ZStack {
        Color.aeroGroupedBackground.ignoresSafeArea()
        GenerationProgressOverlay(
            progress: 0.65,
            statusText: "Generando parte 2 de 3...",
            typeScale: .make(isLargeCanvas: true)
        )
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
