import SwiftUI

// MARK: - Full-screen podcast player

struct StudyPodcastPlayerView: View {
    @EnvironmentObject private var podcastState: PodcastPlayerState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var vm: StudyPodcastPlayerViewModel? { podcastState.activePlayer }
    private var isLargeCanvas: Bool { aeroIsLargeCanvas(horizontalSizeClass: horizontalSizeClass) }

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            if let vm {
                VStack(spacing: 0) {
                    header(vm: vm)
                    Spacer(minLength: 16)
                    coverArt(vm: vm)
                    Spacer(minLength: 24)
                    sectionInfo(vm: vm)
                    Spacer(minLength: 16)
                    progressBar(vm: vm)
                    Spacer(minLength: 20)
                    controls(vm: vm)
                    Spacer(minLength: 12)
                    speedPicker(vm: vm)
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: isLargeCanvas ? 480 : .infinity)
                .padding(.horizontal, isLargeCanvas ? 32 : 24)
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Header

    private func header(vm: StudyPodcastPlayerViewModel) -> some View {
        HStack {
            Button { podcastState.dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Minimizar reproductor")

            Spacer()

            VStack(spacing: 2) {
                Text("REPRODUCIENDO DESDE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(0.8)
                Text(vm.study.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer()

            Button { podcastState.close() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar podcast")
        }
    }

    // MARK: - Cover

    private func coverArt(vm: StudyPodcastPlayerViewModel) -> some View {
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
                        .symbolEffect(.variableColor.iterative, isActive: vm.isPlaying)

                    Text(vm.study.title)
                        .font(isLargeCanvas ? .title2.weight(.bold) : .title3.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 20)

                    if vm.estimatedMinutes > 0 {
                        Text("\(vm.estimatedMinutes) min aprox.")
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

    private func sectionInfo(vm: StudyPodcastPlayerViewModel) -> some View {
        VStack(spacing: 6) {
            Text(vm.currentSection?.title ?? "")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: vm.currentSectionIndex)

            Text("Seccion \(vm.sectionLabel)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress

    private func progressBar(vm: StudyPodcastPlayerViewModel) -> some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: max(4, geo.size.width * vm.progress))
                }
            }
            .frame(height: 4)
            .animation(.linear(duration: 0.15), value: vm.progress)

            HStack {
                Text("\(Int(vm.progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text("\(vm.sections.count) secciones")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    // MARK: - Controls (play/pause + next only)

    private func controls(vm: StudyPodcastPlayerViewModel) -> some View {
        Button { vm.togglePlayPause() } label: {
            Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: isLargeCanvas ? 72 : 64))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(vm.isPlaying ? "Pausar" : "Reproducir")
    }

    // MARK: - Speed

    private func speedPicker(vm: StudyPodcastPlayerViewModel) -> some View {
        HStack(spacing: 12) {
            ForEach(speedOptions, id: \.self) { rate in
                Button {
                    vm.setRate(rate)
                } label: {
                    Text(speedLabel(rate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(vm.playbackRate == rate ? .white : .white.opacity(0.4))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(vm.playbackRate == rate ? Color.white.opacity(0.18) : Color.clear)
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

// MARK: - Mini player bar (overlay at bottom of app)

struct PodcastMiniPlayerBar: View {
    @EnvironmentObject private var podcastState: PodcastPlayerState

    var body: some View {
        if let vm = podcastState.activePlayer, !podcastState.isFullPlayerPresented {
            Button {
                podcastState.isFullPlayerPresented = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.aeroLavender)
                        .symbolEffect(.variableColor.iterative, isActive: vm.isPlaying)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.currentSection?.title ?? vm.study.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(vm.study.title)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Button {
                        vm.togglePlayPause()
                    } label: {
                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(vm.isPlaying ? "Pausar" : "Reproducir")

                    Button {
                        podcastState.close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cerrar podcast")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.10, green: 0.12, blue: 0.28))
                        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                )
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: podcastState.isActive)
        }
    }
}
