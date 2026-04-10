import SwiftUI
import SwiftData

private enum OnboardingOptionStyle {
    static let selectedFill = Color.accentColor.opacity(0.12)
    static let selectedStroke = Color.accentColor.opacity(0.7)
    static let unselectedFill = Color.aeroSecondaryBackground.opacity(0.75)
    static let unselectedStroke = Color.secondary.opacity(0.25)
}

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("sessionStyle") private var sessionStyle: String = ""
    @AppStorage("accessibilityNeeds") private var accessibilityNeeds: String = ""
    @AppStorage("focusMode") private var focusMode: Bool = false
    @AppStorage("reduceMotion") private var reduceMotion: String = "auto" // auto | on | off

    @State private var step: Int = 0
    @State private var sessionSelections: Set<String> = []
    @State private var accessibilitySelections: Set<String> = []
    @State private var draftName: String = ""

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var contentWidth: CGFloat {
        isLargeCanvas ? AeroAdaptiveLayout.maxRegularContentWidth : AeroAdaptiveLayout.maxCompactContentWidth
    }

    var body: some View {
        ZStack {
            AeroAppBackground()

            VStack(spacing: 0) {
                TabView(selection: $step) {
                    OnboardingWelcomePage(isLargeCanvas: isLargeCanvas) {
                        goNext()
                    }
                    .tag(0)

                    OnboardingMultiSelectPage(
                        title: "¿Cómo prefieres estudiar?",
                        subtitle: "Puedes cambiarlo cuando quieras.",
                        isLargeCanvas: isLargeCanvas,
                        columns: 2,
                        options: [
                            .init(key: "short_sessions", systemImage: "timer", title: "Sesiones cortas", subtitle: "10–15 min"),
                            .init(key: "long_sessions", systemImage: "book.fill", title: "Sesiones largas", subtitle: "Sin límite"),
                            .init(key: "prefer_audio", systemImage: "headphones", title: "Prefiero escuchar", subtitle: "Audio en flashcards"),
                            .init(key: "prefer_writing", systemImage: "pencil", title: "Prefiero leer y escribir", subtitle: "Modo texto")
                        ],
                        selection: $sessionSelections,
                        topTrailingAction: nil,
                        primaryButtonTitle: "Siguiente"
                    ) {
                        goNext()
                    }
                    .tag(1)

                    OnboardingMultiSelectPage(
                        title: "¿Algo que debamos saber?",
                        subtitle: "Esto nos ayuda a adaptar la app para ti.",
                        isLargeCanvas: isLargeCanvas,
                        columns: 1,
                        options: [
                            .init(key: "adhd", systemImage: "brain.head.profile", title: "Tengo TDAH", subtitle: "Me cuesta mantener el foco por mucho tiempo"),
                            .init(key: "autism", systemImage: "figure.mind.and.body", title: "Estoy en el espectro autista", subtitle: "Prefiero interfaces predecibles y lenguaje claro"),
                            .init(key: "dyslexia", systemImage: "text.book.closed", title: "Tengo dislexia", subtitle: "Me cuesta leer textos largos"),
                            .init(key: "low_vision", systemImage: "eye", title: "Baja visión", subtitle: "Necesito texto más grande")
                        ],
                        selection: $accessibilitySelections,
                        topTrailingAction: .init(title: "Saltar") {
                            goNext(skipSave: true)
                        },
                        primaryButtonTitle: "Siguiente"
                    ) {
                        goNext()
                    }
                    .tag(2)

                    OnboardingNamePage(
                        isLargeCanvas: isLargeCanvas,
                        name: $draftName,
                        primaryButtonTitle: "Empezar"
                    ) {
                        finish()
                    }
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: step)
            }
            .frame(maxWidth: contentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, isLargeCanvas ? 24 : 16)
            .padding(.vertical, isLargeCanvas ? 24 : 16)
        }
        .onAppear {
            sessionSelections = Set(parseCSV(sessionStyle))
            accessibilitySelections = Set(parseCSV(accessibilityNeeds))
            draftName = userName
        }
    }

    private func goNext(skipSave: Bool = false) {
        if step == 1 {
            sessionStyle = toCSV(Array(sessionSelections))
        } else if step == 2, !skipSave {
            accessibilityNeeds = toCSV(Array(accessibilitySelections))
        }
        step = min(step + 1, 3)
    }

    private func finish() {
        let finalName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameToStore = finalName.isEmpty ? "Estudiante" : finalName

        userName = nameToStore
        sessionStyle = toCSV(Array(sessionSelections))
        accessibilityNeeds = toCSV(Array(accessibilitySelections))

        // Defaults by needs
        if accessibilitySelections.contains("adhd") {
            focusMode = true
        }
        if accessibilitySelections.contains("autism"), reduceMotion == "auto" {
            reduceMotion = "on"
        }

        let profile = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first ?? UserProfile(name: nameToStore)
        profile.name = nameToStore
        profile.sessionStyle = Array(sessionSelections)
        profile.accessibilityNeeds = Array(accessibilitySelections)
        profile.updatedAt = Date()

        if profile.modelContext == nil { modelContext.insert(profile) }
        try? modelContext.save()

        hasCompletedOnboarding = true
    }
}

private func parseCSV(_ raw: String) -> [String] {
    raw.split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

private func toCSV(_ values: [String]) -> String {
    values
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .sorted()
        .joined(separator: ",")
}

private struct OnboardingWelcomePage: View {
    let isLargeCanvas: Bool
    let onPrimary: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)

            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: isLargeCanvas ? 72 : 56, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Aprende con lo que ya tienes")
                    .font(isLargeCanvas ? .largeTitle : .title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Sube tus notas y PDFs. La IA genera flashcards, detecta en qué fallas y adapta tu estudio.")
                    .font(isLargeCanvas ? .title3 : .body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, isLargeCanvas ? 16 : 4)

            Spacer()

            Button(action: onPrimary) {
                HStack {
                    Text("Comenzar")
                    Image(systemName: "arrow.right")
                }
                .fontWeight(.semibold)
            }
            .buttonStyle(AeroPrimaryButtonStyle())
            .controlSize(isLargeCanvas ? .large : .regular)
            .accessibilityLabel("Comenzar onboarding")
        }
        .padding(isLargeCanvas ? 24 : 16)
    }
}

private struct OnboardingMultiSelectPage: View {
    struct Option: Identifiable {
        let id = UUID()
        let key: String
        let systemImage: String
        let title: String
        let subtitle: String
    }

    struct TopAction {
        let title: String
        let action: () -> Void
    }

    let title: String
    let subtitle: String
    let isLargeCanvas: Bool
    let columns: Int
    let options: [Option]
    @Binding var selection: Set<String>
    let topTrailingAction: TopAction?
    let primaryButtonTitle: String
    let onPrimary: () -> Void

    private var grid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: max(1, columns))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                if let topTrailingAction {
                    Button(topTrailingAction.title, action: topTrailingAction.action)
                        .buttonStyle(.plain)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(topTrailingAction.title)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(isLargeCanvas ? .largeTitle : .title2)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(isLargeCanvas ? .title3 : .body)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: grid, spacing: 12) {
                ForEach(options) { opt in
                    SelectCard(
                        isLargeCanvas: isLargeCanvas,
                        systemImage: opt.systemImage,
                        title: opt.title,
                        subtitle: opt.subtitle,
                        isSelected: selection.contains(opt.key)
                    ) {
                        if selection.contains(opt.key) {
                            selection.remove(opt.key)
                        } else {
                            selection.insert(opt.key)
                        }
                    }
                }
            }
            .padding(.top, 6)

            Spacer(minLength: 8)

            Button(action: onPrimary) {
                HStack {
                    Text(primaryButtonTitle)
                    Image(systemName: "arrow.right")
                }
                .fontWeight(.semibold)
            }
            .buttonStyle(AeroPrimaryButtonStyle())
            .controlSize(isLargeCanvas ? .large : .regular)
        }
        .padding(isLargeCanvas ? 24 : 16)
    }
}

private struct SelectCard: View {
    let isLargeCanvas: Bool
    let systemImage: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: systemImage)
                        .font(isLargeCanvas ? .title2 : .title3)
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(isLargeCanvas ? .title3.weight(.semibold) : .headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(isLargeCanvas ? .body : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isLargeCanvas ? 3 : 2)
            }
            .padding(isLargeCanvas ? 16 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? OnboardingOptionStyle.selectedFill : OnboardingOptionStyle.unselectedFill)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? OnboardingOptionStyle.selectedStroke : OnboardingOptionStyle.unselectedStroke, lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Seleccionado" : "No seleccionado")
        .accessibilityHint("Doble toque para cambiar la selección.")
    }
}

private struct OnboardingNamePage: View {
    let isLargeCanvas: Bool
    @Binding var name: String
    let primaryButtonTitle: String
    let onPrimary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("¿Cómo te llamamos?")
                    .font(isLargeCanvas ? .largeTitle : .title2)
                    .fontWeight(.bold)

                Text("Solo lo usamos para personalizar tu experiencia.")
                    .font(isLargeCanvas ? .title3 : .body)
                    .foregroundStyle(.secondary)
            }

            TextField("Tu nombre", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(isLargeCanvas ? .title3 : .body)
                .padding(.top, 6)

            Spacer()

            Button(action: onPrimary) {
                HStack {
                    Text(primaryButtonTitle)
                    Image(systemName: "arrow.right")
                }
                .fontWeight(.semibold)
            }
            .buttonStyle(AeroPrimaryButtonStyle())
            .controlSize(isLargeCanvas ? .large : .regular)
        }
        .padding(isLargeCanvas ? 24 : 16)
    }
}

