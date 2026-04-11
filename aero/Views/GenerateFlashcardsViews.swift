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
        Color.aeroGroupedBackground.ignoresSafeArea()
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
                .foregroundStyle(isSelected ? Color.aeroNavy : Color.secondary)
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
                .tint(Color.aeroNavy)
                .controlSize(isLargeCanvas ? .large : .regular)
        }
        .padding(.vertical, isLargeCanvas ? 10 : 6)
        .padding(.horizontal, isLargeCanvas ? 14 : 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.aeroNavy.opacity(0.08) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isSelected ? Color.aeroNavy.opacity(0.22) : Color.white.opacity(0.12), lineWidth: 1)
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
                            colors: [Color.aeroNavy.opacity(0.15), Color.aeroLavender.opacity(0.05), .clear],
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
                            colors: [Color.aeroNavy, Color.aeroLavender, Color.aeroNavy],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                Image(systemName: iconName)
                    .font(.system(size: 34))
                    .foregroundStyle(
                        Color.aeroNavy
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
                                Color.aeroNavy
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

// Card type filter for exam generation
private enum ExamCardType: String, CaseIterable, Identifiable {
    case mixed = "Mixto"
    case open = "Abiertas"
    case multipleChoice = "Opción múltiple"
    var id: String { rawValue }
}

struct GenerateFlashcardsSheet: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedIds: Set<UUID> = []
    @State private var depth: IntelligentStudyAssistant.Depth = .medium
    @State private var cardTypeFilter: ExamCardType = .mixed
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
                                            Color.aeroNavy
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
                                    Picker("Cantidad", selection: $depth) {
                                        Text("8").tag(IntelligentStudyAssistant.Depth.low)
                                        Text("16").tag(IntelligentStudyAssistant.Depth.medium)
                                        Text("24").tag(IntelligentStudyAssistant.Depth.high)
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
                        SectionHeader("Cantidad de preguntas", systemImage: "number.circle", typeScale: typeScale) { EmptyView() }
                    } footer: {
                        Text(depth == .low ? "Mínimo 8 preguntas." : (depth == .medium ? "Mínimo 16 preguntas." : "Mínimo 24 preguntas."))
                            .font(typeScale.secondary)
                    }

                    Section {
                        AeroCard(isLargeCanvas: isLargeCanvas) {
                            VStack(alignment: .leading, spacing: 10) {
                                Picker("Tipo de preguntas", selection: $cardTypeFilter) {
                                    ForEach(ExamCardType.allCases) { t in
                                        Text(t.rawValue).tag(t)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .controlSize(isLargeCanvas ? .large : .regular)
                                Text(cardTypeFilter == .mixed
                                     ? "Mezcla de preguntas abiertas y opción múltiple."
                                     : cardTypeFilter == .open
                                       ? "Solo preguntas abiertas, evaluadas por IA."
                                       : "Solo opción múltiple con 4 opciones para elegir.")
                                    .font(typeScale.secondary).foregroundStyle(.secondary)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    } header: {
                        SectionHeader("Tipo de preguntas", systemImage: "square.grid.2x2.fill", typeScale: typeScale) { EmptyView() }
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
                                description: Text("Añade al menos un recurso con texto para generar el examen.")
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
                                Text(isGenerating ? "Generando…" : "Generar examen simulado")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(canGenerate ? AnyShapeStyle(Color.aeroNavy) : AnyShapeStyle(Color.gray.opacity(0.25)))
                            )
                            .foregroundStyle(canGenerate ? .white : .secondary)
                            .shadow(color: canGenerate ? Color.aeroNavy.opacity(0.30) : .clear, radius: 16, y: 8)
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
            .navigationTitle("Generar examen simulado")
            .toolbarColorScheme(.light, for: .navigationBar)
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

            // Filter by card type preference
            let filtered: [EditableFlashcard]
            switch cardTypeFilter {
            case .open:
                filtered = result.filter { $0.type == .open }
            case .multipleChoice:
                filtered = result.filter { $0.type == .multipleChoice }
            case .mixed:
                filtered = result
            }
            isGenerating = false

            if filtered.isEmpty && cardTypeFilter != .mixed {
                generationError = "La IA no generó suficientes preguntas de tipo '\(cardTypeFilter.rawValue)'. Prueba con 'Mixto' o agrega más texto al recurso."
            } else if result.isEmpty {
                generationError = "No se generó ninguna tarjeta. Prueba añadiendo más texto al recurso."
            } else {
                drafts = filtered.isEmpty ? result : filtered
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
                                            Color.aeroNavy
                                        )
                                        .symbolRenderingMode(.hierarchical)
                                        .accessibilityHidden(true)
                                    Text(card.type == .open ? "Abierta" : "Opción múltiple")
                                        .font(typeScale.sectionHeader)
                                    Spacer()
                                    Toggle("Incluir", isOn: $card.isIncluded)
                                        .labelsHidden()
                                        .tint(Color.aeroNavy)
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

    // Bindings into options for multipleChoice
    private var correctBinding: Binding<String> {
        Binding(
            get: { card.options?.correct ?? card.answer },
            set: { val in
                if card.options != nil {
                    card.options = FlashcardOptions(correct: val, distractors: card.options?.distractors ?? [])
                } else {
                    card.answer = val
                }
            }
        )
    }
    private func distractorBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { card.options?.distractors.count ?? 0 > index ? card.options!.distractors[index] : "" },
            set: { val in
                var dist = card.options?.distractors ?? ["", "", ""]
                while dist.count <= index { dist.append("") }
                dist[index] = val
                card.options = FlashcardOptions(correct: card.options?.correct ?? card.answer, distractors: dist)
            }
        )
    }

    var body: some View {
        Group {
            if card.type == .multipleChoice {
                multipleChoiceFields
            } else {
                openFields
            }
        }
    }

    // MARK: Open question fields
    @ViewBuilder private var openFields: some View {
        if isLargeCanvas {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pregunta").font(typeScale.editorLabel).foregroundStyle(.secondary)
                    TextField("Pregunta", text: $card.question, axis: .vertical).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Respuesta").font(typeScale.editorLabel).foregroundStyle(.secondary)
                    TextField("Respuesta", text: $card.answer, axis: .vertical).textFieldStyle(.roundedBorder)
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill").font(.caption).foregroundStyle(Color.aeroNavy)
                        Text("Etiquetas").font(typeScale.editorLabel).foregroundStyle(Color.aeroNavy)
                    }
                    TextField("ej: fotosíntesis, célula", text: tagsBinding)
                        .textFieldStyle(.roundedBorder).font(.caption)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Pregunta", text: $card.question, axis: .vertical).textFieldStyle(.roundedBorder)
                TextField("Respuesta", text: $card.answer, axis: .vertical).textFieldStyle(.roundedBorder)
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill").font(.caption).foregroundStyle(Color.aeroNavy)
                    Text("Etiquetas").font(typeScale.editorLabel).foregroundStyle(Color.aeroNavy)
                }
                TextField("ej: fotosíntesis, célula", text: tagsBinding)
                    .textFieldStyle(.roundedBorder).font(.caption)
            }
        }
    }

    // MARK: Multiple choice fields
    @ViewBuilder private var multipleChoiceFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pregunta").font(typeScale.editorLabel).foregroundStyle(.secondary)
            TextField("Pregunta", text: $card.question, axis: .vertical).textFieldStyle(.roundedBorder)

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                Text("Respuesta correcta").font(typeScale.editorLabel).foregroundStyle(.secondary)
            }
            TextField("Opción correcta", text: correctBinding, axis: .vertical).textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red.opacity(0.7)).font(.caption)
                Text("Distractores (opciones incorrectas)").font(typeScale.editorLabel).foregroundStyle(.secondary)
            }
            TextField("Distractor A", text: distractorBinding(0)).textFieldStyle(.roundedBorder)
            TextField("Distractor B", text: distractorBinding(1)).textFieldStyle(.roundedBorder)
            TextField("Distractor C", text: distractorBinding(2)).textFieldStyle(.roundedBorder)

            HStack(spacing: 6) {
                Image(systemName: "tag.fill").font(.caption).foregroundStyle(Color.aeroNavy)
                Text("Etiquetas").font(typeScale.editorLabel).foregroundStyle(Color.aeroNavy)
            }
            TextField("ej: fotosíntesis, célula", text: tagsBinding)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
        }
    }

    private var tagsBinding: Binding<String> {
        Binding(
            get: { card.conceptTags.joined(separator: ", ") },
            set: { card.conceptTags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        )
    }
}

// MARK: - Generate Anki Cards Sheet

struct GenerateAnkiCardsSheet: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedIds: Set<UUID> = []
    @State private var depth: IntelligentStudyAssistant.Depth = .medium
    @State private var drafts: [EditableAnkiCard] = []
    @State private var navigateReview = false
    @State private var isGenerating = false
    @State private var generationError: String?
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
    private var maxContentWidth: CGFloat { isLargeCanvas ? AeroLayout.maxContentWidthRegular : AeroLayout.maxContentWidthCompact }
    private var resourcePreviewLength: Int { isLargeCanvas ? 200 : 120 }

    var body: some View {
        NavigationStack {
            ZStack {
                AeroBackground()

                List {
                    Section {
                        AeroCard(isLargeCanvas: isLargeCanvas) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "rectangle.on.rectangle.angled")
                                    .font(typeScale.sectionHeader)
                                    .foregroundStyle(Color.aeroNavy)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Flashcards estilo Anki")
                                        .font(typeScale.sectionHeader)
                                    Text("Tarjetas frente/dorso para memorizar con el algoritmo SM-2 de repetición espaciada. Distintas al examen simulado.")
                                        .font(typeScale.secondary)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)

                        AeroCard(isLargeCanvas: isLargeCanvas) {
                            if IntelligentStudyAssistant.isAppleIntelligenceReady {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: "apple.intelligence")
                                        .font(typeScale.sectionHeader)
                                        .foregroundStyle(Color.aeroNavy)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Apple Intelligence activa")
                                            .font(typeScale.sectionHeader)
                                        Text("Generación on-device privada.")
                                            .font(typeScale.secondary)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 8)
                                    Text("OK")
                                        .font(typeScale.pill)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(Color.green.opacity(0.14), in: Capsule())
                                        .foregroundStyle(.green)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    let reason = IntelligentStudyAssistant.unavailabilityReason
                                    if reason == .modelNotReady {
                                        Label("Modelo descargándose…", systemImage: "arrow.down.circle")
                                            .font(typeScale.sectionHeader).foregroundStyle(.orange)
                                        Text("Espera a que termine la descarga del modelo.")
                                            .font(typeScale.secondary).foregroundStyle(.secondary)
                                    } else {
                                        Label("Apple Intelligence no disponible", systemImage: "exclamationmark.triangle.fill")
                                            .font(typeScale.sectionHeader).foregroundStyle(.red)
                                        Text(IntelligentStudyAssistant.unavailabilityReasonDescription())
                                            .font(typeScale.secondary).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                    } header: {
                        SectionHeader("Tipo y motor", systemImage: "cpu", typeScale: typeScale) { EmptyView() }
                    }

                    Section {
                        AeroCard(isLargeCanvas: isLargeCanvas) {
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(typeScale.sectionHeader).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 6) {
                                    Picker("Cantidad", selection: $depth) {
                                        Text("8").tag(IntelligentStudyAssistant.Depth.low)
                                        Text("16").tag(IntelligentStudyAssistant.Depth.medium)
                                        Text("24").tag(IntelligentStudyAssistant.Depth.high)
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
                        SectionHeader("Número de flashcards", systemImage: "rectangle.on.rectangle.angled", typeScale: typeScale) { EmptyView() }
                    } footer: {
                        Text(depth == .low ? "Mínimo 8 tarjetas." : depth == .medium ? "Mínimo 16 tarjetas." : "Mínimo 24 tarjetas.")
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
                        Text("La IA extraerá los conceptos clave y creará tarjetas atómicas frente/dorso.")
                            .font(typeScale.secondary)
                    }

                    if let generationError {
                        Section {
                            AeroCard(isLargeCanvas: isLargeCanvas) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "xmark.octagon.fill").foregroundStyle(.red).font(typeScale.sectionHeader)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("No se pudo generar").font(typeScale.sectionHeader)
                                        Text(generationError).font(typeScale.secondary).foregroundStyle(.secondary)
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
                    VStack(spacing: 10) {
                        Button {
                            Task { await runAnkiGeneration() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: canGenerate ? "rectangle.on.rectangle.angled" : "sparkles.slash")
                                    .symbolRenderingMode(.hierarchical)
                                Text(isGenerating ? "Generando…" : "Generar flashcards")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(canGenerate
                                          ? AnyShapeStyle(Color.aeroNavy)
                                          : AnyShapeStyle(Color.gray.opacity(0.25)))
                            )
                            .foregroundStyle(canGenerate ? .white : .secondary)
                            .shadow(color: canGenerate ? Color.aeroNavy.opacity(0.30) : .clear, radius: 16, y: 8)
                        }
                        .disabled(!canGenerate)
                        .controlSize(isLargeCanvas ? .large : .regular)
                    }
                    .padding(.horizontal, isLargeCanvas ? 24 : 16)
                    .padding(.top, 10).padding(.bottom, 10)
                    .background(.ultraThinMaterial)
                    .frame(maxWidth: maxContentWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .allowsHitTesting(!isGenerating)
                .blur(radius: isGenerating ? 4 : 0)

                if isGenerating {
                    Color.black.opacity(0.15).ignoresSafeArea().transition(.opacity)
                    GenerationProgressOverlay(progress: generationProgress, statusText: generationStatus, typeScale: typeScale)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .navigationTitle("Generar flashcards")
            .toolbarColorScheme(.light, for: .navigationBar)
            .navigationBarTitleDisplayMode(isLargeCanvas ? .automatic : .inline)
            .onAppear { IntelligentStudyAssistant.prewarm() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.disabled(isGenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await runAnkiGeneration() } } label: {
                        Label("Generar", systemImage: "rectangle.on.rectangle.angled")
                    }
                    .disabled(!canGenerate)
                }
            }
            .navigationDestination(isPresented: $navigateReview) {
                ReviewGeneratedAnkiView(
                    viewModel: viewModel,
                    drafts: $drafts,
                    onFinish: { navigateReview = false; dismiss() }
                )
            }
        }
    }

    private func runAnkiGeneration() async {
        isGenerating = true
        generationError = nil
        generationProgress = 0.05
        generationStatus = "Analizando material..."

        let selected = viewModel.resources.filter { selectedIds.contains($0.id) }
        let payload = selected.map { (id: $0.id, title: $0.title, content: $0.content) }

        do {
            let result = try await IntelligentStudyAssistant.generateAnkiCardsFromResources(
                resources: payload,
                depth: depth,
                onProgress: { progress in
                    Task { @MainActor in
                        let total = max(1, progress.totalChunks)
                        generationProgress = CGFloat(0.05 + 0.85 * (Double(progress.completedChunks) / Double(total)))
                        if progress.completedChunks == 0 {
                            generationStatus = total > 1 ? "Generando parte 1 de \(total)..." : "Generando flashcards..."
                        } else if progress.completedChunks < total {
                            generationStatus = "Generando parte \(progress.completedChunks + 1) de \(total)..."
                        } else {
                            generationStatus = "Finalizando..."
                        }
                    }
                }
            )
            generationProgress = 1.0
            generationStatus = "¡Listo!"
            try? await Task.sleep(for: .milliseconds(500))
            drafts = result
            isGenerating = false
            if result.isEmpty {
                generationError = "No se generó ninguna tarjeta. Añade más texto al recurso."
            } else {
                navigateReview = true
            }
        } catch {
            generationError = error.localizedDescription
            isGenerating = false
        }
    }
}

// MARK: - Review Generated Anki Cards

struct ReviewGeneratedAnkiView: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    @Binding var drafts: [EditableAnkiCard]
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
    private var maxContentWidth: CGFloat { isLargeCanvas ? AeroLayout.maxContentWidthRegular : AeroLayout.maxContentWidthCompact }

    var body: some View {
        ZStack {
            AeroBackground()

            List {
                if let errorMessage {
                    Section {
                        AeroCard(isLargeCanvas: isLargeCanvas) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red).font(typeScale.sectionHeader).accessibilityHidden(true)
                                Text(errorMessage).font(typeScale.secondary).foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                }

                ForEach($drafts) { $card in
                    Section {
                        AeroCard(isLargeCanvas: isLargeCanvas) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "rectangle.on.rectangle.angled")
                                        .foregroundStyle(Color.aeroNavy)
                                        .symbolRenderingMode(.hierarchical).accessibilityHidden(true)
                                    Text("Flashcard Anki").font(typeScale.sectionHeader)
                                    Spacer()
                                    Toggle("Incluir", isOn: $card.isIncluded)
                                        .labelsHidden().tint(Color.aeroNavy)
                                        .controlSize(isLargeCanvas ? .large : .regular)
                                }

                                if isLargeCanvas {
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Frente").font(typeScale.editorLabel).foregroundStyle(.secondary)
                                            TextField("Frente", text: $card.front, axis: .vertical).textFieldStyle(.roundedBorder)
                                        }
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Dorso").font(typeScale.editorLabel).foregroundStyle(.secondary)
                                            TextField("Dorso", text: $card.back, axis: .vertical).textFieldStyle(.roundedBorder)
                                            TextField("Tags (coma)", text: Binding(
                                                get: { card.tags.joined(separator: ", ") },
                                                set: { card.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                                            )).textFieldStyle(.roundedBorder)
                                        }
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Frente").font(typeScale.editorLabel).foregroundStyle(.secondary)
                                        TextField("Frente", text: $card.front, axis: .vertical).textFieldStyle(.roundedBorder)
                                        Text("Dorso").font(typeScale.editorLabel).foregroundStyle(.secondary)
                                        TextField("Dorso", text: $card.back, axis: .vertical).textFieldStyle(.roundedBorder)
                                        TextField("Tags (coma)", text: Binding(
                                            get: { card.tags.joined(separator: ", ") },
                                            set: { card.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                                        )).textFieldStyle(.roundedBorder)
                                    }
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
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
                Button("Guardar todas") { saveBatch() }
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
        viewModel.saveAnkiCardBatch(included)
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
