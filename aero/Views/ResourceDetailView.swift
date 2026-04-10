import SwiftUI

struct ResourceDetailView: View {
    @ObservedObject var studyViewModel: StudyDetailViewModel
    let resource: Resource

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Título") {
                TextField("Título", text: $title)
            }
            Section("Contenido") {
                TextEditor(text: $content)
                    .frame(minHeight: 220)
            }
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Recurso")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Guardar") {
                    Task { await save() }
                }
                .disabled(isSaving || title.count < 3 || content.isEmpty)
            }
        }
        .onAppear {
            title = resource.title
            content = resource.content
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await studyViewModel.updateResource(id: resource.id, title: title, content: content)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

#if DEBUG
#Preview("Detalle recurso") {
    NavigationStack {
        ResourceDetailView(
            studyViewModel: StudyDetailViewModel.previewMock(),
            resource: Resource(
                id: UUID(),
                title: "Fotosíntesis",
                content: "Texto largo de ejemplo para el editor en la vista previa de Xcode.",
                sourceName: "notas.pdf",
                createdAt: Date()
            )
        )
    }
}
#endif
