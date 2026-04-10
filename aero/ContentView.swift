import SwiftUI

// Shared visual language for the app.
// Keeping these components in this file avoids project reference churn.

struct AeroAppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Group {
                if colorScheme == .dark {
                    LinearGradient(
                        colors: [
                            Color.aeroNavyDeep,
                            Color(red: 0.08, green: 0.09, blue: 0.14)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    LinearGradient(
                        colors: [
                            Color.aeroNavy.opacity(0.06),
                            Color.aeroGroupedBackground,
                            Color.aeroSecondaryBackground
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .ignoresSafeArea()
        }
    }
}

struct AeroSurfaceCard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var fill: Color {
        colorScheme == .dark ? Color(white: 0.12) : Color.aeroCardFill
    }

    private var strokeOpacity: Double { colorScheme == .dark ? 0.22 : 0.08 }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.primary.opacity(strokeOpacity), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.55 : 0.07), radius: colorScheme == .dark ? 20 : 14, y: colorScheme == .dark ? 10 : 6)
            )
    }
}

struct AeroPrimaryButtonStyle: ButtonStyle {
    var disabled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(disabled ? Color.secondary : Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        disabled
                        ? AnyShapeStyle(Color.gray.opacity(0.25))
                        : AnyShapeStyle(Color.aeroNavy)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

/// Secondary outline button for less prominent actions.
struct AeroSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.aeroNavy.opacity(colorScheme == .dark ? 0.35 : 0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - Atheneum-style building blocks

/// Etiqueta de sección en mayúsculas (estilo referencia UI).
struct AeroSectionCaption: View {
    let text: String

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(1.35)
            Spacer(minLength: 0)
        }
    }
}

/// Tarjeta con borde discontinuo para «subir / agregar recurso».
struct AeroDashedAddResourceCard: View {
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
                        .frame(width: 58, height: 58)
                        .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.title2)
                        .foregroundStyle(Color.aeroNavy)
                }

                VStack(spacing: 6) {
                    Text("Agregar recurso")
                        .font(.headline)
                        .foregroundStyle(Color.aeroNavy)
                    Text("PDF, imagen con OCR o texto. El texto se extrae en el dispositivo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.aeroNavy.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        Color.secondary.opacity(colorScheme == .dark ? 0.35 : 0.28),
                        style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Agregar recurso")
        .accessibilityHint("Abre el formulario para importar o pegar material de estudio.")
    }
}

/// Tarjeta de «dominio del tema» con barra de progreso (mockup Topic Mastery).
struct AeroTopicMasteryCard: View {
    let percent: Int
    let footnote: String
    let progress: Double
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dominio del tema")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.white.opacity(0.7))
                .tracking(1.2)

            Text("\(percent)%")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(Color.aeroMint)
                        .frame(width: max(8, geo.size.width * min(1, max(0, progress))))
                }
            }
            .frame(height: 6)

            Text(footnote)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.aeroNavy,
                            Color.aeroNavyDeep.opacity(colorScheme == .dark ? 1 : 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color.aeroNavy.opacity(0.35), radius: 16, y: 8)
    }
}
