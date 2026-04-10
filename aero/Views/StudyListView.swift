import SwiftUI
import SwiftData

struct StudyListView: View {
    @StateObject private var viewModel = StudyListViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showSettings = false
    @AppStorage("userName") private var userName: String = ""

    private var displayName: String {
        let t = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Estudiante" : t
    }

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var contentWidth: CGFloat {
        isLargeCanvas ? AeroAdaptiveLayout.maxStudyListWidth : AeroAdaptiveLayout.maxCompactContentWidth
    }

    private var studyGrid: [GridItem] {
        AeroAdaptiveLayout.studyGridItems(horizontalSizeClass: horizontalSizeClass)
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
                        VStack(alignment: .leading, spacing: 0) {
                            StudyStatsBanner(userDisplayName: displayName, count: viewModel.rows.count, isLargeCanvas: isLargeCanvas)
                                .padding(.horizontal, isLargeCanvas ? 28 : 16)
                                .padding(.top, isLargeCanvas ? 12 : 8)
                                .padding(.bottom, isLargeCanvas ? 20 : 16)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Biblioteca")
                                    .font(AeroType.sectionOverline())
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1.1)
                                Text("Toca un tema para abrirlo. En iPad verás varias columnas según el ancho de pantalla.")
                                    .font(isLargeCanvas ? .subheadline : .caption)
                                    .foregroundStyle(.tertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, isLargeCanvas ? 28 : 16)
                            .padding(.bottom, 12)

                            LazyVGrid(columns: studyGrid, spacing: isLargeCanvas ? 18 : 12) {
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
                            .padding(.horizontal, isLargeCanvas ? 28 : 16)
                            .padding(.bottom, 36)
                        }
                        .frame(maxWidth: contentWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Estudios")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        if horizontalSizeClass == .regular {
                            Label("Ajustes", systemImage: "gearshape.fill")
                        } else {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                    .accessibilityLabel("Configuración")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showingCreateStudy = true
                    } label: {
                        if horizontalSizeClass == .regular {
                            Label("Nuevo", systemImage: "plus.circle.fill")
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                    .accessibilityLabel("Nuevo estudio")
                }
            }
            .sheet(isPresented: $viewModel.showingCreateStudy) {
                CreateStudyView(viewModel: viewModel)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: viewModel.showingCreateStudy) { _, isPresented in
                if !isPresented { viewModel.fetchStudies() }
            }
            .onAppear {
                viewModel.modelContext = modelContext
                viewModel.fetchStudies()
            }
            .tint(Color.aeroNavy)
        }
    }
}

// MARK: - Stats Banner

struct StudyStatsBanner: View {
    let userDisplayName: String
    let count: Int
    let isLargeCanvas: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var greetingInk: Color { colorScheme == .light ? Color.aeroNavy : Color.primary }

    var body: some View {
        AeroSurfaceCard {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hola, \(userDisplayName)")
                        .font(AeroType.studyGreeting(largeCanvas: isLargeCanvas))
                        .foregroundStyle(greetingInk)
                    Text("Aquí tienes un vistazo de tus temas. Sigue donde lo dejaste o crea uno nuevo.")
                        .font(AeroType.studyCardBody(largeCanvas: isLargeCanvas))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Label("\(count) activo\(count == 1 ? "" : "s")", systemImage: "books.vertical.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.aeroNavy.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.aeroNavy)
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.aeroNavy.opacity(0.2), Color.aeroLavender.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: isLargeCanvas ? 72 : 56, height: isLargeCanvas ? 72 : 56)
                    Text("\(count)")
                        .font(isLargeCanvas ? .largeTitle : .title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.aeroNavy)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Estudios activos")
                .accessibilityValue("\(count)")
            }
        }
    }
}

// MARK: - Study Card

struct StudyCardView: View {
    let row: StudyRowModel
    let isLargeCanvas: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var titleInk: Color { colorScheme == .light ? Color.aeroNavy : Color.primary }

    var body: some View {
        AeroSurfaceCard {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        colors: [Color.aeroNavy, Color.aeroLavender.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 4)
                    .padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.study.title)
                            .font(AeroType.studyCardTitle(largeCanvas: isLargeCanvas))
                            .foregroundStyle(titleInk)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(isLargeCanvas ? .body : .caption)
                            .foregroundStyle(.tertiary)
                    }

                    Text(row.study.desc)
                        .font(AeroType.studyCardBody(largeCanvas: isLargeCanvas))
                        .foregroundStyle(.secondary)
                        .lineLimit(isLargeCanvas ? 3 : 2)

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
                            colors: [Color.aeroNavy.opacity(0.12), Color.aeroLavender.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)
                    Image(systemName: "books.vertical")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(colors: [Color.aeroNavy, Color.aeroLavender],
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

                Text("Flujo sugerido: importa un PDF o pega notas → genera tarjetas con IA → practica con examen simulado.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

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
                        colors: [Color.aeroNavy, Color.aeroNavyDeep],
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
        .modelContainer(for: [SDStudy.self, SDStudyBoard.self, SDResource.self, SDFlashcard.self, SDAttempt.self], inMemory: true)
}

#Preview("Banner stats") {
    StudyStatsBanner(userDisplayName: "Alex", count: 5, isLargeCanvas: false).padding()
}

#Preview("Estudios vacíos") {
    EmptyStudiesView(action: {}).padding()
}
