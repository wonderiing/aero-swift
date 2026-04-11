import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Main View

struct StudyDetailView: View {
    @StateObject private var viewModel: StudyDetailViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab = 0
    @State private var showingAnkiSession = false

    var onNavigateBack: (() -> Void)? = nil

    init(study: SDStudy, onNavigateBack: (() -> Void)? = nil) {
        self.onNavigateBack = onNavigateBack
        _viewModel = StateObject(wrappedValue: StudyDetailViewModel(study: study))
    }

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var contentWidth: CGFloat {
        isLargeCanvas ? AeroAdaptiveLayout.maxRegularContentWidth : AeroAdaptiveLayout.maxCompactContentWidth
    }

    var body: some View {
        Group {
            if isLargeCanvas {
                largeCanvasLayout
            } else {
                compactLayout
            }
        }
        .tint(Color.aeroNavy)
        .sheet(isPresented: $viewModel.showingAddResource) { AddResourceView(viewModel: viewModel) }
        .sheet(isPresented: $viewModel.showingGenerateFlashcards) { GenerateFlashcardsSheet(viewModel: viewModel) }
        .sheet(isPresented: $viewModel.showingGenerateAnkiCards) { GenerateAnkiCardsSheet(viewModel: viewModel) }
        .sheet(isPresented: $viewModel.showingCreateFlashcardManual) { CreateFlashcardManualView(viewModel: viewModel) }
        .sheet(isPresented: $viewModel.showingGenerateFromGaps) {
            GenerateFromGapsSheet(viewModel: viewModel) {
                selectedTab = 1
            }
        }
        .sheet(isPresented: $viewModel.showingGenerateResourcesFromGaps) {
            GenerateResourcesFromGapsSheet(viewModel: viewModel) {
                selectedTab = 0
            }
        }
        .fullScreenCover(isPresented: $showingAnkiSession) { AnkiSessionView(viewModel: viewModel) }
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.fetchContent()
        }
        .onChange(of: showingAnkiSession) { _, isShowing in
            // Refresh content after session ends (SM-2 was saved directly to context)
            if !isShowing { viewModel.fetchContent() }
        }
    }

    // MARK: Large canvas — tab picker in content area (single sidebar from parent)

    @ViewBuilder
    private var largeCanvasLayout: some View {
        VStack(spacing: 0) {
            StudyHeroHeader(
                study: viewModel.study,
                reviewCount: viewModel.reviewQueue.count,
                ankiCardCount: viewModel.ankiCards.count,
                ankiDueCount: viewModel.ankiReviewQueue.count,
                isLargeCanvas: true,
                onNavigateBack: onNavigateBack,
                onStartAnkiSession: { showingAnkiSession = true }
            )
            StudyTabPicker(selectedTab: $selectedTab, isLargeCanvas: true)
            Divider()

            // Content
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                if viewModel.isLoading && viewModel.resources.isEmpty && viewModel.flashcards.isEmpty && viewModel.ankiCards.isEmpty {
                    ProgressView().frame(maxHeight: .infinity)
                } else {
                    TabView(selection: $selectedTab) {
                        ResourcesTab(viewModel: viewModel, isLargeCanvas: true).tag(0)
                        AnkiCardsTab(viewModel: viewModel, isLargeCanvas: true).tag(1)
                        ExamenSimuladoTab(viewModel: viewModel, isLargeCanvas: true).tag(2)
                        ProgressTab(viewModel: viewModel, isLargeCanvas: true).tag(3)
                        StudyCanvasTab(viewModel: viewModel, isLargeCanvas: true).tag(4)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.22), value: selectedTab)
                }
            }
            .frame(maxWidth: .infinity)
        }
        // Keep toolbar visible so macOS shows the system sidebar toggle in the window bar
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: Compact — original tab picker layout

    @ViewBuilder
    private var compactLayout: some View {
        VStack(spacing: 0) {
            StudyHeroHeader(
                study: viewModel.study,
                reviewCount: viewModel.reviewQueue.count,
                ankiCardCount: viewModel.ankiCards.count,
                ankiDueCount: viewModel.ankiReviewQueue.count,
                isLargeCanvas: false,
                onNavigateBack: nil,
                onStartAnkiSession: { showingAnkiSession = true }
            )
            StudyTabPicker(selectedTab: $selectedTab, isLargeCanvas: false)

            ZStack {
                AeroAppBackground()
                if viewModel.isLoading && viewModel.resources.isEmpty && viewModel.flashcards.isEmpty && viewModel.ankiCards.isEmpty {
                    ProgressView().frame(maxHeight: .infinity)
                } else {
                    TabView(selection: $selectedTab) {
                        ResourcesTab(viewModel: viewModel, isLargeCanvas: false).tag(0)
                        AnkiCardsTab(viewModel: viewModel, isLargeCanvas: false).tag(1)
                        ExamenSimuladoTab(viewModel: viewModel, isLargeCanvas: false).tag(2)
                        ProgressTab(viewModel: viewModel, isLargeCanvas: false).tag(3)
                        StudyCanvasTab(viewModel: viewModel, isLargeCanvas: false).tag(4)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(maxWidth: contentWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTab == 0 {
                    Button { viewModel.showingAddResource = true } label: { Image(systemName: "plus.circle.fill") }
                } else if selectedTab == 1 {
                    Button { viewModel.showingGenerateAnkiCards = true } label: { Image(systemName: "plus.circle.fill") }
                        .disabled(viewModel.resources.isEmpty)
                } else if selectedTab == 2 {
                    Menu {
                        Button { viewModel.showingGenerateFlashcards = true }
                        label: { Label("Generar con IA", systemImage: "wand.and.stars") }
                        .disabled(viewModel.resources.isEmpty)
                        Button { viewModel.showingCreateFlashcardManual = true }
                        label: { Label("Crear manualmente", systemImage: "pencil.and.list.clipboard") }
                        .disabled(viewModel.resources.isEmpty)
                    } label: { Image(systemName: "plus.circle.fill") }
                } else {
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Hero Header

struct StudyHeroHeader: View {
    let study: SDStudy
    let reviewCount: Int
    let ankiCardCount: Int
    let ankiDueCount: Int
    let isLargeCanvas: Bool
    /// En iPad / Mac: botón para volver a la biblioteca sobre el hero.
    var onNavigateBack: (() -> Void)? = nil
    var onStartAnkiSession: (() -> Void)? = nil

    @State private var wikipediaThumbnail: URL?
    @State private var wikipediaFetchFinished = false

    private var hasPractice: Bool { reviewCount > 0 || ankiCardCount > 0 }

    private var heroHeight: CGFloat {
        if hasPractice {
            return isLargeCanvas ? 328 : 256
        }
        return isLargeCanvas ? 288 : 220
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            heroBackdrop
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.2), location: 0),
                    .init(color: .black.opacity(0.45), location: 0.45),
                    .init(color: .black.opacity(0.88), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: heroHeight)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    if let onNavigateBack {
                        Button(action: onNavigateBack) {
                            Label("Biblioteca", systemImage: "chevron.left")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .shadow(color: .black.opacity(0.28), radius: 10, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, isLargeCanvas ? 24 : 16)
                .padding(.top, isLargeCanvas ? 12 : 8)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 10) {
                    Text("ESTUDIO")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.68))
                        .tracking(2.4)

                    Text(study.title)
                        .font(
                            isLargeCanvas
                                ? .system(size: 36, weight: .bold, design: .rounded)
                                : .system(size: 28, weight: .bold, design: .rounded)
                        )
                        .foregroundStyle(.white)
                        .lineLimit(4)
                        .minimumScaleFactor(0.72)
                        .shadow(color: .black.opacity(0.5), radius: 16, y: 5)

                    if !study.desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(study.desc)
                            .font(isLargeCanvas ? .body : .subheadline)
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(isLargeCanvas ? 3 : 2)
                            .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
                    }

                    if hasPractice {
                        HStack(spacing: 10) {
                            if ankiCardCount > 0 {
                                Button {
                                    onStartAnkiSession?()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "rectangle.on.rectangle.angled").font(.caption)
                                        if ankiDueCount > 0 {
                                            Text("Flashcards · \(ankiDueCount) pendiente\(ankiDueCount == 1 ? "" : "s")")
                                                .fontWeight(.semibold)
                                                .font(isLargeCanvas ? .body : .subheadline)
                                        } else {
                                            Text("Flashcards · Repasar todo")
                                                .fontWeight(.semibold)
                                                .font(isLargeCanvas ? .body : .subheadline)
                                        }
                                    }
                                    .foregroundStyle(Color.aeroNavy)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, isLargeCanvas ? 12 : 9)
                                    .background(Color.white, in: Capsule())
                                    .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                                }
                            }

                            if reviewCount > 0 {
                                NavigationLink(destination: PracticeSessionView(study: study)) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.questionmark.fill").font(.caption)
                                        Text("Examen · \(reviewCount)")
                                            .fontWeight(.semibold)
                                            .font(isLargeCanvas ? .body : .subheadline)
                                    }
                                    .foregroundStyle(Color.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, isLargeCanvas ? 12 : 9)
                                    .background(Color.aeroLavender.opacity(0.42), in: Capsule())
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, isLargeCanvas ? 24 : 18)
                .padding(.bottom, isLargeCanvas ? 24 : 18)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
        .task(id: study.id) {
            wikipediaFetchFinished = false
            wikipediaThumbnail = await WikipediaThumbnailService.thumbnailURL(for: study.title)
            wikipediaFetchFinished = true
        }
    }

    @ViewBuilder
    private var heroBackdrop: some View {
        if let url = wikipediaThumbnail {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    heroFallbackGradient
                        .overlay { ProgressView().tint(.white) }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    heroFallbackGradient
                @unknown default:
                    heroFallbackGradient
                }
            }
        } else {
            heroFallbackGradient
                .overlay(alignment: .topTrailing) {
                    if !wikipediaFetchFinished {
                        ProgressView()
                            .tint(.white.opacity(0.85))
                            .padding(14)
                    }
                }
        }
    }

    private var heroFallbackGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.14, green: 0.16, blue: 0.28),
                Color.aeroNavy,
                Color.aeroNavyDeep
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Custom Tab Picker

private struct StudyTabDefinition: Identifiable {
    let id: Int
    let title: String
    let systemImage: String
}

struct StudyTabPicker: View {
    @Binding var selectedTab: Int
    let isLargeCanvas: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let tabs: [StudyTabDefinition] = [
        .init(id: 0, title: "Recursos", systemImage: "doc.text"),
        .init(id: 1, title: "Flashcards", systemImage: "rectangle.on.rectangle.angled"),
        .init(id: 2, title: "Examen", systemImage: "doc.questionmark.fill"),
        .init(id: 3, title: "Progreso", systemImage: "chart.bar"),
        .init(id: 4, title: "Pizarra", systemImage: "scribble.variable")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tabs) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                            selectedTab = tab.id
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.systemImage).font(.caption)
                            Text(tab.title)
                                .font(isLargeCanvas ? .body : .subheadline)
                                .fontWeight(selectedTab == tab.id ? .semibold : .regular)
                        }
                        .foregroundStyle(selectedTab == tab.id ? Color.white : Color.secondary)
                        .padding(.horizontal, isLargeCanvas ? 18 : 14)
                        .padding(.vertical, isLargeCanvas ? 11 : 9)
                        .background(
                            Capsule().fill(selectedTab == tab.id ? Color.aeroNavy : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selectedTab == tab.id ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.aeroCardFill)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 14, y: 5)
        )
        .padding(.horizontal, isLargeCanvas ? 24 : 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Resources Tab

private enum TopicMasterySnapshot {
    static func compute(from viewModel: StudyDetailViewModel) -> (percent: Int, progress: Double, footnote: String) {
        let resources = viewModel.resources.count
        let examAttempts = viewModel.flashcards.flatMap(\.attempts)
        let totalAtt = examAttempts.count
        let correctAtt = examAttempts.filter(\.isCorrect).count
        let examAcc = totalAtt > 0 ? Double(correctAtt) / Double(totalAtt) : nil

        let ankiCards = viewModel.ankiCards
        let totalReviews = ankiCards.reduce(0) { $0 + $1.ratingHistory.count }
        let failures = ankiCards.reduce(0) { $0 + $1.ratingHistory.filter { $0 < 3 }.count }
        let ankiAcc = totalReviews > 0 ? Double(totalReviews - failures) / Double(totalReviews) : nil

        let combined: Double?
        if let e = examAcc, let a = ankiAcc {
            combined = (e + a) / 2
        } else if let e = examAcc {
            combined = e
        } else if let a = ankiAcc {
            combined = a
        } else {
            combined = nil
        }

        if let c = combined {
            let pct = Int((c * 100).rounded())
            let foot = "Basado en examen simulado y flashcards. \(resources) recurso\(resources == 1 ? "" : "s") en este tema."
            return (pct, c, foot)
        }

        if resources == 0 {
            return (0, 0, "Añade materiales y practica para ver aquí tu dominio del tema.")
        }
        return (0, 0, "Practica el examen o las flashcards para calcular tu dominio. Tienes \(resources) recurso\(resources == 1 ? "" : "s").")
    }
}

struct ResourcesTab: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    let isLargeCanvas: Bool

    private var columns: [GridItem] {
        if isLargeCanvas {
            return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        }
        return [GridItem(.flexible())]
    }

    private var mastery: (percent: Int, progress: Double, footnote: String) {
        TopicMasterySnapshot.compute(from: viewModel)
    }

    var body: some View {
        if viewModel.resources.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AeroDashedAddResourceCard { viewModel.showingAddResource = true }

                    AeroTopicMasteryCard(
                        percent: mastery.percent,
                        footnote: mastery.footnote,
                        progress: mastery.progress
                    )


                }
                .padding(.horizontal, isLargeCanvas ? 24 : 16)
                .padding(.vertical, 16)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Group {
                        if isLargeCanvas {
                            HStack(alignment: .top, spacing: 14) {
                                AeroDashedAddResourceCard { viewModel.showingAddResource = true }
                                    .frame(maxWidth: .infinity)
                                AeroTopicMasteryCard(
                                    percent: mastery.percent,
                                    footnote: mastery.footnote,
                                    progress: mastery.progress
                                )
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            AeroDashedAddResourceCard { viewModel.showingAddResource = true }
                            AeroTopicMasteryCard(
                                percent: mastery.percent,
                                footnote: mastery.footnote,
                                progress: mastery.progress
                            )
                        }
                    }

                    AeroSectionCaption(text: "Materiales de la biblioteca")

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.resources) { resource in
                            NavigationLink {
                                ResourceDetailView(studyViewModel: viewModel, resource: resource)
                            } label: {
                                ResourceCardView(resource: resource, isLargeCanvas: isLargeCanvas)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, isLargeCanvas ? 24 : 16)
                .padding(.vertical, 14)
                .padding(.bottom, 72)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        viewModel.showingAddResource = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Color.aeroNavy))
                            .shadow(color: Color.aeroNavy.opacity(0.4), radius: 14, y: 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Agregar recurso")
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

struct ResourceCardView: View {
    let resource: SDResource
    let isLargeCanvas: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var titleInk: Color { colorScheme == .light ? Color.aeroNavy : Color.primary }

    private var isPDF: Bool { resource.sourceName?.lowercased().hasSuffix(".pdf") == true }

    private var iconBackground: Color {
        if isPDF { return Color.red.opacity(0.12) }
        return Color.yellow.opacity(0.14)
    }

    private var iconForeground: Color {
        if isPDF { return Color.red.opacity(0.85) }
        return Color.orange.opacity(0.9)
    }

    var body: some View {
        AeroSurfaceCard {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconBackground)
                        .frame(width: 48, height: 48)
                    Image(systemName: isPDF ? "doc.richtext.fill" : "doc.text.fill")
                        .font(.title3)
                        .foregroundStyle(iconForeground)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(resource.title)
                        .font(isLargeCanvas ? .title3 : .headline)
                        .foregroundStyle(titleInk)
                        .lineLimit(1)
                    Text(Self.previewLine(from: resource.content))
                        .font(isLargeCanvas ? .callout : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(isLargeCanvas ? 3 : 2)
                    Text(metaLine)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static func previewLine(from markdown: String) -> String {
        let plain = AeroMarkdown.plainText(from: markdown)
        let oneLine = plain.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if oneLine.count > 220 {
            return String(oneLine.prefix(220)) + "…"
        }
        return oneLine
    }

    private var metaLine: String {
        let date = resource.createdAt.formatted(date: .abbreviated, time: .omitted)
        let chars = resource.content.count
        if let src = resource.sourceName {
            return "\(date) · \(chars) caracteres · \(src)"
        }
        return "\(date) · \(chars) caracteres"
    }
}

// MARK: - Anki Cards Tab (Flashcards estilo Anki)

struct AnkiCardsTab: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    let isLargeCanvas: Bool
    @State private var showingSession = false

    private var columns: [GridItem] {
        isLargeCanvas
            ? [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            : [GridItem(.flexible())]
    }

    private var dueCount: Int { viewModel.ankiReviewQueue.count }
    private var totalCount: Int { viewModel.ankiCards.count }

    var body: some View {
        if viewModel.ankiCards.isEmpty {
            ContentUnavailableView(
                "Sin flashcards todavía",
                systemImage: "rectangle.on.rectangle.angled",
                description: Text("Genera flashcards simples frente/dorso con IA para memorizar con repetición espaciada.")
            )
            .overlay(alignment: .bottom) {
                Button {
                    viewModel.showingGenerateAnkiCards = true
                } label: {
                    Label("Generar con IA", systemImage: "wand.and.stars")
                        .fontWeight(.semibold)
                }
                .buttonStyle(AeroPrimaryButtonStyle(disabled: viewModel.resources.isEmpty))
                .disabled(viewModel.resources.isEmpty)
                .controlSize(isLargeCanvas ? .large : .regular)
                .padding(.horizontal, 40)
                .padding(.bottom, 34)
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.ankiCards) { card in
                        AnkiCardItemView(card: card, isLargeCanvas: isLargeCanvas) {
                            viewModel.deleteAnkiCard(id: card.id)
                        }
                    }
                }
                .padding(.horizontal, isLargeCanvas ? 24 : 16)
                .padding(.top, 12)
                .padding(.bottom, 90)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    showingSession = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        if dueCount > 0 {
                            Text("Practicar · \(dueCount) pendiente\(dueCount == 1 ? "" : "s")")
                                .fontWeight(.semibold)
                        } else {
                            Text("Repasar todo · \(totalCount) tarjeta\(totalCount == 1 ? "" : "s")")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        if dueCount > 0 {
                            Text("SM-2")
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.white.opacity(0.2), in: Capsule())
                        } else {
                            Text("Libre")
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.white.opacity(0.2), in: Capsule())
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(
                                colors: dueCount > 0
                                    ? [Color.aeroNavy, Color.aeroNavyDeep]
                                    : [Color.aeroMint.opacity(0.85), Color.aeroNavy],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .shadow(color: Color.aeroNavy.opacity(0.35), radius: 14, y: 6)
                    )
                }
                .padding(.horizontal, isLargeCanvas ? 24 : 16)
                .padding(.top, 10).padding(.bottom, 16)
                .background(.ultraThinMaterial)
            }
            .fullScreenCover(isPresented: $showingSession) {
                AnkiSessionView(viewModel: viewModel)
            }
        }
    }
}

struct AnkiCardItemView: View {
    let card: SDAnkiCard
    let isLargeCanvas: Bool
    var onDelete: (() -> Void)? = nil
    @State private var isFlipped = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { isFlipped.toggle() }
        } label: {
            AeroSurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        Label("Flashcard", systemImage: "rectangle.on.rectangle.angled")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(Color.teal)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Color.teal.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 7))

                        Spacer()

                        if card.intervalDays > 0 {
                            Label("en \(card.intervalDays)d", systemImage: "clock")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        Image(systemName: isFlipped ? "arrow.uturn.backward.circle" : "arrow.uturn.forward.circle")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }

                    if !isFlipped {
                        Text(card.front)
                            .font(isLargeCanvas ? .callout : .body)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(card.back)
                            .font(isLargeCanvas ? .body : .subheadline)
                            .lineSpacing(3)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !card.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(card.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.caption)
                                            .padding(.horizontal, 9).padding(.vertical, 4)
                                            .background(Color.teal.opacity(0.1))
                                            .foregroundStyle(.teal)
                                            .clipShape(.rect(cornerRadius: 7))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Eliminar tarjeta", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Examen Simulado Tab (antigua FlashcardsTab)

struct ExamenSimuladoTab: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    let isLargeCanvas: Bool

    private var columns: [GridItem] {
        if isLargeCanvas {
            return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        }
        return [GridItem(.flexible())]
    }

    var body: some View {
        if viewModel.flashcards.isEmpty {
            ContentUnavailableView(
                "Sin preguntas de examen todavía",
                systemImage: "doc.questionmark.fill",
                description: Text("Genera preguntas con IA para practicar como en un examen real. La IA evalúa tus respuestas.")
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
                    .controlSize(isLargeCanvas ? .large : .regular)

                    Button {
                        viewModel.showingCreateFlashcardManual = true
                    } label: {
                        Label("Manual", systemImage: "pencil")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.aeroNavy.opacity(0.9))
                    .disabled(viewModel.resources.isEmpty)
                    .controlSize(isLargeCanvas ? .large : .regular)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.flashcards) { card in
                        FlashcardItemView(card: card, isLargeCanvas: isLargeCanvas) {
                            viewModel.deleteFlashcard(id: card.id)
                        }
                    }
                }
                .padding(.horizontal, isLargeCanvas ? 24 : 16)
                .padding(.top, 12)
                .padding(.bottom, 90)
            }
            .safeAreaInset(edge: .bottom) {
                NavigationLink(destination: PracticeSessionView(study: viewModel.study)) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("Practicar examen · \(viewModel.reviewQueue.count) pregunta\(viewModel.reviewQueue.count == 1 ? "" : "s")")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("IA evalúa")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.white.opacity(0.2), in: Capsule())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.aeroNavy, Color.aeroNavyDeep],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .shadow(color: Color.aeroNavy.opacity(0.35), radius: 14, y: 6)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, isLargeCanvas ? 24 : 16)
                .padding(.top, 10).padding(.bottom, 16)
                .background(.ultraThinMaterial)
            }
        }
    }
}

struct FlashcardItemView: View {
    let card: SDFlashcard
    let isLargeCanvas: Bool
    var onDelete: (() -> Void)? = nil
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    private var questionInk: Color { colorScheme == .light ? Color.aeroNavy : Color.primary }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { isExpanded.toggle() }
        } label: {
            AeroSurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        Label(card.type == .open ? "Abierta" : "Opción múltiple",
                              systemImage: card.type == .open ? "text.bubble" : "list.bullet.circle")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(card.type == .open ? Color.aeroNavy : Color.aeroLavender)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background((card.type == .open ? Color.aeroNavy : Color.aeroLavender).opacity(0.12))
                            .clipShape(.rect(cornerRadius: 7))

                        Spacer()

                        if card.intervalDays > 0 {
                            Label("en \(card.intervalDays)d", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }

                    Text(card.question)
                        .font(isLargeCanvas ? .callout : .body)
                        .fontWeight(.medium)
                        .foregroundStyle(questionInk)
                        .lineLimit(isExpanded ? nil : 3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isExpanded {
                        Divider()

                        Text(card.answer)
                            .font(isLargeCanvas ? .body : .subheadline)
                            .lineSpacing(3)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !card.conceptTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(card.conceptTags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.caption)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 4)
                                            .background(Color.teal.opacity(0.1))
                                            .foregroundStyle(.teal)
                                            .clipShape(.rect(cornerRadius: 7))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Eliminar tarjeta", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Progress Tab

struct ProgressTab: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    let isLargeCanvas: Bool

    var body: some View {
        if let gaps = viewModel.gapAnalysis {
            let allAttempts = viewModel.flashcards.flatMap(\.attempts)
            let totalAtt = allAttempts.count
            let correctAtt = allAttempts.filter(\.isCorrect).count
            let acc = totalAtt > 0 ? min(1, max(0, Double(correctAtt) / Double(totalAtt))) : 0.0
            let ankiTotal = gaps.ankiTotalReviews

            let hasExamData = totalAtt > 0
            let hasAnkiData = ankiTotal > 0

            if !hasExamData && !hasAnkiData {
                ContentUnavailableView(
                    "Sin datos de práctica",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Practica flashcards o responde preguntas de examen para ver tu progreso aquí.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 14) {

                        // ── Sección Examen Simulado ──
                        if hasExamData {
                            ProgressSectionHeader(title: "Examen simulado",
                                                  systemImage: "doc.questionmark.fill",
                                                  color: Color.aeroNavy)

                            AeroSurfaceCard {
                                HStack(spacing: 20) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color.gray.opacity(0.15), lineWidth: 10)
                                            .frame(width: 90, height: 90)
                                        Circle()
                                            .trim(from: 0, to: CGFloat(acc))
                                            .stroke(
                                                LinearGradient(colors: [.teal, .cyan],
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
                                            .font(isLargeCanvas ? .title3 : .headline)
                                        StatRow(label: "Total intentos", value: "\(totalAtt)")
                                        StatRow(label: "Aciertos", value: "\(correctAtt)", color: .green)
                                        StatRow(label: "Errores", value: "\(totalAtt - correctAtt)", color: .red)
                                        let reviewed = viewModel.flashcards.filter { !$0.attempts.isEmpty }.count
                                        StatRow(label: "Tarjetas practicadas", value: "\(reviewed) / \(viewModel.flashcards.count)")
                                    }
                                    Spacer()
                                }
                            }

                            if !gaps.errorTypeBreakdown.isEmpty {
                                AeroSurfaceCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Label("Errores por tipo", systemImage: "chart.bar.fill")
                                            .font(.subheadline).fontWeight(.semibold)
                                        Divider()
                                        ForEach(gaps.errorTypeBreakdown, id: \.type.rawValue) { item in
                                            let pct = totalAtt > 0 ? Double(item.count) / Double(totalAtt) : 0
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: errorTypeIcon(item.type))
                                                            .font(.caption)
                                                            .foregroundStyle(errorTypeColor(item.type))
                                                        Text(errorTypeLabel(item.type))
                                                            .font(.caption)
                                                            .foregroundStyle(.primary)
                                                    }
                                                    Spacer()
                                                    Text("\(item.count) error\(item.count == 1 ? "" : "es") · \(Int(pct * 100))%")
                                                        .font(.caption).fontWeight(.semibold)
                                                        .foregroundStyle(errorTypeColor(item.type))
                                                }
                                                ProgressView(value: pct).tint(errorTypeColor(item.type))
                                            }
                                        }
                                    }
                                }
                            }

                            if !gaps.gaps.isEmpty {
                                ProgressSectionHeader(title: "Lagunas (Examen)",
                                                      systemImage: "exclamationmark.triangle.fill",
                                                      color: .orange)
                                ForEach(gaps.gaps) { gap in
                                    GapCardView(gap: gap, isLargeCanvas: isLargeCanvas)
                                }
                            }

                            if !gaps.strongConcepts.isEmpty {
                                ProgressSectionHeader(title: "Conceptos dominados (Examen)",
                                                      systemImage: "checkmark.seal.fill",
                                                      color: .green)
                                ForEach(gaps.strongConcepts) { concept in
                                    StrongConceptCardView(concept: concept)
                                }
                            }
                        }

                        // ── Sección Flashcards Anki ──
                        if hasAnkiData {
                            ProgressSectionHeader(title: "Flashcards (Anki)",
                                                  systemImage: "rectangle.on.rectangle.angled",
                                                  color: .teal)

                            AnkiProgressSummaryCard(
                                ankiCards: viewModel.ankiCards,
                                totalReviews: ankiTotal,
                                isLargeCanvas: isLargeCanvas
                            )

                            if !gaps.ankiGaps.isEmpty {
                                ProgressSectionHeader(title: "Conceptos difíciles (Anki)",
                                                      systemImage: "brain.head.profile",
                                                      color: .red)
                                ForEach(gaps.ankiGaps) { gap in
                                    AnkiGapCardView(gap: gap, isLargeCanvas: isLargeCanvas)
                                }
                            }

                            if !gaps.ankiStrongConcepts.isEmpty {
                                ProgressSectionHeader(title: "Conceptos dominados",
                                                      systemImage: "star.fill",
                                                      color: .teal)
                                ForEach(gaps.ankiStrongConcepts) { concept in
                                    StrongConceptCardView(concept: concept)
                                }
                            }
                        }

                        // Refuerzo: misma lista que usa la IA (`reinforcementGaps`: examen, fallback por tarjeta o Anki).
                        if !viewModel.reinforcementGaps.isEmpty {
                            VStack(spacing: 10) {
                                Button {
                                    viewModel.showingGenerateFromGaps = true
                                } label: {
                                    AeroSurfaceCard {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                Circle()
                                                    .fill(LinearGradient(colors: [.orange, .red],
                                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                                    .frame(width: 46, height: 46)
                                                Image(systemName: "wand.and.stars").font(.title3).foregroundStyle(.white)
                                            }
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text("Generar tarjetas de refuerzo")
                                                    .font(isLargeCanvas ? .subheadline : .callout)
                                                    .fontWeight(.semibold).foregroundStyle(.primary)
                                                Text("La IA creará preguntas sobre tus \(viewModel.reinforcementGaps.count) concepto\(viewModel.reinforcementGaps.count == 1 ? "" : "s") a reforzar")
                                                    .font(.caption2).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.orange)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.resources.isEmpty)

                                Button {
                                    viewModel.showingGenerateResourcesFromGaps = true
                                } label: {
                                    AeroSurfaceCard {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                Circle()
                                                    .fill(LinearGradient(colors: [Color.aeroNavy, Color.aeroNavy.opacity(0.75)],
                                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                                    .frame(width: 46, height: 46)
                                                Image(systemName: "doc.text.fill").font(.title3).foregroundStyle(.white)
                                            }
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text("Generar recursos de estudio")
                                                    .font(isLargeCanvas ? .subheadline : .callout)
                                                    .fontWeight(.semibold).foregroundStyle(.primary)
                                                Text("Apuntes con IA según tus lagunas; se guardan en Recursos.")
                                                    .font(.caption2).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.aeroNavy.opacity(0.8))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.resources.isEmpty)
                            }
                        }
                    }
                    .padding(.horizontal, isLargeCanvas ? 24 : 16)
                    .padding(.vertical, 12)
                }
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

    private func errorTypeLabel(_ type: ErrorType) -> String {
        switch type {
        case .conceptual: return "Error conceptual"
        case .memoria: return "Falta de memoria"
        case .confusion: return "Confusión"
        case .incompleto: return "Respuesta incompleta"
        }
    }

    private func errorTypeIcon(_ type: ErrorType) -> String {
        switch type {
        case .conceptual: return "brain"
        case .memoria: return "clock.arrow.circlepath"
        case .confusion: return "arrow.triangle.2.circlepath"
        case .incompleto: return "text.badge.minus"
        }
    }

    private func errorTypeColor(_ type: ErrorType) -> Color {
        switch type {
        case .conceptual: return .red
        case .memoria: return .orange
        case .confusion: return Color.aeroNavy
        case .incompleto: return Color.aeroNavy
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

// MARK: - Anki Progress Views

struct AnkiProgressSummaryCard: View {
    let ankiCards: [SDAnkiCard]
    let totalReviews: Int
    let isLargeCanvas: Bool

    private var reviewedCards: Int { ankiCards.filter { !$0.ratingHistory.isEmpty }.count }
    private var strugglingCards: Int { ankiCards.filter { $0.isStruggling }.count }
    /// Dominadas: mínimo 5 repasos y tasa de olvido <= 20%
    private var dominatedCards: Int { ankiCards.filter { $0.ratingHistory.count >= 5 && $0.ankiErrorRate <= 0.2 }.count }
    private var totalFailures: Int { ankiCards.reduce(0) { $0 + $1.ratingHistory.filter { $0 < 3 }.count } }
    private var accuracy: Double {
        totalReviews > 0 ? Double(totalReviews - totalFailures) / Double(totalReviews) : 0
    }

    var body: some View {
        AeroSurfaceCard {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 10)
                        .frame(width: 90, height: 90)
                    Circle()
                        .trim(from: 0, to: CGFloat(accuracy))
                        .stroke(
                            LinearGradient(colors: [.teal, .cyan], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: accuracy)
                    Text("\(Int(accuracy * 100))%")
                        .font(.title3).fontWeight(.bold)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Retención Anki")
                        .font(isLargeCanvas ? .title3 : .headline)
                    StatRow(label: "Total repasos", value: "\(totalReviews)")
                    StatRow(label: "Recordadas", value: "\(totalReviews - totalFailures)", color: .green)
                    StatRow(label: "Olvidadas", value: "\(totalFailures)", color: .red)
                    StatRow(label: "Tarjetas revisadas", value: "\(reviewedCards) / \(ankiCards.count)")
                }
                Spacer()
            }

            if strugglingCards > 0 || dominatedCards > 0 {
                Divider().padding(.top, 8)
                HStack(spacing: 16) {
                    if strugglingCards > 0 {
                        Label("\(strugglingCards) difíciles", systemImage: "exclamationmark.circle.fill")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.red)
                    }
                    if dominatedCards > 0 {
                        Label("\(dominatedCards) dominadas", systemImage: "checkmark.circle.fill")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.teal)
                    }
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
    }
}

struct AnkiGapCardView: View {
    let gap: ConceptGap
    let isLargeCanvas: Bool
    @State private var isExpanded = false

    private var severityColor: Color {
        gap.error_rate >= 0.7 ? .red : gap.error_rate >= 0.5 ? .orange : Color(red: 0.9, green: 0.6, blue: 0)
    }
    private var severityLabel: String {
        gap.error_rate >= 0.7 ? "Muy difícil" : gap.error_rate >= 0.5 ? "Difícil" : "Moderado"
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { isExpanded.toggle() }
        } label: {
            AeroSurfaceCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(severityColor.opacity(0.12)).frame(width: 50, height: 50)
                            Text("\(Int(gap.error_rate * 100))%")
                                .font(.subheadline).fontWeight(.bold).foregroundStyle(severityColor)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(gap.concept.capitalized)
                                    .font(isLargeCanvas ? .subheadline : .callout).fontWeight(.semibold)
                                Text(severityLabel)
                                    .font(.caption2).fontWeight(.bold)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(severityColor.opacity(0.1)).foregroundStyle(severityColor)
                                    .clipShape(Capsule())
                            }
                            Text("\(gap.errors) veces olvidado de \(gap.total_attempts) repasos")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    }

                    if isExpanded {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Tasa de olvido").font(.caption2).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(gap.error_rate * 100))%").font(.caption2).fontWeight(.semibold).foregroundStyle(severityColor)
                                }
                                ProgressView(value: gap.error_rate).tint(severityColor)
                            }

                            HStack(spacing: 6) {
                                Label("\(gap.total_attempts - gap.errors) recordadas", systemImage: "checkmark.circle.fill")
                                    .font(.caption2).foregroundStyle(.teal)
                                Spacer()
                                Label("\(gap.errors) olvidadas", systemImage: "xmark.circle.fill")
                                    .font(.caption2).foregroundStyle(.red)
                            }

                            GeometryReader { geo in
                                HStack(spacing: 2) {
                                    Rectangle()
                                        .fill(Color.teal.opacity(0.7))
                                        .frame(width: geo.size.width * CGFloat(1 - gap.error_rate), height: 6)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                    Rectangle()
                                        .fill(Color.red.opacity(0.7))
                                        .frame(width: geo.size.width * CGFloat(gap.error_rate), height: 6)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                            }
                            .frame(height: 6)

                            Text("Consejo: repasa este concepto con mayor frecuencia. Aparecerá antes en tu cola Anki.")
                                .font(.caption2).foregroundStyle(.secondary)
                                .italic()
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
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
    let isLargeCanvas: Bool
    @State private var isExpanded = false

    private var severityColor: Color {
        gap.error_rate >= 0.7 ? .red : gap.error_rate >= 0.5 ? .orange : Color(red: 0.9, green: 0.6, blue: 0)
    }

    private var severityLabel: String {
        gap.error_rate >= 0.7 ? "Crítico" : gap.error_rate >= 0.5 ? "Alto" : "Moderado"
    }

    private func errorTypeLabel(_ type: ErrorType) -> String {
        switch type {
        case .conceptual: return "Error conceptual — no comprende el concepto"
        case .memoria: return "Falta de memoria — no lo recuerda"
        case .confusion: return "Confusión — mezcla con otro concepto"
        case .incompleto: return "Respuesta incompleta — le falta detalle"
        }
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { isExpanded.toggle() }
        } label: {
            AeroSurfaceCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(severityColor.opacity(0.12)).frame(width: 50, height: 50)
                            Text("\(Int(gap.error_rate * 100))%")
                                .font(.subheadline).fontWeight(.bold).foregroundStyle(severityColor)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(gap.concept.capitalized)
                                    .font(isLargeCanvas ? .subheadline : .callout)
                                    .fontWeight(.semibold)
                                Text(severityLabel)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(severityColor.opacity(0.1))
                                    .foregroundStyle(severityColor)
                                    .clipShape(Capsule())
                            }
                            Text("\(gap.errors) errores de \(gap.total_attempts) intentos")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    }

                    if isExpanded {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            // Barra de error rate
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Tasa de error")
                                        .font(.caption2).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(gap.error_rate * 100))%")
                                        .font(.caption2).fontWeight(.semibold).foregroundStyle(severityColor)
                                }
                                ProgressView(value: gap.error_rate)
                                    .tint(severityColor)
                            }

                            if let det = gap.dominant_error_type {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.bubble.fill")
                                        .font(.caption).foregroundStyle(.orange)
                                    Text(errorTypeLabel(det))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }

                            if let lastSeen = gap.last_seen {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock").font(.caption2).foregroundStyle(.secondary)
                                    Text("Último intento: \(lastSeen.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }

                            // Mini progress bar aciertos vs errores
                            let successRate = 1.0 - gap.error_rate
                            HStack(spacing: 6) {
                                Label("\(gap.total_attempts - gap.errors) correctos", systemImage: "checkmark.circle.fill")
                                    .font(.caption2).foregroundStyle(.green)
                                Spacer()
                                Label("\(gap.errors) errores", systemImage: "xmark.circle.fill")
                                    .font(.caption2).foregroundStyle(.red)
                            }
                            GeometryReader { geo in
                                HStack(spacing: 2) {
                                    Rectangle()
                                        .fill(Color.green.opacity(0.7))
                                        .frame(width: geo.size.width * CGFloat(successRate), height: 6)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                    Rectangle()
                                        .fill(Color.red.opacity(0.7))
                                        .frame(width: geo.size.width * CGFloat(gap.error_rate), height: 6)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
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

// MARK: - Generate From Gaps Sheet

struct GenerateFromGapsSheet: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Tras guardar desde la revisión (p. ej. ir a la pestaña Flashcards / Anki).
    var onCardsSaved: (() -> Void)?

    @State private var drafts: [EditableFlashcard] = []
    @State private var navigateReview = false
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var generationProgress: CGFloat = 0
    @State private var generationStatus = "Preparando..."

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var typeScale: AeroTypeScale { AeroTypeScale.make(isLargeCanvas: isLargeCanvas) }

    /// Misma lógica que `GapAnalysis.reinforcementGaps`: examen agregado, fallback por fallos, o Anki.
    private var gaps: [ConceptGap] {
        viewModel.reinforcementGaps
    }

    init(viewModel: StudyDetailViewModel, onCardsSaved: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onCardsSaved = onCardsSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AeroAppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        // Info header
                        AeroSurfaceCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.title3)
                                        .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    Text("Refuerzo inteligente")
                                        .font(.headline)
                                }
                                Text("La IA generará flashcards específicas para los conceptos donde tienes más dificultad.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if gaps.isEmpty {
                            AeroSurfaceCard {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.largeTitle).foregroundStyle(.green)
                                    Text("¡Sin lagunas detectadas!")
                                        .font(.headline)
                                    Text("Practica más tarjetas para que el análisis detecte conceptos a reforzar.")
                                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Conceptos a reforzar (\(min(gaps.count, 5)))")
                                    .font(.headline)
                                    .padding(.horizontal, 2)
                                ForEach(gaps.prefix(5)) { gap in
                                    AeroSurfaceCard {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.orange.opacity(0.12))
                                                    .frame(width: 40, height: 40)
                                                Text("\(Int(gap.error_rate * 100))%")
                                                    .font(.caption).fontWeight(.bold).foregroundStyle(.orange)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(gap.concept.capitalized)
                                                    .font(.subheadline).fontWeight(.medium)
                                                if let det = gap.dominant_error_type {
                                                    Text(det.rawValue.capitalized)
                                                        .font(.caption2).foregroundStyle(.secondary)
                                                }
                                            }
                                            Spacer()
                                            Text("\(gap.errors)/\(gap.total_attempts) errores")
                                                .font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }

                        if let generationError {
                            AeroSurfaceCard {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                                    Text(generationError).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, isLargeCanvas ? 24 : 16)
                    .padding(.vertical, 12)
                }
                .allowsHitTesting(!isGenerating)
                .blur(radius: isGenerating ? 3 : 0)

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
            .navigationTitle("Generar desde lagunas")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.fetchContent() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.disabled(isGenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await runGeneration() }
                    } label: {
                        Label("Generar", systemImage: "sparkles")
                    }
                    .disabled(gaps.isEmpty || viewModel.resources.isEmpty || isGenerating)
                }
            }
            .navigationDestination(isPresented: $navigateReview) {
                ReviewGeneratedFlashcardsView(
                    viewModel: viewModel,
                    drafts: $drafts,
                    onFinish: {
                        navigateReview = false
                        onCardsSaved?()
                        dismiss()
                    },
                    alsoSaveAsAnkiCards: true
                )
            }
        }
    }

    private func runGeneration() async {
        isGenerating = true
        generationError = nil
        generationProgress = 0.05
        generationStatus = "Analizando lagunas..."

        let payload = viewModel.resources.map { (id: $0.id, title: $0.title, content: $0.content) }

        do {
            let result = try await IntelligentStudyAssistant.generateFlashcardsFromGaps(
                gaps: gaps,
                resources: payload,
                onProgress: { progress in
                    Task { @MainActor in
                        let total = max(1, progress.totalChunks)
                        let chunk = Double(progress.completedChunks) / Double(total)
                        generationProgress = CGFloat(0.05 + 0.85 * chunk)
                        generationStatus = progress.completedChunks < total
                            ? "Generando parte \(progress.completedChunks + 1) de \(total)..."
                            : "Finalizando..."
                    }
                }
            )
            generationProgress = 1.0
            generationStatus = "¡Listo!"
            try? await Task.sleep(for: .milliseconds(400))
            drafts = result
            isGenerating = false
            if result.isEmpty {
                generationError = "No se generaron tarjetas. Asegúrate de tener recursos con contenido relevante."
            } else {
                navigateReview = true
            }
        } catch {
            generationError = error.localizedDescription
            isGenerating = false
        }
    }
}

// MARK: - Generate resources from gaps

struct GenerateResourcesFromGapsSheet: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var onResourcesSaved: (() -> Void)?

    @State private var drafts: [GeneratedGapResourceDraft] = []
    @State private var navigateReview = false
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var generationProgress: CGFloat = 0
    @State private var generationStatus = "Preparando..."

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var typeScale: AeroTypeScale { AeroTypeScale.make(isLargeCanvas: isLargeCanvas) }

    private var gaps: [ConceptGap] { viewModel.reinforcementGaps }

    init(viewModel: StudyDetailViewModel, onResourcesSaved: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onResourcesSaved = onResourcesSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AeroAppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        AeroSurfaceCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.aeroNavy)
                                    Text("Recursos de refuerzo")
                                        .font(.headline)
                                }
                                Text("La IA redactará apuntes enfocados en tus lagunas, usando tus recursos como base. Podrás revisarlos antes de guardarlos.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if gaps.isEmpty {
                            AeroSurfaceCard {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.largeTitle).foregroundStyle(.green)
                                    Text("¡Sin lagunas detectadas!")
                                        .font(.headline)
                                    Text("Practica más para que el análisis detecte conceptos a reforzar.")
                                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Lagunas consideradas (\(min(gaps.count, 5)))")
                                    .font(.headline)
                                    .padding(.horizontal, 2)
                                ForEach(gaps.prefix(5)) { gap in
                                    AeroSurfaceCard {
                                        HStack(spacing: 12) {
                                            Text("\(Int(gap.error_rate * 100))%")
                                                .font(.caption).fontWeight(.bold).foregroundStyle(.orange)
                                                .frame(width: 36)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(gap.concept.capitalized)
                                                    .font(.subheadline).fontWeight(.medium)
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }

                        if let generationError {
                            AeroSurfaceCard {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                                    Text(generationError).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, isLargeCanvas ? 24 : 16)
                    .padding(.vertical, 12)
                }
                .allowsHitTesting(!isGenerating)
                .blur(radius: isGenerating ? 3 : 0)

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
            .navigationTitle("Recursos desde lagunas")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.fetchContent()
                IntelligentStudyAssistant.prewarm()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.disabled(isGenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await runGeneration() }
                    } label: {
                        Label("Generar", systemImage: "sparkles")
                    }
                    .disabled(gaps.isEmpty || viewModel.resources.isEmpty || isGenerating)
                }
            }
            .navigationDestination(isPresented: $navigateReview) {
                ReviewGeneratedGapResourcesView(
                    viewModel: viewModel,
                    drafts: $drafts,
                    onFinish: {
                        navigateReview = false
                        onResourcesSaved?()
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
        generationStatus = "Leyendo material..."

        let payload = viewModel.resources.map { (id: $0.id, title: $0.title, content: $0.content) }

        do {
            let result = try await IntelligentStudyAssistant.generateResourcesFromGaps(
                gaps: gaps,
                resources: payload,
                onProgress: { progress in
                    Task { @MainActor in
                        let total = max(1, progress.totalChunks)
                        let chunk = Double(progress.completedChunks) / Double(total)
                        generationProgress = CGFloat(0.05 + 0.85 * chunk)
                        generationStatus = progress.completedChunks < total ? "Redactando apuntes..." : "Finalizando..."
                    }
                }
            )
            generationProgress = 1.0
            generationStatus = "¡Listo!"
            try? await Task.sleep(for: .milliseconds(400))
            drafts = result
            isGenerating = false
            if result.isEmpty {
                generationError = "No se generaron recursos. Comprueba que tus recursos tengan texto suficiente."
            } else {
                navigateReview = true
            }
        } catch {
            generationError = error.localizedDescription
            isGenerating = false
        }
    }
}

private struct ReviewGeneratedGapResourcesView: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    @Binding var drafts: [GeneratedGapResourceDraft]
    var onFinish: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }

    var body: some View {
        ZStack {
            AeroAppBackground()

            List {
                if let errorMessage {
                    Section {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                            Text(errorMessage).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                }

                ForEach($drafts) { $item in
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(item.gapConcept)
                                    .font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Spacer()
                                Toggle("Incluir", isOn: $item.isIncluded)
                                    .labelsHidden()
                                    .tint(Color.aeroNavy)
                            }
                            TextField("Título", text: $item.title)
                                .font(.headline)
                            TextEditor(text: $item.content)
                                .frame(minHeight: isLargeCanvas ? 200 : 160)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { drafts.remove(atOffsets: $0) }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Revisar recursos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar en Recursos") {
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
            errorMessage = "Incluye al menos un recurso."
            isSaving = false
            return
        }
        viewModel.saveGapResourceBatch(included)
        isSaving = false
        onFinish()
    }
}

// MARK: - Add Resource View

struct AddResourceView: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showFileImporter = false
    @State private var isExtracting = false
    @State private var importError: String?

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var contentWidth: CGFloat {
        isLargeCanvas ? AeroAdaptiveLayout.maxRegularContentWidth : AeroAdaptiveLayout.maxCompactContentWidth
    }

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
                            .frame(minHeight: isLargeCanvas ? 280 : 200)
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
            .frame(maxWidth: contentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var question = ""
    @State private var answer = ""
    @State private var tagsText = ""
    @State private var cardType: FlashcardType = .open
    @State private var selectedResourceId: UUID?
    @State private var distractor1 = ""
    @State private var distractor2 = ""
    @State private var distractor3 = ""
    @State private var isSaving = false

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var contentWidth: CGFloat {
        isLargeCanvas ? AeroAdaptiveLayout.maxRegularContentWidth : AeroAdaptiveLayout.maxCompactContentWidth
    }

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
                                .foregroundColor(Color.aeroNavy)
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
                    .controlSize(isLargeCanvas ? .large : .regular)
                } header: {
                    Text("Tipo de tarjeta")
                }

                Section {
                    TextEditor(text: $question)
                        .frame(minHeight: isLargeCanvas ? 120 : 80)
                } header: {
                    Text("Pregunta")
                }

                Section {
                    TextEditor(text: $answer)
                        .frame(minHeight: isLargeCanvas ? 100 : 60)
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
            .frame(maxWidth: contentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
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
    .modelContainer(for: [SDStudy.self, SDStudyBoard.self, SDResource.self, SDFlashcard.self, SDAttempt.self, SDAnkiCard.self], inMemory: true)
}
#endif
