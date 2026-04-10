import SwiftUI

struct ResourceDetailView: View {
    @ObservedObject var studyViewModel: StudyDetailViewModel
    let resource: SDResource

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var errorMessage: String?

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var contentWidth: CGFloat {
        isLargeCanvas ? AeroAdaptiveLayout.maxRegularContentWidth : AeroAdaptiveLayout.maxCompactContentWidth
    }

    var body: some View {
        ZStack {
            AeroAppBackground()

            ScrollView {
                VStack(spacing: 14) {
                    AeroSurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Título", systemImage: "textformat")
                                .font(.headline)
                            TextField("Título", text: $title)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    AeroSurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Contenido", systemImage: "doc.text")
                                .font(.headline)
                            TextEditor(text: $content)
                                .frame(minHeight: isLargeCanvas ? 360 : 240)
                                .padding(8)
                                .background(Color.aeroSecondaryBackground.opacity(0.8))
                                .clipShape(.rect(cornerRadius: 12))
                        }
                    }

                    if let errorMessage {
                        AeroSurfaceCard {
                            HStack(spacing: 10) {
                                Image(systemName: "xmark.octagon.fill")
                                    .foregroundStyle(.red)
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal, isLargeCanvas ? 24 : 16)
                .padding(.vertical, 14)
                .frame(maxWidth: contentWidth)
                .frame(maxWidth: .infinity, alignment: .center)
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
