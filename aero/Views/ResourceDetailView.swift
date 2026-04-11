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
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.aeroNavy.opacity(0.14))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "doc.text.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.aeroNavy)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Recurso de estudio")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Edita el título y el texto. Los cambios se guardan al pulsar Guardar.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            Divider()
                            Label("Título", systemImage: "textformat")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("Título", text: $title)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    AeroSurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Contenido", systemImage: "doc.text")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(content.count) caracteres")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
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
        .toolbar(.visible, for: .navigationBar)           // override parent's .hidden
        .toolbarColorScheme(.light, for: .navigationBar)  // always light, regardless of header
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancelar") { dismiss() }
                    .foregroundStyle(.secondary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    studyViewModel.updateResource(id: resource.id, title: title, content: content)
                    dismiss()
                } label: {
                    Text("Guardar").fontWeight(.semibold)
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
