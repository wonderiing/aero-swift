import SwiftUI
import UniformTypeIdentifiers

struct StudyDetailView: View {
    @StateObject private var viewModel: StudyDetailViewModel
    @State private var selectedTab = 0
    
    init(study: Study) {
        _viewModel = StateObject(wrappedValue: StudyDetailViewModel(study: study))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con información del estudio
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.study.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(viewModel.study.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Botón Iniciar Sesión de Repaso
                NavigationLink(destination: PracticeSessionView(studyId: viewModel.study.id)) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Iniciar sesión de repaso")
                        Spacer()
                        if !viewModel.reviewQueue.isEmpty {
                            Text("\(viewModel.reviewQueue.count)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(6)
                                .background(Color.white.opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    .background(viewModel.reviewQueue.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.reviewQueue.isEmpty)
                .padding(.top, 8)
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            
            // Picker de Tabs
            Picker("", selection: $selectedTab) {
                Text("Recursos").tag(0)
                Text("Flashcards").tag(1)
                Text("Progreso").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .background(Color(uiColor: .systemBackground))
            
            // Contenido del Tab
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.resources.isEmpty && viewModel.flashcards.isEmpty {
                    ProgressView()
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
                    Button {
                        viewModel.showingGenerateFlashcards = true
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    .disabled(viewModel.resources.isEmpty)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddResource) {
            AddResourceView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingGenerateFlashcards) {
            GenerateFlashcardsSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.fetchContent()
        }
    }
}

// MARK: - Tabs

struct ResourcesTab: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    
    var body: some View {
        if viewModel.resources.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.3))
                Text("No hay recursos todavía")
                    .foregroundColor(.secondary)
                Button("Agregar primer recurso") {
                    viewModel.showingAddResource = true
                }
                .buttonStyle(.bordered)
            }
        } else {
            List(viewModel.resources) { resource in
                NavigationLink {
                    ResourceDetailView(studyViewModel: viewModel, resource: resource)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(resource.title)
                            .font(.headline)
                        Text(resource.content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        if let src = resource.sourceName {
                            Text(src)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct FlashcardsTab: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    
    var body: some View {
        if viewModel.flashcards.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.3))
                Text("No hay flashcards generadas")
                    .foregroundColor(.secondary)
                Text("Agrega un recurso para que la IA pueda generar tus tarjetas de estudio.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        } else {
            List(viewModel.flashcards) { card in
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        ForEach(card.conceptTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        Spacer()
                        if let interval = card.intervalDays {
                            Text("Repaso en \(interval) d")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct ProgressTab: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    
    var body: some View {
        if let gaps = viewModel.gaps {
            let accValue = min(1, max(0, viewModel.attemptsSummary?.accuracy ?? 0))
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Accuracy Card
                    VStack(spacing: 12) {
                        Text("Precisión general")
                            .font(.headline)

                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                                .frame(width: 100, height: 100)

                            Circle()
                                .trim(from: 0, to: CGFloat(accValue))
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))

                            Text("\(Int(accValue * 100))%")
                                .font(.title3)
                                .fontWeight(.bold)
                        }

                        if let summary = viewModel.attemptsSummary {
                            Text("Total: \(summary.total) · Aciertos: \(summary.correct)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(gaps.total_attempts) intentos totales")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    
                    // Gaps Section
                    if !gaps.gaps.isEmpty {
                        Text("🔴 Conceptos Débiles")
                            .font(.headline)
                        
                        ForEach(gaps.gaps, id: \.concept) { gap in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(gap.concept)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(gap.errors) errores en \(gap.total_attempts) intentos · \(gap.trend)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    if let det = gap.dominant_error_type {
                                        Text("Error dominante: \(det.rawValue)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(Int(gap.error_rate * 100))% error")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(6)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Strong Concepts Section
                    if !gaps.strong_concepts.isEmpty {
                        Text("🟢 Conceptos Fuertes")
                            .font(.headline)
                        
                        ForEach(gaps.strong_concepts, id: \.concept) { strong in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(strong.concept)
                                        .font(.subheadline)
                                    Text("\(strong.total_attempts) intentos · \(Int(strong.error_rate * 100))% error")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        } else {
            VStack {
                ProgressView()
                Text("Analizando tu progreso...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

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
                        Text(importError)
                            .font(.caption)
                            .foregroundColor(.red)
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
                        Task {
                            await viewModel.createResource()
                            dismiss()
                        }
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
            defer {
                if access { url.stopAccessingSecurityScopedResource() }
            }
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
                await MainActor.run {
                    importError = error.localizedDescription
                }
            }
            await MainActor.run { isExtracting = false }
        }
    }
}

#if DEBUG
#Preview("Estudio — detalle") {
    NavigationStack {
        StudyDetailView(study: Study(
            id: UUID(),
            title: "Biología Celular",
            description: "Apuntes del parcial 2",
            createdAt: Date()
        ))
    }
}

#Preview("Agregar recurso") {
    AddResourceView(viewModel: StudyDetailViewModel.previewMock())
}

#Preview("Pestaña recursos") {
    ResourcesTab(viewModel: StudyDetailViewModel.previewMock())
}

#Preview("Pestaña flashcards") {
    FlashcardsTab(viewModel: StudyDetailViewModel.previewWithProgress())
}

#Preview("Pestaña progreso") {
    ProgressTab(viewModel: StudyDetailViewModel.previewWithProgress())
}
#endif
