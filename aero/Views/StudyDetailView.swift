import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Main View

struct StudyDetailView: View {
    @StateObject private var viewModel: StudyDetailViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0

    init(study: SDStudy) {
        _viewModel = StateObject(wrappedValue: StudyDetailViewModel(study: study))
    }

    var body: some View {
        VStack(spacing: 0) {
            StudyHeroHeader(study: viewModel.study, reviewCount: viewModel.reviewQueue.count)
            StudyTabPicker(selectedTab: $selectedTab)

            ZStack {
                AeroAppBackground()

                if viewModel.isLoading && viewModel.resources.isEmpty && viewModel.flashcards.isEmpty {
                    ProgressView().frame(maxHeight: .infinity)
                } else {
                    TabView(selection: $selectedTab) {
                        ResourcesTab(viewModel: viewModel).tag(0)
                        FlashcardsTab(viewModel: viewModel).tag(1)
                        ProgressTab(viewModel: viewModel).tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTab == 0 {
                    Button {
                        viewModel.showingAddResource = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                } else if selectedTab == 1 {
                    Menu {
                        Button {
                            viewModel.showingGenerateFlashcards = true
                        } label: {
                            Label("Generar con IA", systemImage: "wand.and.stars")
                        }
                        .disabled(viewModel.resources.isEmpty)

                        Button {
                            viewModel.showingCreateFlashcardManual = true
                        } label: {
                            Label("Crear manualmente", systemImage: "pencil.and.list.clipboard")
                        }
                        .disabled(viewModel.resources.isEmpty)
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                } else {
                    EmptyView()
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddResource) {
            AddResourceView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingGenerateFlashcards) {
            GenerateFlashcardsSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingCreateFlashcardManual) {
            CreateFlashcardManualView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.fetchContent()
        }
    }
}

// MARK: - Hero Header

struct StudyHeroHeader: View {
    let study: SDStudy
    let reviewCount: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(red: 0.28, green: 0.22, blue: 0.92), Color(red: 0.52, green: 0.28, blue: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 8) {
                Text(study.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(study.desc)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)

                if reviewCount > 0 {
                    NavigationLink(destination: PracticeSessionView(study: study)) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill").font(.caption)
                            Text("Practicar · \(reviewCount) tarjeta\(reviewCount == 1 ? "" : "s")")
                                .fontWeight(.semibold)
                                .font(.subheadline)
                        }
                        .foregroundColor(Color(red: 0.28, green: 0.22, blue: 0.92))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.white)
                        .cornerRadius(20)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: reviewCount > 0 ? 178 : 128)
    }
}

// MARK: - Custom Tab Picker

struct StudyTabPicker: View {
    @Binding var selectedTab: Int

    private let tabs: [(String, String)] = [
        ("Recursos", "doc.text"),
        ("Flashcards", "rectangle.stack"),
        ("Progreso", "chart.bar")
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs.indices, id: \.self) { idx in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                        selectedTab = idx
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tabs[idx].1).font(.caption)
                        Text(tabs[idx].0)
                            .font(.subheadline)
                            .fontWeight(selectedTab == idx ? .semibold : .regular)
                    }
                    .foregroundColor(selectedTab == idx ? .white : .secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(selectedTab == idx ? Color.indigo : Color.clear)
                    )
                }
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Resources Tab

struct ResourcesTab: View {
    @ObservedObject var viewModel: StudyDetailViewModel

    var body: some View {
        if viewModel.resources.isEmpty {
            ContentUnavailableView(
                "Sin recursos todavía",
                systemImage: "doc.badge.plus",
                description: Text("Agrega apuntes o PDFs para que la IA genere flashcards automáticamente.")
            )
            .overlay(alignment: .bottom) {
                Button {
                    viewModel.showingAddResource = true
                } label: {
                    Label("Agregar recurso", systemImage: "plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(AeroPrimaryButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 34)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.resources) { resource in
                        NavigationLink {
                            ResourceDetailView(studyViewModel: viewModel, resource: resource)
                        } label: {
                            ResourceCardView(resource: resource)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
}

struct ResourceCardView: View {
    let resource: SDResource

    var body: some View {
        AeroSurfaceCard {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.indigo.opacity(0.1))
                        .frame(width: 46, height: 46)
                    Image(systemName: resource.sourceName?.lowercased().hasSuffix(".pdf") == true
                          ? "doc.richtext" : "doc.text")
                        .font(.title3)
                        .foregroundStyle(.indigo)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(resource.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if let src = resource.sourceName {
                        Label(src, systemImage: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.indigo)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Flashcards Tab

struct FlashcardsTab: View {
    @ObservedObject var viewModel: StudyDetailViewModel

    var body: some View {
        if viewModel.flashcards.isEmpty {
            ContentUnavailableView(
                "Sin flashcards todavía",
                systemImage: "rectangle.stack.badge.plus",
                description: Text("Genera tarjetas con IA a partir de tus recursos o crea una manualmente.")
            )
            .overlay(alignment: .bottom) {
                HStack(spacing: 12) {
                    Button {
                        viewModel.showingGenerateFlashcards = true
                    } label: {
                        Label("Con IA", systemImage: "wand.and.stars")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(AeroPrimaryButtonStyle(disabled: viewModel.resources.isEmpty))
                    .disabled(viewModel.resources.isEmpty)

                    Button {
                        viewModel.showingCreateFlashcardManual = true
                    } label: {
                        Label("Manual", systemImage: "pencil")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo.opacity(0.75))
                    .disabled(viewModel.resources.isEmpty)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.flashcards) { card in
                        FlashcardItemView(card: card)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
}

struct FlashcardItemView: View {
    let card: SDFlashcard
    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { isExpanded.toggle() }
        } label: {
            AeroSurfaceCard {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(card.type == .open ? Color.indigo : Color.purple)
                        .frame(width: 3)
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(card.type == .open ? "Abierta" : "Opción múltiple")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(card.type == .open ? .indigo : .purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background((card.type == .open ? Color.indigo : Color.purple).opacity(0.1))
                                .clipShape(.rect(cornerRadius: 6))

                            Spacer()

                            if card.intervalDays > 0 {
                                Label("en \(card.intervalDays)d", systemImage: "clock")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(card.question)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(isExpanded ? nil : 2)

                        if isExpanded {
                            Divider().padding(.vertical, 2)

                            Text(card.answer)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if !card.conceptTags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(card.conceptTags, id: \.self) { tag in
                                            Text("#\(tag)")
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Color.teal.opacity(0.1))
                                                .foregroundStyle(.teal)
                                                .clipShape(.rect(cornerRadius: 6))
                                        }
                                    }
                                }
                                .padding(.top, 2)
                            }
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress Tab

struct ProgressTab: View {
    @ObservedObject var viewModel: StudyDetailViewModel

    var body: some View {
        if let gaps = viewModel.gapAnalysis {
            let allAttempts = viewModel.flashcards.flatMap(\.attempts)
            let totalAtt = allAttempts.count
            let correctAtt = allAttempts.filter(\.isCorrect).count
            let acc = totalAtt > 0 ? min(1, max(0, Double(correctAtt) / Double(totalAtt))) : 0.0
            ScrollView {
                VStack(spacing: 14) {
                    // Accuracy card
                    AeroSurfaceCard {
                        HStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 10)
                                    .frame(width: 90, height: 90)
                                Circle()
                                    .trim(from: 0, to: CGFloat(acc))
                                    .stroke(
                                        LinearGradient(colors: [.indigo, .teal],
                                                       startPoint: .leading, endPoint: .trailing),
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                    )
                                    .frame(width: 90, height: 90)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeOut(duration: 0.8), value: acc)
                                Text("\(Int(acc * 100))%")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Precisión general")
                                    .font(.headline)
                                StatRow(label: "Total", value: "\(totalAtt)")
                                StatRow(label: "Aciertos", value: "\(correctAtt)", color: .green)
                                StatRow(label: "Errores", value: "\(totalAtt - correctAtt)", color: .red)
                            }
                            Spacer()
                        }
                    }

                    if !gaps.gaps.isEmpty {
                        ProgressSectionHeader(title: "Conceptos débiles",
                                              systemImage: "exclamationmark.triangle.fill",
                                              color: .orange)
                        ForEach(gaps.gaps) { gap in
                            GapCardView(gap: gap)
                        }
                    }

                    if !gaps.strongConcepts.isEmpty {
                        ProgressSectionHeader(title: "Conceptos fuertes",
                                              systemImage: "checkmark.seal.fill",
                                              color: .green)
                        ForEach(gaps.strongConcepts) { concept in
                            StrongConceptCardView(concept: concept)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text("Analizando tu progreso...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxHeight: .infinity)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption).fontWeight(.semibold).foregroundColor(color)
        }
    }
}

struct ProgressSectionHeader: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).foregroundColor(color)
            Text(title).font(.headline)
            Spacer()
        }
    }
}

struct GapCardView: View {
    let gap: ConceptGap

    var body: some View {
        AeroSurfaceCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.orange.opacity(0.12)).frame(width: 44, height: 44)
                    Text("\(Int(gap.error_rate * 100))%")
                        .font(.caption).fontWeight(.bold).foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(gap.concept).font(.subheadline).fontWeight(.medium)
                    Text("\(gap.errors) errores de \(gap.total_attempts) intentos · \(gap.trend)")
                        .font(.caption2).foregroundStyle(.secondary)
                    if let det = gap.dominant_error_type {
                        Text("Error principal: \(det.rawValue)")
                            .font(.caption2).foregroundStyle(.orange.opacity(0.8))
                    }
                }
                Spacer()
            }
        }
    }
}

struct StrongConceptCardView: View {
    let concept: StrongConcept

    var body: some View {
        AeroSurfaceCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: "checkmark").font(.subheadline).fontWeight(.bold).foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(concept.concept).font(.subheadline).fontWeight(.medium)
                    Text("\(concept.total_attempts) intentos · \(Int(concept.error_rate * 100))% error")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Add Resource View

struct AddResourceView: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showFileImporter = false
    @State private var isExtracting = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Nuevo recurso")) {
                    TextField("Título", text: $viewModel.resourceTitle)
                    ZStack(alignment: .topLeading) {
                        if viewModel.resourceContent.isEmpty {
                            Text("Escribe tus notas aquí o pega el contenido extraído de un PDF...")
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $viewModel.resourceContent)
                            .frame(minHeight: 200)
                    }
                }

                Section {
                    Button {
                        showFileImporter = true
                    } label: {
                        if isExtracting {
                            ProgressView()
                        } else {
                            Label("Importar PDF o imagen (OCR)", systemImage: "doc.viewfinder")
                        }
                    }
                    .disabled(isExtracting)
                } footer: {
                    Text("El texto se extrae en el dispositivo con PDFKit o Vision; el servidor solo recibe texto plano.")
                        .font(.caption2)
                }

                if let importError {
                    Section {
                        Text(importError).font(.caption).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Agregar recurso")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleImport(result) }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        viewModel.createResource()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(viewModel.resourceTitle.isEmpty || viewModel.resourceContent.isEmpty)
                }
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) async {
        importError = nil
        switch result {
        case .failure(let err):
            importError = err.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            isExtracting = true
            do {
                let text = try await DocumentTextExtractor.extractText(from: url)
                await MainActor.run {
                    viewModel.resourceContent = text
                    viewModel.resourceSourceName = url.lastPathComponent
                    if viewModel.resourceTitle.count < 3 {
                        viewModel.resourceTitle = url.deletingPathExtension().lastPathComponent
                    }
                }
            } catch {
                await MainActor.run { importError = error.localizedDescription }
            }
            await MainActor.run { isExtracting = false }
        }
    }
}

// MARK: - Create Flashcard Manually

struct CreateFlashcardManualView: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    @Environment(\.dismiss) var dismiss

    @State private var question = ""
    @State private var answer = ""
    @State private var tagsText = ""
    @State private var cardType: FlashcardType = .open
    @State private var selectedResourceId: UUID?
    @State private var distractor1 = ""
    @State private var distractor2 = ""
    @State private var distractor3 = ""
    @State private var isSaving = false

    private var effectiveResourceId: UUID? {
        selectedResourceId ?? viewModel.resources.first?.id
    }

    private var canSave: Bool {
        !question.trimmingCharacters(in: .whitespaces).isEmpty &&
        !answer.trimmingCharacters(in: .whitespaces).isEmpty &&
        effectiveResourceId != nil &&
        (cardType == .open || !distractor1.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if viewModel.resources.isEmpty {
                        Label("Primero agrega un recurso al estudio.", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                    } else if viewModel.resources.count == 1 {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.indigo)
                            Text(viewModel.resources[0].title)
                        }
                    } else {
                        Picker("Recurso", selection: Binding(
                            get: { effectiveResourceId ?? UUID() },
                            set: { selectedResourceId = $0 }
                        )) {
                            ForEach(viewModel.resources) { r in
                                Text(r.title).tag(r.id)
                            }
                        }
                    }
                } header: {
                    Text("Recurso asociado")
                }

                Section {
                    Picker("Tipo", selection: $cardType) {
                        Text("Respuesta abierta").tag(FlashcardType.open)
                        Text("Opción múltiple").tag(FlashcardType.multipleChoice)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Tipo de tarjeta")
                }

                Section {
                    TextEditor(text: $question)
                        .frame(minHeight: 80)
                } header: {
                    Text("Pregunta")
                }

                Section {
                    TextEditor(text: $answer)
                        .frame(minHeight: 60)
                } header: {
                    Text("Respuesta correcta")
                }

                if cardType == .multipleChoice {
                    Section {
                        TextField("Distractor 1 (obligatorio)", text: $distractor1)
                        TextField("Distractor 2", text: $distractor2)
                        TextField("Distractor 3", text: $distractor3)
                    } header: {
                        Text("Respuestas incorrectas")
                    } footer: {
                        Text("Al menos un distractor es obligatorio para opción múltiple.")
                    }
                }

                Section {
                    TextField("fotosíntesis, cloroplasto, ...", text: $tagsText)
                } header: {
                    Text("Etiquetas de concepto")
                } footer: {
                    Text("Opcional. Separa los conceptos con comas.")
                }
            }
            .navigationTitle("Nueva Flashcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Guardar").fontWeight(.bold)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .onAppear {
                if selectedResourceId == nil {
                    selectedResourceId = viewModel.resources.first?.id
                }
            }
        }
    }

    private func save() {
        guard let resourceId = effectiveResourceId else { return }
        isSaving = true

        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var options: FlashcardOptions?
        if cardType == .multipleChoice {
            let distractors = [distractor1, distractor2, distractor3]
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            options = FlashcardOptions(correct: answer.trimmingCharacters(in: .whitespaces),
                                       distractors: distractors)
        }

        let success = viewModel.createFlashcardManually(
            question: question.trimmingCharacters(in: .whitespaces),
            answer: answer.trimmingCharacters(in: .whitespaces),
            tags: tags,
            resourceId: resourceId,
            type: cardType,
            options: options
        )

        isSaving = false
        if success { dismiss() }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Estudio — detalle") {
    let study = SDStudy(title: "Biología Celular", desc: "Apuntes del parcial 2")
    return NavigationStack {
        StudyDetailView(study: study)
    }
    .modelContainer(for: [SDStudy.self, SDResource.self, SDFlashcard.self, SDAttempt.self], inMemory: true)
}
#endif
