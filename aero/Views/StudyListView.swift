import SwiftUI
import SwiftData

struct StudyListView: View {
    @StateObject private var viewModel = StudyListViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var contentWidth: CGFloat {
        isLargeCanvas ? AeroAdaptiveLayout.maxRegularContentWidth : AeroAdaptiveLayout.maxCompactContentWidth
    }

    private var studyGrid: [GridItem] {
        if isLargeCanvas {
            return [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        }
        return [GridItem(.flexible())]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AeroAppBackground()

                if viewModel.isLoading && viewModel.rows.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.2)
                        Text("Cargando estudios...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.rows.isEmpty {
                    EmptyStudiesView { viewModel.showingCreateStudy = true }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            StudyStatsBanner(count: viewModel.rows.count, isLargeCanvas: isLargeCanvas)
                                .padding(.horizontal, isLargeCanvas ? 24 : 16)
                                .padding(.top, 8)
                                .padding(.bottom, 16)

                            LazyVGrid(columns: studyGrid, spacing: 12) {
                                ForEach(viewModel.rows) { row in
                                    NavigationLink(destination: StudyDetailView(study: row.study)) {
                                        StudyCardView(row: row, isLargeCanvas: isLargeCanvas)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            viewModel.deleteStudy(id: row.study.id)
                                        } label: {
                                            Label("Eliminar estudio", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            viewModel.deleteStudy(id: row.study.id)
                                        } label: {
                                            Label("Eliminar", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, isLargeCanvas ? 24 : 16)
                            .padding(.bottom, 30)
                        }
                        .frame(maxWidth: contentWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
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
                            .foregroundStyle(.indigo)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCreateStudy) {
                CreateStudyView(viewModel: viewModel)
            }
            .onChange(of: viewModel.showingCreateStudy) { _, isPresented in
                if !isPresented { viewModel.fetchStudies() }
            }
            .onAppear {
                viewModel.modelContext = modelContext
                viewModel.fetchStudies()
            }
        }
    }
}

// MARK: - Stats Banner

struct StudyStatsBanner: View {
    let count: Int
    let isLargeCanvas: Bool

    var body: some View {
        AeroSurfaceCard {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("¡A estudiar!")
                        .font(isLargeCanvas ? .title3 : .headline)
                        .fontWeight(.bold)
                    Text("\(count) tema\(count == 1 ? "" : "s") activo\(count == 1 ? "" : "s")")
                        .font(isLargeCanvas ? .body : .subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.indigo.opacity(0.18), Color.purple.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 54, height: 54)
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.indigo)
                }
            }
        }
    }
}

// MARK: - Study Card

struct StudyCardView: View {
    let row: StudyRowModel
    let isLargeCanvas: Bool

    var body: some View {
        AeroSurfaceCard {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        colors: [Color.indigo, Color.purple],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 4)
                    .padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(row.study.title)
                            .font(isLargeCanvas ? .title3 : .headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(row.study.desc)
                        .font(isLargeCanvas ? .body : .subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if let acc = row.accuracy {
                        let tint: Color = acc >= 0.7 ? .green : acc >= 0.4 ? .orange : .red
                        ProgressView(value: acc) {
                            HStack {
                                Text("Precisión")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(acc * 100))%")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(tint)
                            }
                        }
                        .tint(tint)
                    }

                    HStack(spacing: 8) {
                        if row.pendingReviewCount > 0 {
                            Label(
                                "\(row.pendingReviewCount) pendiente\(row.pendingReviewCount == 1 ? "" : "s")",
                                systemImage: "rectangle.stack.fill"
                            )
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.12))
                            .foregroundStyle(.orange)
                            .cornerRadius(8)
                        } else {
                            Label("Al día", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .foregroundStyle(.green)
                                .cornerRadius(8)
                        }

                        Spacer()

                        if let last = row.lastPractice {
                            Text(last.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(row.study.createdAt.formatted(.dateTime.day().month().year()))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }
}

// MARK: - Empty State

struct EmptyStudiesView: View {
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var contentWidth: CGFloat {
        isLargeCanvas ? AeroAdaptiveLayout.maxRegularContentWidth : AeroAdaptiveLayout.maxCompactContentWidth
    }

    var body: some View {
        AeroSurfaceCard {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.indigo.opacity(0.1), Color.purple.opacity(0.07)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)
                    Image(systemName: "books.vertical")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(colors: [.indigo, .purple],
                                           startPoint: .top, endPoint: .bottom)
                        )
                }

                VStack(spacing: 8) {
                    Text("Empieza tu primer estudio")
                        .font(isLargeCanvas ? .title2 : .title3)
                        .fontWeight(.bold)
                    Text("Crea un tema, agrega recursos y deja que\nla IA genere tus flashcards.")
                        .font(isLargeCanvas ? .body : .subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: action) {
                    Label("Crear primer estudio", systemImage: "plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(AeroPrimaryButtonStyle())
            }
        }
        .frame(maxWidth: contentWidth)
        .padding(.horizontal, isLargeCanvas ? 24 : 40)
        .padding(.vertical, 20)
    }
}

// MARK: - Create Study Sheet

struct CreateStudyView: View {
    @ObservedObject var viewModel: StudyListViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var contentWidth: CGFloat {
        isLargeCanvas ? AeroAdaptiveLayout.maxRegularContentWidth : AeroAdaptiveLayout.maxCompactContentWidth
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.28, green: 0.22, blue: 0.92),
                                 Color(red: 0.52, green: 0.28, blue: 0.96)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 8) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.white)
                        Text("Nuevo Estudio")
                            .font(isLargeCanvas ? .title2 : .title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("Dale un nombre y descripción a tu tema.")
                            .font(isLargeCanvas ? .body : .caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.vertical, isLargeCanvas ? 34 : 28)
                }
                .frame(maxWidth: .infinity)

                Form {
                    Section {
                        TextField("Título (ej: Biología Celular)", text: $viewModel.newStudyTitle)
                        ZStack(alignment: .topLeading) {
                            if viewModel.newStudyDescription.isEmpty {
                                Text("Describe el tema de estudio...")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                            TextEditor(text: $viewModel.newStudyDescription)
                                .frame(minHeight: 100)
                        }
                    } header: {
                        Text("Información del estudio")
                    }
                }
                .frame(maxWidth: contentWidth)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if viewModel.createStudy() { dismiss() }
                    } label: {
                        Text("Crear").fontWeight(.bold)
                    }
                    .disabled(viewModel.newStudyTitle.isEmpty || viewModel.newStudyDescription.isEmpty)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Lista estudios") {
    StudyListView()
        .modelContainer(for: [SDStudy.self, SDResource.self, SDFlashcard.self, SDAttempt.self], inMemory: true)
}

#Preview("Banner stats") {
    StudyStatsBanner(count: 5, isLargeCanvas: false).padding()
}

#Preview("Estudios vacíos") {
    EmptyStudiesView(action: {}).padding()
}
