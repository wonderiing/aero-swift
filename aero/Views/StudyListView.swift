import SwiftUI

struct StudyListView: View {
    @StateObject private var viewModel = StudyListViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.rows.isEmpty {
                    ProgressView("Cargando estudios...")
                } else if viewModel.rows.isEmpty {
                    EmptyStudiesView {
                        viewModel.showingCreateStudy = true
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.rows) { row in
                                NavigationLink(destination: StudyDetailView(study: row.study)) {
                                    StudyCardView(row: row)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteStudy(id: row.study.id) }
                                    } label: {
                                        Label("Eliminar estudio", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteStudy(id: row.study.id) }
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.fetchStudies()
                    }
                }
            }
            .navigationTitle("Mis Estudios")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showingCreateStudy = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            try? await AuthService.shared.logout()
                            await MainActor.run {
                                appState.isAuthenticated = false
                            }
                        }
                    } label: {
                        Image(systemName: "person.circle")
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCreateStudy) {
                CreateStudyView(viewModel: viewModel)
            }
            .onChange(of: viewModel.showingCreateStudy) { isPresented in
                if !isPresented {
                    Task { await viewModel.fetchStudies() }
                }
            }
            .task {
                await viewModel.fetchStudies()
            }
        }
    }
}

#Preview("Lista estudios") {
    StudyListView()
        .environmentObject(AppState())
}

#if DEBUG
#Preview("Tarjeta estudio") {
    StudyCardView(row: StudyRowModel(
        study: Study(
            id: UUID(),
            title: "Biología celular",
            description: "Apuntes del parcial con texto de ejemplo para el preview.",
            createdAt: Date()
        ),
        pendingReviewCount: 7,
        accuracy: 0.68,
        lastPractice: Date()
    ))
    .padding()
}
#endif

struct StudyCardView: View {
    let row: StudyRowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(row.study.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Text(row.study.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            if let acc = row.accuracy {
                ProgressView(value: acc) {
                    HStack {
                        Text("Precisión")
                            .font(.caption2)
                        Spacer()
                        Text("\(Int(acc * 100))%")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
                .tint(.blue)
            }

            HStack {
                if row.pendingReviewCount > 0 {
                    Label("\(row.pendingReviewCount) pendientes", systemImage: "rectangle.stack")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                } else {
                    Label("Al día", systemImage: "checkmark.circle")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }

                Spacer()

                if let last = row.lastPractice {
                    Text("Última sesión: \(last.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else {
                    Text(row.study.createdAt?.formatted(.dateTime.day().month().year()) ?? "Reciente")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct EmptyStudiesView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.3))

            Text("No tienes estudios todavía")
                .font(.title3)
                .fontWeight(.medium)

            Text("Crea tu primer tema de estudio para empezar a generar flashcards con IA.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: action) {
                Text("Crear primer estudio")
                    .fontWeight(.bold)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }
}

struct CreateStudyView: View {
    @ObservedObject var viewModel: StudyListViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Información del Estudio")) {
                    TextField("Título (ej: Biología Celular)", text: $viewModel.newStudyTitle)
                    ZStack(alignment: .topLeading) {
                        if viewModel.newStudyDescription.isEmpty {
                            Text("Descripción del tema...")
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $viewModel.newStudyDescription)
                            .frame(minHeight: 100)
                    }
                }
            }
            .navigationTitle("Nuevo Estudio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Crear") {
                        Task {
                            if await viewModel.createStudy() {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(viewModel.newStudyTitle.isEmpty || viewModel.newStudyDescription.isEmpty)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Crear estudio") {
    CreateStudyView(viewModel: StudyListViewModel())
}

#Preview("Estudios vacíos") {
    EmptyStudiesView(action: {})
        .padding()
}
#endif
