import SwiftUI
import SwiftData

struct StudyListView: View {
    @StateObject private var viewModel = StudyListViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showSettings = false
    @State private var selectedStudyId: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("userName") private var userName: String = ""

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }

    private var selectedStudy: SDStudy? {
        viewModel.rows.first { $0.id == selectedStudyId }?.study
    }

    private var displayName: String {
        let t = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Estudiante" : t
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isLargeCanvas {
                largeCanvasLayout
            } else {
                compactLayout
            }
        }
        .sheet(isPresented: $viewModel.showingCreateStudy) {
            CreateStudyView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
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
    }

    // MARK: - Large Canvas (Mac / iPad)

    private var largeCanvasLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            AthenaeumSidebar(
                viewModel: viewModel,
                selectedStudyId: $selectedStudyId,
                onShowSettings: { showSettings = true }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            .toolbarColorScheme(.dark, for: .navigationBar)
        } detail: {
            Group {
                if let study = selectedStudy {
                    StudyDetailView(study: study, onNavigateBack: {
                        withAnimation(.easeInOut(duration: 0.25)) { selectedStudyId = nil }
                    })
                    .id(study.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                } else {
                    LibraryWelcome(
                        viewModel: viewModel,
                        displayName: displayName,
                        columnVisibility: $columnVisibility,
                        onSelectStudy: { id in
                            withAnimation(.easeInOut(duration: 0.25)) { selectedStudyId = id }
                        },
                        onNewStudy: { viewModel.showingCreateStudy = true }
                    )
                    .id("library")
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedStudyId)
            .navigationBarBackButtonHidden(true)
        }
        .animation(.easeInOut(duration: 0.2), value: columnVisibility)
        .tint(Color.aeroNavy)
    }

    // MARK: - Compact (iPhone)

    private var compactLayout: some View {
        NavigationStack {
            ZStack {
                AeroAppBackground()

                if viewModel.isLoading && viewModel.rows.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.2)
                        Text("Cargando estudios...")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else if viewModel.rows.isEmpty {
                    EmptyStudiesView { viewModel.showingCreateStudy = true }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            StudyStatsBanner(userDisplayName: displayName, count: viewModel.rows.count, isLargeCanvas: false)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 16)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Biblioteca")
                                    .font(AeroType.sectionOverline())
                                    .foregroundStyle(.secondary).textCase(.uppercase).tracking(1.1)
                                Text("Toca un tema para abrirlo.")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)

                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(viewModel.rows) { row in
                                    NavigationLink(destination: StudyDetailView(study: row.study)) {
                                        StudyCardView(row: row, isLargeCanvas: false)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) { viewModel.deleteStudy(id: row.study.id) }
                                        label: { Label("Eliminar estudio", systemImage: "trash") }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) { viewModel.deleteStudy(id: row.study.id) }
                                        label: { Label("Eliminar", systemImage: "trash") }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 36)
                        }
                        .frame(maxWidth: AeroAdaptiveLayout.maxCompactContentWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Estudios")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Configuración")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { viewModel.showingCreateStudy = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .accessibilityLabel("Nuevo estudio")
                }
            }
            .tint(Color.aeroNavy)
        }
    }
}

// MARK: - Atheneum Sidebar

private struct AthenaeumSidebar: View {
    @ObservedObject var viewModel: StudyListViewModel
    @Binding var selectedStudyId: UUID?
    var onShowSettings: () -> Void

    var body: some View {
        ZStack {
            Color.aeroNavyDeep.ignoresSafeArea()

            VStack(spacing: 0) {
                // Branding — carga explícita del PNG desde el bundle
                VStack(alignment: .leading, spacing: 5) {
                    AeroLogoView()
                        .frame(width: 110, height: 41) // 110 × (264/713 × 110) ≈ 41
                    Text("ESPACIO ACADÉMICO")
                        .font(.caption2).foregroundStyle(.white.opacity(0.35)).tracking(0.9)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 26)
                .padding(.bottom, 18)

                Divider().overlay(Color.white.opacity(0.10))

                // Studies list
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        // Biblioteca shortcut (only when a study is selected)
                        if selectedStudyId != nil {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) { selectedStudyId = nil }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "books.vertical.fill")
                                        .font(.body).frame(width: 20)
                                        .foregroundStyle(.white.opacity(0.60))
                                    Text("Biblioteca")
                                        .font(.body).foregroundStyle(.white.opacity(0.75))
                                    Spacer()
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.top, 10)
                        }

                        Text("MIS ESTUDIOS")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.38)).tracking(1.2)
                            .padding(.horizontal, 22)
                            .padding(.top, 14)
                            .padding(.bottom, 8)

                        if viewModel.isLoading && viewModel.rows.isEmpty {
                            ProgressView().padding(.horizontal, 22)
                        } else if viewModel.rows.isEmpty {
                            Text("Aún no hay estudios.")
                                .font(.caption).foregroundStyle(.white.opacity(0.40))
                                .padding(.horizontal, 22)
                        } else {
                            ForEach(viewModel.rows) { row in
                                SidebarStudyRow(
                                    row: row,
                                    isSelected: selectedStudyId == row.id
                                ) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedStudyId = row.id
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                Divider().overlay(Color.white.opacity(0.10))

                // Bottom nav
                VStack(spacing: 2) {
                    AeroSidebarNavRow(icon: "gearshape.fill",       title: "Ajustes", isSelected: false, action: onShowSettings)
                    AeroSidebarNavRow(icon: "questionmark.circle",  title: "Soporte",  isSelected: false, action: {})
                }
                .padding(.top, 10)

                // CTA
                Button { viewModel.showingCreateStudy = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Nueva Sesión").fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.aeroNavy, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Sidebar Study Row

private struct SidebarStudyRow: View {
    let row: StudyRowModel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.aeroNavy.opacity(isSelected ? 0.90 : 0.40))
                        .frame(width: 30, height: 30)
                    Text(String(row.study.title.prefix(1)).uppercased())
                        .font(.caption).fontWeight(.bold).foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.study.title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.75))
                        .lineLimit(1)
                    if row.pendingReviewCount > 0 {
                        Text("\(row.pendingReviewCount) pendiente\(row.pendingReviewCount == 1 ? "" : "s")")
                            .font(.caption2).foregroundStyle(Color.aeroLavender.opacity(0.85))
                    }
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                isSelected ? Color.aeroNavy.opacity(0.55) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

// MARK: - Library Welcome (detail when nothing selected)

private struct LibraryWelcome: View {
    @ObservedObject var viewModel: StudyListViewModel
    let displayName: String
    var columnVisibility: Binding<NavigationSplitViewVisibility>? = nil
    var onSelectStudy: ((UUID) -> Void)? = nil
    let onNewStudy: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    // Edit mode state
    @State private var isEditMode = false
    @State private var selectedIds: Set<UUID> = []
    @State private var showDeleteConfirm = false

    private var studyGrid: [GridItem] {
        [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 16, alignment: .top)]
    }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(red: 0.10, green: 0.11, blue: 0.16) : Color(uiColor: .systemGroupedBackground))
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Biblioteca de Estudios")
                                .font(.system(.largeTitle, design: .rounded)).fontWeight(.bold)
                            Text("Gestiona y explora tus temas académicos activos.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: onNewStudy) {
                            Label("Nuevo Estudio", systemImage: "plus")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(AeroPrimaryButtonStyle())
                        .frame(maxWidth: 180)
                    }
                    .padding(.top, 4)

                    // Stats row
                    HStack(spacing: 14) {
                        LibraryStatCard(value: "\(viewModel.rows.count)", label: "Estudios activos", icon: "books.vertical.fill", color: .aeroNavy)
                        LibraryStatCard(
                            value: "\(viewModel.rows.reduce(0) { $0 + $1.pendingReviewCount })",
                            label: "Pendientes de repaso",
                            icon: "clock.fill",
                            color: .orange
                        )
                    }

                    if viewModel.rows.isEmpty {
                        EmptyStudiesView(action: onNewStudy)
                            .frame(maxWidth: 500).frame(maxWidth: .infinity)
                    } else {
                        // Section header + cancel button
                        HStack {
                            Text("Biblioteca")
                                .font(AeroType.sectionOverline())
                                .foregroundStyle(.secondary).textCase(.uppercase).tracking(1.1)
                            Spacer()
                            if isEditMode {
                                Button {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                        isEditMode = false; selectedIds.removeAll()
                                    }
                                } label: {
                                    Text("Cancelar").font(.subheadline).fontWeight(.medium)
                                        .foregroundStyle(Color.aeroNavy)
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isEditMode)

                        // Grid with edit mode badges
                        LazyVGrid(columns: studyGrid, spacing: 14) {
                            ForEach(viewModel.rows) { row in
                                let isSelected = selectedIds.contains(row.id)
                                ZStack(alignment: .topTrailing) {
                                    StudyCardView(row: row, isLargeCanvas: true)
                                        .scaleEffect(isEditMode ? 0.95 : 1.0)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(
                                                    isSelected ? Color.aeroNavy : Color.clear,
                                                    lineWidth: 2.5
                                                )
                                        )

                                    // X / checkmark badge
                                    if isEditMode {
                                        Button {
                                            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                                                if isSelected { selectedIds.remove(row.id) }
                                                else { selectedIds.insert(row.id) }
                                            }
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(isSelected ? Color.aeroNavy : Color.red)
                                                    .frame(width: 26, height: 26)
                                                    .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
                                                Image(systemName: isSelected ? "checkmark" : "xmark")
                                                    .font(.system(size: 11, weight: .black))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 7, y: -7)
                                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                                    }
                                }
                                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isEditMode)
                                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
                                .onTapGesture {
                                    if isEditMode {
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                                            if isSelected { selectedIds.remove(row.id) }
                                            else { selectedIds.insert(row.id) }
                                        }
                                    } else {
                                        onSelectStudy?(row.id)
                                    }
                                }
                                .onLongPressGesture(minimumDuration: 0.35) {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                        isEditMode = true
                                        selectedIds.insert(row.id)
                                    }
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewModel.deleteStudy(id: row.study.id)
                                    } label: { Label("Eliminar estudio", systemImage: "trash") }
                                }
                            }
                        }

                        // Bottom action bar
                        if isEditMode {
                            HStack(spacing: 14) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary).font(.subheadline)
                                Text(selectedIds.isEmpty
                                     ? "Mantén presionado para seleccionar"
                                     : "\(selectedIds.count) seleccionado\(selectedIds.count == 1 ? "" : "s")")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Button { showDeleteConfirm = true } label: {
                                    Label("Eliminar", systemImage: "trash.fill")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16).padding(.vertical, 9)
                                        .background(
                                            selectedIds.isEmpty ? Color.gray.opacity(0.30) : Color.red,
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedIds.isEmpty)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: AeroAdaptiveLayout.maxStudyListWidth)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Eliminar \(selectedIds.count) estudio\(selectedIds.count == 1 ? "" : "s")",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedIds.forEach { viewModel.deleteStudy(id: $0) }
                    selectedIds.removeAll()
                    isEditMode = false
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
}

private struct LibraryStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon).font(.title3).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title2).fontWeight(.bold).foregroundStyle(color)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.14) : .white)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        )
    }
}

// MARK: - Stats Banner (compact)

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
                    Text("Aquí tienes un vistazo de tus temas.")
                        .font(AeroType.studyCardBody(largeCanvas: isLargeCanvas))
                        .foregroundStyle(.secondary)
                    Label("\(count) activo\(count == 1 ? "" : "s")", systemImage: "books.vertical.fill")
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.aeroNavy.opacity(0.10), in: Capsule())
                        .foregroundStyle(Color.aeroNavy)
                        .padding(.top, 2)
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.aeroNavy.opacity(0.15), Color.aeroLavender.opacity(0.25)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: isLargeCanvas ? 72 : 56, height: isLargeCanvas ? 72 : 56)
                    Text("\(count)")
                        .font(isLargeCanvas ? .largeTitle : .title2)
                        .fontWeight(.bold).foregroundStyle(Color.aeroNavy)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Estudios activos: \(count)")
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
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 4)
                    .padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.study.title)
                            .font(AeroType.studyCardTitle(largeCanvas: isLargeCanvas))
                            .foregroundStyle(titleInk).multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(isLargeCanvas ? .body : .caption).foregroundStyle(.tertiary)
                    }

                    Text(row.study.desc)
                        .font(AeroType.studyCardBody(largeCanvas: isLargeCanvas))
                        .foregroundStyle(.secondary).lineLimit(isLargeCanvas ? 3 : 2)

                    if let acc = row.accuracy {
                        let tint: Color = acc >= 0.7 ? .green : acc >= 0.4 ? .orange : .red
                        ProgressView(value: acc) {
                            HStack {
                                Text("Precisión").font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(acc * 100))%").font(.caption2).fontWeight(.semibold).foregroundStyle(tint)
                            }
                        }
                        .tint(tint)
                    }

                    HStack(spacing: 8) {
                        if row.pendingReviewCount > 0 {
                            Label("\(row.pendingReviewCount) pendiente\(row.pendingReviewCount == 1 ? "" : "s")", systemImage: "rectangle.stack.fill")
                                .font(.caption2).fontWeight(.medium)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.orange.opacity(0.10))
                                .foregroundStyle(.orange).cornerRadius(8)
                        } else {
                            Label("Al día", systemImage: "checkmark.circle.fill")
                                .font(.caption2).fontWeight(.medium)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.green.opacity(0.10))
                                .foregroundStyle(.green).cornerRadius(8)
                        }
                        Spacer()
                        if let last = row.lastPractice {
                            Text(last.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2).foregroundStyle(.secondary)
                        } else {
                            Text(row.study.createdAt.formatted(.dateTime.day().month().year()))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
        }
    }
}

// MARK: - Empty State

struct EmptyStudiesView: View {
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }

    var body: some View {
        AeroSurfaceCard {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.aeroNavy.opacity(0.08))
                        .frame(width: 100, height: 100)
                    Image(systemName: "books.vertical")
                        .font(.system(size: 42))
                        .foregroundStyle(Color.aeroNavy)
                }
                VStack(spacing: 8) {
                    Text("Empieza tu primer estudio")
                        .font(isLargeCanvas ? .title2 : .title3).fontWeight(.bold)
                    Text("Crea un tema, agrega recursos y deja que\nla IA genere tus flashcards.")
                        .font(isLargeCanvas ? .body : .subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button(action: action) {
                    Label("Crear primer estudio", systemImage: "plus").fontWeight(.semibold)
                }
                .buttonStyle(AeroPrimaryButtonStyle())
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Create Study Sheet

struct CreateStudyView: View {
    @ObservedObject var viewModel: StudyListViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var canCreate: Bool {
        !viewModel.newStudyTitle.isEmpty && !viewModel.newStudyDescription.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancelar")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.secondary.opacity(0.30), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    if viewModel.createStudy() { dismiss() }
                } label: {
                    Text("Crear")
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(canCreate ? Color.aeroNavy : Color.secondary.opacity(0.25))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))

            Divider()

            // Navy hero banner
            ZStack {
                LinearGradient(
                    colors: [Color.aeroNavy, Color.aeroNavyDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                VStack(spacing: 8) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 34)).foregroundColor(.white)
                    Text("Nuevo Estudio")
                        .font(isLargeCanvas ? .title2 : .title3).fontWeight(.bold).foregroundStyle(.white)
                    Text("Dale un nombre y descripción a tu tema.")
                        .font(isLargeCanvas ? .body : .caption).foregroundStyle(.white.opacity(0.8))
                }
                .padding(.vertical, isLargeCanvas ? 34 : 28)
            }
            .frame(maxWidth: .infinity)

            // Form
            Form {
                Section {
                    TextField("Título (ej: Biología Celular)", text: $viewModel.newStudyTitle)
                    ZStack(alignment: .topLeading) {
                        if viewModel.newStudyDescription.isEmpty {
                            Text("Describe el tema de estudio...")
                                .foregroundColor(.gray.opacity(0.5)).padding(.top, 8).padding(.leading, 4)
                        }
                        TextEditor(text: $viewModel.newStudyDescription).frame(minHeight: 100)
                    }
                } header: { Text("Información del estudio") }
            }
            .frame(maxWidth: AeroAdaptiveLayout.maxRegularContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Logo Helper

/// Carga AERO.png desde el bundle explícitamente — funciona con PNGs sueltos (no solo .xcassets)
private struct AeroLogoView: View {
    var body: some View {
        #if canImport(UIKit)
        let img = UIImage(named: "AERO")
        return Group {
            if let img {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Aero.")
                    .font(.title3).fontWeight(.bold).foregroundStyle(.white)
            }
        }
        #else
        let img = NSImage(named: "AERO")
        return Group {
            if let img {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Aero.")
                    .font(.title3).fontWeight(.bold).foregroundStyle(.white)
            }
        }
        #endif
    }
}

// MARK: - Previews

#Preview("Lista estudios") {
    StudyListView()
        .modelContainer(for: [SDStudy.self, SDStudyBoard.self, SDResource.self, SDFlashcard.self, SDAttempt.self], inMemory: true)
}
#Preview("Estudios vacíos") { EmptyStudiesView(action: {}).padding() }
