import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @AppStorage("userName") private var userName: String = ""
    @AppStorage("sessionStyle") private var sessionStyle: String = ""
    @AppStorage("accessibilityNeeds") private var accessibilityNeeds: String = ""

    @AppStorage("focusMode") private var focusMode: Bool = false
    @AppStorage("reduceMotion") private var reduceMotion: String = "auto" // auto | on | off
    @AppStorage("textSize") private var textSize: String = "normal" // normal | large | extraLarge

    @State private var nameDraft: String = ""

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Form {
            Section("Perfil") {
                TextField("Nombre", text: $nameDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveName() }
                Button("Guardar nombre") { saveName() }
                    .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Estilo de estudio") {
                ForEach(sessionOptions) { opt in
                    MultipleSelectionRow(
                        title: opt.title,
                        systemImage: opt.systemImage,
                        isSelected: selectedSession.contains(opt.key)
                    ) {
                        toggleSession(opt.key)
                    }
                }
            }

            Section("Accesibilidad") {
                ForEach(accessibilityOptions) { opt in
                    MultipleSelectionRow(
                        title: opt.title,
                        systemImage: opt.systemImage,
                        isSelected: selectedAccessibility.contains(opt.key)
                    ) {
                        toggleAccessibility(opt.key)
                    }
                }
            }

            Section("Apariencia") {
                Toggle("Modo Focus", isOn: $focusMode)
                    .onChange(of: focusMode) { _, _ in syncProfile() }

                Picker("Reducir movimiento", selection: $reduceMotion) {
                    Text("AUTO").tag("auto")
                    Text("ON").tag("on")
                    Text("OFF").tag("off")
                }
                .onChange(of: reduceMotion) { _, _ in syncProfile() }

                Picker("Tamaño de texto", selection: $textSize) {
                    Text("Normal").tag("normal")
                    Text("Grande").tag("large")
                    Text("Muy grande").tag("extraLarge")
                }
                .onChange(of: textSize) { _, _ in syncProfile() }
            }
        }
        .navigationTitle("Configuración")
        .onAppear {
            nameDraft = userName.isEmpty ? (profile?.name ?? "") : userName
            if userName.isEmpty, let p = profile, !p.name.isEmpty {
                userName = p.name
            }
        }
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
}

private let sessionOptions: [SettingsOption] = [
    .init(key: "short_sessions", systemImage: "timer", title: "Sesiones cortas"),
    .init(key: "long_sessions", systemImage: "book.fill", title: "Sesiones largas"),
    .init(key: "prefer_audio", systemImage: "headphones", title: "Prefiero escuchar"),
    .init(key: "prefer_writing", systemImage: "pencil", title: "Prefiero escribir")
]

private let accessibilityOptions: [SettingsOption] = [
    .init(key: "adhd", systemImage: "brain.head.profile", title: "TDAH"),
    .init(key: "autism", systemImage: "figure.mind.and.body", title: "Autismo"),
    .init(key: "dyslexia", systemImage: "text.book.closed", title: "Dislexia"),
    .init(key: "low_vision", systemImage: "eye", title: "Baja visión")
]

private struct MultipleSelectionRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
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

