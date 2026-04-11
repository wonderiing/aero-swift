import SwiftUI

struct ResourceDetailView: View {
    @ObservedObject var studyViewModel: StudyDetailViewModel
    let resource: SDResource

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isEditingBody = false
    @State private var errorMessage: String?
    @State private var showDiscardAlert = false

    private var hasChanges: Bool {
        title != resource.title || content != resource.content
    }

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }
    private var contentWidth: CGFloat {
        isLargeCanvas ? AeroAdaptiveLayout.maxRegularContentWidth : AeroAdaptiveLayout.maxCompactContentWidth
    }

    var body: some View {
        ZStack {
            AeroAppBackground()

            ScrollView {
                VStack(spacing: 14) {
                    // Título grande y prominente
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Título")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .padding(.horizontal, 4)
                        TextField("Título del recurso", text: $title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(uiColor: .systemBackground))
                                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                            )
                    }

                    AeroSurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Contenido", systemImage: "doc.text")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isEditingBody.toggle()
                                    }
                                } label: {
                                    Text(isEditingBody ? "Ver formato" : "Editar texto")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                                Text("\(content.count) caracteres")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            if isEditingBody {
                                TextEditor(text: $content)
                                    .frame(minHeight: 600)
                                    .scrollDisabled(true)
                                    .padding(8)
                                    .background(Color.aeroSecondaryBackground.opacity(0.8))
                                    .clipShape(.rect(cornerRadius: 12))
                            } else {
                                ScrollView {
                                    AeroMarkdownText(markdown: content)
                                        .textSelection(.enabled)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(minHeight: 400)
                                .background(Color.aeroSecondaryBackground.opacity(0.8))
                                .clipShape(.rect(cornerRadius: 12))
                            }
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
        .toolbar(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    if hasChanges { showDiscardAlert = true } else { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    studyViewModel.updateResource(id: resource.id, title: title, content: content)
                    dismiss()
                } label: {
                    Text("Guardar").fontWeight(.semibold)
                }
                .disabled(!hasChanges || title.count < 3 || content.isEmpty)
            }
        }
        .confirmationDialog("¿Descartar cambios?", isPresented: $showDiscardAlert, titleVisibility: .visible) {
            Button("Descartar cambios", role: .destructive) { dismiss() }
            Button("Seguir editando", role: .cancel) {}
        } message: {
            Text("Tienes cambios sin guardar. Si sales ahora, se perderán.")
        }
        .onAppear {
            title = resource.title
            content = resource.content
        }
    }
}
