import SwiftUI

struct StudyPodcastPlayerView: View {
    @StateObject private var viewModel: StudyPodcastPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(study: SDStudy) {
        _viewModel = StateObject(wrappedValue: StudyPodcastPlayerViewModel(study: study))
    }

    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 16)
                coverArt
                Spacer(minLength: 24)
                sectionInfo
                Spacer(minLength: 16)
                progressBar
                Spacer(minLength: 20)
                controls
                Spacer(minLength: 12)
                speedPicker
                Spacer(minLength: 8)
            }
            .frame(maxWidth: isLargeCanvas ? 480 : .infinity)
            .padding(.horizontal, isLargeCanvas ? 32 : 24)
            .padding(.vertical, 16)
        }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar reproductor")

            Spacer()

            VStack(spacing: 2) {
                Text("REPRODUCIENDO DESDE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(0.8)
                Text(viewModel.study.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear.frame(width: 40, height: 40)
        }
    }

    // MARK: - Cover

    private var coverArt: some View {
        RoundedRectangle(cornerRadius: isLargeCanvas ? 16 : 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.aeroNavy, Color.aeroLavender.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: isLargeCanvas ? 56 : 44, weight: .light))
                        .foregroundStyle(.white.opacity(0.6))
                        .symbolEffect(.variableColor.iterative, isActive: viewModel.isPlaying)

                    Text(viewModel.study.title)
                        .font(isLargeCanvas ? .title2.weight(.bold) : .title3.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 20)

                    if viewModel.estimatedMinutes > 0 {
                        Text("\(viewModel.estimatedMinutes) min aprox.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: isLargeCanvas ? 340 : 300)
            .shadow(color: .black.opacity(0.45), radius: 30, y: 14)
    }

    // MARK: - Section info

    private var sectionInfo: some View {
        VStack(spacing: 6) {
            Text(viewModel.currentSection?.title ?? "")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: viewModel.currentSectionIndex)

            Text("Seccion \(viewModel.sectionLabel)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress

    private var progressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: max(4, geo.size.width * viewModel.progress))
                }
            }
            .frame(height: 4)
            .animation(.linear(duration: 0.15), value: viewModel.progress)

            HStack {
                Text(sectionProgressLabel)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text("\(viewModel.sections.count) secciones")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private var sectionProgressLabel: String {
        let pct = Int(viewModel.progress * 100)
        return "\(pct)%"
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: isLargeCanvas ? 48 : 36) {
            Button { viewModel.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.hasPrevious ? .white : .white.opacity(0.25))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.hasPrevious)
            .accessibilityLabel("Seccion anterior")

            Button { viewModel.togglePlayPause() } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: isLargeCanvas ? 72 : 64))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.isPlaying ? "Pausar" : "Reproducir")

            Button { viewModel.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.hasNext ? .white : .white.opacity(0.25))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.hasNext)
            .accessibilityLabel("Siguiente seccion")
        }
    }

    // MARK: - Speed

    private var speedPicker: some View {
        HStack(spacing: 12) {
            ForEach(speedOptions, id: \.self) { rate in
                Button {
                    viewModel.setRate(rate)
                } label: {
                    Text(speedLabel(rate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(viewModel.playbackRate == rate ? .white : .white.opacity(0.4))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(viewModel.playbackRate == rate ? Color.white.opacity(0.18) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Velocidad \(speedLabel(rate))")
            }
        }
    }

    private let speedOptions: [Float] = [0.75, 1.0, 1.25, 1.5]

    private func speedLabel(_ rate: Float) -> String {
        if rate == 1.0 { return "1x" }
        if rate == 0.75 { return "0.75x" }
        if rate == 1.25 { return "1.25x" }
        return "1.5x"
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.10, blue: 0.28),
                Color(red: 0.04, green: 0.05, blue: 0.14),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
