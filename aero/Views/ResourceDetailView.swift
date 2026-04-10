import SwiftUI

struct ResourceDetailView: View {
    @ObservedObject var studyViewModel: StudyDetailViewModel
    let resource: SDResource

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var content: String = ""
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
                    studyViewModel.updateResource(id: resource.id, title: title, content: content)
                    dismiss()
                }
                .disabled(title.count < 3 || content.isEmpty)
            }
        }
        .onAppear {
            title = resource.title
            content = resource.content
        }
    }
}
