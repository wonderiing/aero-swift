import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @AppStorage("userName") private var userName: String = ""
    @AppStorage("sessionStyle") private var sessionStyle: String = ""
    @AppStorage("accessibilityNeeds") private var accessibilityNeeds: String = ""

    @AppStorage("focusMode") private var focusMode: Bool = false
    @AppStorage("reduceMotion") private var reduceMotion: String = "auto" // auto | on | off
    @AppStorage("textSize") private var textSize: String = "normal" // normal | large | extraLarge
    /// system | light | dark
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @AppStorage("podcastEnabled") private var podcastEnabled: Bool = false

    @State private var nameDraft: String = ""

    private var profile: UserProfile? { profiles.first }
    private var isWide: Bool { horizontalSizeClass == .regular }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.aeroNavy, Color.aeroLavender],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: isWide ? 72 : 60, height: isWide ? 72 : 60)
                        Text(profileInitials)
                            .font(isWide ? .title2 : .title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tu espacio de estudio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        TextField("Nombre", text: $nameDraft)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .onSubmit { saveName() }
                        Button("Guardar nombre") { saveName() }
                            .buttonStyle(AeroSecondaryButtonStyle())
                            .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Label("Perfil", systemImage: "person.crop.circle")
            } footer: {
                Text("Usamos tu nombre para saludarte y personalizar la lista de estudios.")
            }

            Section {
                ForEach(sessionOptions) { opt in
                    MultipleSelectionRow(
                        title: opt.title,
                        subtitle: opt.subtitle,
                        systemImage: opt.systemImage,
                        isSelected: selectedSession.contains(opt.key)
                    ) {
                        toggleSession(opt.key)
                    }
                }
            } header: {
                Label("Estilo de estudio", systemImage: "slider.horizontal.3")
            } footer: {
                Text("Puedes combinar varias opciones. La app ajusta el número de tarjetas, el tipo de preguntas y el formato del contenido.")
            }

            Section {
                ForEach(accessibilityOptions) { opt in
                    MultipleSelectionRow(
                        title: opt.title,
                        subtitle: opt.subtitle,
                        systemImage: opt.systemImage,
                        isSelected: selectedAccessibility.contains(opt.key)
                    ) {
                        toggleAccessibility(opt.key)
                    }
                }
            } header: {
                Label("¿Cómo aprendes mejor?", systemImage: "accessibility")
            } footer: {
                Text("Usamos estas preferencias para adaptar el lenguaje, el ritmo y el formato del contenido generado con IA.")
            }

            Section {
                Toggle("Modo Podcast", isOn: $podcastEnabled)
                    .onChange(of: podcastEnabled) { _, _ in syncProfile() }
            } header: {
                Label("Audio", systemImage: "headphones")
            } footer: {
                Text("Activa el modo podcast para escuchar tus recursos como audio narrado. Ideal si prefieres aprender escuchando.")
            }

            Section {
                Picker("Tema de la app", selection: $colorSchemePreference) {
                    Text("Sistema").tag("system")
                    Text("Claro").tag("light")
                    Text("Oscuro").tag("dark")
                }

                Toggle("Modo Focus", isOn: $focusMode)
                    .onChange(of: focusMode) { _, _ in syncProfile() }

                Picker("Reducir movimiento", selection: $reduceMotion) {
                    Text("Automático").tag("auto")
                    Text("Sí").tag("on")
                    Text("No").tag("off")
                }
                .onChange(of: reduceMotion) { _, _ in syncProfile() }

                Picker("Tamaño de texto", selection: $textSize) {
                    Text("Normal").tag("normal")
                    Text("Grande").tag("large")
                    Text("Muy grande").tag("extraLarge")
                }
                .onChange(of: textSize) { _, _ in syncProfile() }
            } header: {
                Label("Apariencia", systemImage: "sparkles")
            } footer: {
                Text("El tema solo afecta a esta app — «Sistema» sigue el ajuste de iOS/iPadOS. Modo Focus oculta distracciones visuales durante el estudio.")
            }
        }
        .navigationTitle("Configuración")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Listo") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            nameDraft = userName.isEmpty ? (profile?.name ?? "") : userName
            if userName.isEmpty, let p = profile, !p.name.isEmpty {
                userName = p.name
            }
        }
    }

    private var profileInitials: String {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? userName : trimmed
        let parts = source.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            let a = parts[0].prefix(1)
            let b = parts[1].prefix(1)
            return "\(a)\(b)".uppercased()
        }
        if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "AE"
    }

    private var selectedSession: Set<String> { Set(parseCSV(sessionStyle)) }
    private var selectedAccessibility: Set<String> { Set(parseCSV(accessibilityNeeds)) }

    private func toggleSession(_ key: String) {
        var s = selectedSession
        if s.contains(key) { s.remove(key) } else { s.insert(key) }
        sessionStyle = toCSV(Array(s))
        syncProfile()
    }

    private func toggleAccessibility(_ key: String) {
        var s = selectedAccessibility
        if s.contains(key) { s.remove(key) } else { s.insert(key) }
        accessibilityNeeds = toCSV(Array(s))
        syncProfile()
    }

    private func saveName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        userName = trimmed.isEmpty ? "Estudiante" : trimmed
        syncProfile()
    }

    private func syncProfile() {
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Estudiante" : userName
        let sess = parseCSV(sessionStyle)
        let acc = parseCSV(accessibilityNeeds)

        let p = profile ?? UserProfile(name: name)
        p.name = name
        p.sessionStyle = sess
        p.accessibilityNeeds = acc
        p.updatedAt = Date()

        if p.modelContext == nil { modelContext.insert(p) }
        try? modelContext.save()
    }
}

private struct SettingsOption: Identifiable {
    let id = UUID()
    let key: String
    let systemImage: String
    let title: String
    var subtitle: String? = nil
}

private let sessionOptions: [SettingsOption] = [
    .init(key: "short_sessions",  systemImage: "timer",     title: "Sesiones cortas",    subtitle: "Máximo 10 tarjetas por sesión"),
    .init(key: "long_sessions",   systemImage: "book.fill", title: "Sesiones largas",    subtitle: "Sin límite — repasa todo lo pendiente de una vez"),
    .init(key: "prefer_audio",    systemImage: "headphones",title: "Prefiero escuchar",  subtitle: "Activa el podcast automáticamente al abrir un estudio"),
    .init(key: "prefer_writing",  systemImage: "pencil",    title: "Prefiero escribir",  subtitle: "Prioriza preguntas de respuesta abierta sobre opción múltiple")
]

private let accessibilityOptions: [SettingsOption] = [
    .init(key: "adhd",       systemImage: "brain.head.profile",    title: "Me cuesta mantener el foco",                subtitle: "Feedbacks más cortos y directos, sesiones más breves"),
    .init(key: "autism",     systemImage: "figure.mind.and.body",  title: "Prefiero instrucciones claras y literales",  subtitle: "El contenido evitará metáforas, sarcasmo y lenguaje ambiguo"),
    .init(key: "dyslexia",   systemImage: "text.book.closed",      title: "Leer texto seguido me resulta difícil",      subtitle: "Se activa el modo podcast para escuchar los recursos"),
    .init(key: "low_vision", systemImage: "eye",                   title: "Tengo dificultad con texto pequeño",         subtitle: "Aumenta el tamaño de texto y el contraste en la app")
]

private struct MultipleSelectionRow: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, subtitle != nil ? 8 : 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Activado" : "Desactivado")
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
