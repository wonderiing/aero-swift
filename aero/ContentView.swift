import SwiftUI

// MARK: - App Background

struct AeroAppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                Color(red: 0.10, green: 0.11, blue: 0.16)
            } else {
                Color(uiColor: .systemGroupedBackground)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Surface Card (flat, clean — Stitch style)

struct AeroSurfaceCard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorScheme == .dark ? Color(white: 0.14) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.07), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.40 : 0.06), radius: 10, y: 4)
            )
    }
}

// MARK: - Primary Button (solid navy, no gradient)

struct AeroPrimaryButtonStyle: ButtonStyle {
    var disabled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(disabled ? Color.secondary : Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(disabled ? Color.gray.opacity(0.20) : Color.aeroNavy)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button

struct AeroSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(Color.aeroNavy)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.aeroNavy.opacity(colorScheme == .dark ? 0.18 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.aeroNavy.opacity(0.25), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - Section Caption

struct AeroSectionCaption: View {
    let text: String

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.caption2).fontWeight(.semibold)
                .foregroundStyle(.secondary).tracking(1.35)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Dashed Add Card

struct AeroDashedAddResourceCard: View {
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.aeroNavy.opacity(0.08))
                        .frame(width: 52, height: 52)
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.title2).foregroundStyle(Color.aeroNavy)
                }
                VStack(spacing: 5) {
                    Text("Agregar recurso")
                        .font(.headline).foregroundStyle(Color.aeroNavy)
                    Text("PDF, imagen con OCR o texto.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.aeroNavy.opacity(colorScheme == .dark ? 0.06 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        Color.aeroNavy.opacity(0.20),
                        style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Agregar recurso")
    }
}

// MARK: - Topic Mastery Card

struct AeroTopicMasteryCard: View {
    let percent: Int
    let footnote: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DOMINIO DEL TEMA")
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.75)).tracking(1.2)
                Spacer()
                Text("+\(max(0, percent - 70))% esta semana")
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(Color.aeroMint)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.aeroMint.opacity(0.15), in: Capsule())
            }

            Text("\(percent)%")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(Color.aeroMint)
                        .frame(width: max(8, geo.size.width * min(1, max(0, progress))))
                }
            }
            .frame(height: 5)

            Text(footnote)
                .font(.caption).foregroundStyle(.white.opacity(0.80))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.aeroNavy, Color.aeroNavyDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .shadow(color: Color.aeroNavy.opacity(0.35), radius: 14, y: 6)
    }
}

// MARK: - Sidebar Row (shared between both sidebars)

struct AeroSidebarNavRow: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var badge: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.58))

                Text(title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.72))

                Spacer()

                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.aeroLavender.opacity(0.5), in: Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? Color.aeroNavy.opacity(0.65)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 9)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}
