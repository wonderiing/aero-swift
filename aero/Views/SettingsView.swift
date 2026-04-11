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
                        subtitle: opt.detail,
                        systemImage: opt.systemImage,
                        isSelected: selectedSession.contains(opt.key)
                    ) {
                        toggleSession(opt.key)
                    }
                }
            } header: {
                Label("Estilo de estudio", systemImage: "slider.horizontal.3")
            } footer: {
                Text("La app adapta el tamaño de la sesión y las sugerencias. Puedes combinar varias opciones; los cambios se aplican en la siguiente práctica.")
            }

            Section {
                ForEach(accessibilityOptions) { opt in
                    MultipleSelectionRow(
                        title: opt.title,
                        subtitle: opt.detail,
                        systemImage: opt.systemImage,
                        isSelected: selectedAccessibility.contains(opt.key)
                    ) {
                        toggleAccessibility(opt.key)
                    }
                }
            } header: {
                Label("Accesibilidad", systemImage: "accessibility")
            } footer: {
                Text("Cada opción activa ajustes en la práctica, la IA (tono y formato del feedback) y la interfaz. Puedes cambiarlas cuando quieras; abajo, «Reducir movimiento» y el tamaño de texto también afectan a toda la app.")
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
                Text("Modo oscuro forzado solo afecta a esta app. «Sistema» sigue el tema de iPad, iPhone o Mac.")
            }
        }
        .navigationTitle("Configuración")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Cerrar configuración")
            }
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
        let hadADHD = selectedAccessibility.contains("adhd")
        var s = selectedAccessibility
        if s.contains(key) { s.remove(key) } else { s.insert(key) }
        accessibilityNeeds = toCSV(Array(s))
        let nowADHD = s.contains("adhd")
        if !hadADHD, nowADHD {
            focusMode = true
        }
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
    let key: String
    let systemImage: String
    let title: String
    /// Texto secundario: qué cambia en la app al activar esta opción.
    let detail: String?

    var id: String { key }
}

private let sessionOptions: [SettingsOption] = [
    .init(key: "short_sessions", systemImage: "timer", title: "Sesiones cortas", detail: "Limita la cola de práctica para encajar en descansos breves."),
    .init(key: "long_sessions", systemImage: "book.fill", title: "Sesiones largas", detail: "Repasa más tarjetas seguidas cuando haya material pendiente."),
    .init(key: "prefer_audio", systemImage: "headphones", title: "Prefiero escuchar", detail: "Indica preferencia por voz; la app puede priorizar controles de audio donde ya existan."),
    .init(key: "prefer_writing", systemImage: "pencil", title: "Prefiero escribir", detail: "Indica preferencia por texto al responder cuando haya varias formas de practicar.")
]

private let accessibilityOptions: [SettingsOption] = [
    .init(
        key: "adhd",
        systemImage: "brain.head.profile",
        title: "TDAH",
        detail: "Sesión en bloques cortos con pausas, modo foco recomendado, racha visible, tiempo invertido (no cuenta atrás), feedback breve y una sola corrección prioritaria por respuesta. La IA adapta tono y longitud."
    ),
    .init(
        key: "autism",
        systemImage: "figure.mind.and.body",
        title: "Autismo (TEA)",
        detail: "Rutina y aviso antes de practicar, menos presión temporal, feedback con formato fijo y lenguaje literal, sin dependencia del color para acierto/error. La IA evita ironía y metáforas."
    ),
    .init(
        key: "dyslexia",
        systemImage: "text.book.closed",
        title: "Dislexia",
        detail: "Preguntas más cortas al generar tarjetas, tipografía y espaciado más legibles, énfasis en audio y lectura del feedback. La IA usa frases simples."
    ),
    .init(
        key: "low_vision",
        systemImage: "eye",
        title: "Baja visión",
        detail: "Texto y controles más grandes por defecto y más contraste donde la app ya lo aplica; sigue respetando el tamaño de letra del sistema."
    )
]

private struct MultipleSelectionRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .center)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                        .padding(.top, 2)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityCombinedLabel)
        .accessibilityValue(isSelected ? "Activado" : "Desactivado")
        .accessibilityHint("Doble toque para cambiar. Double tap to toggle.")
    }

    private var accessibilityCombinedLabel: String {
        if let subtitle, !subtitle.isEmpty {
            return "\(title). \(subtitle)"
        }
        return title
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

