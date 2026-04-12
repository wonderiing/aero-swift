import Foundation
import AVFoundation
import Combine

// MARK: - Section model

struct PodcastSection: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}

// MARK: - Shared state (lives in environment, survives minimizing the full player)

@MainActor
final class PodcastPlayerState: ObservableObject {
    @Published var activePlayer: StudyPodcastPlayerViewModel?
    @Published var isFullPlayerPresented: Bool = false

    /// True when a podcast is loaded (playing, paused, or finished).
    var isActive: Bool { activePlayer != nil }

    func start(study: SDStudy) {
        activePlayer?.stop()
        let vm = StudyPodcastPlayerViewModel(study: study)
        activePlayer = vm
        isFullPlayerPresented = true
        vm.play()
    }

    func dismiss() {
        isFullPlayerPresented = false
        // Audio keeps playing — mini player visible.
    }

    func close() {
        activePlayer?.stop()
        activePlayer = nil
        isFullPlayerPresented = false
    }
}

// MARK: - ViewModel

@MainActor
final class StudyPodcastPlayerViewModel: ObservableObject {
    let study: SDStudy

    @Published var sections: [PodcastSection] = []
    @Published var currentSectionIndex: Int = 0
    @Published var isPlaying: Bool = false
    @Published var isPaused: Bool = false
    @Published var progress: Double = 0 // 0…1 within current section
    @Published var playbackRate: Float = 1.0
    @Published var estimatedMinutes: Int = 0
    @Published var isFinished: Bool = false

    var currentSection: PodcastSection? {
        sections.indices.contains(currentSectionIndex) ? sections[currentSectionIndex] : nil
    }
    var hasNext: Bool { currentSectionIndex < sections.count - 1 }
    var sectionLabel: String {
        guard !sections.isEmpty else { return "" }
        return "\(currentSectionIndex + 1) / \(sections.count)"
    }

    // MARK: Private

    private let engine = PodcastSpeechEngine()

    init(study: SDStudy) {
        self.study = study
        buildSections()

        engine.onProgress = { [weak self] value in
            Task { @MainActor in self?.progress = value }
        }
        engine.onFinishedSection = { [weak self] in
            Task { @MainActor in self?.advanceToNextSection() }
        }
        engine.onPaused = { [weak self] in
            Task { @MainActor in
                self?.isPaused = true
                self?.isPlaying = false
            }
        }
        engine.onContinued = { [weak self] in
            Task { @MainActor in
                self?.isPaused = false
                self?.isPlaying = true
            }
        }
    }

    // MARK: Actions

    func play() {
        guard !sections.isEmpty else { return }
        if isFinished {
            // Restart from beginning
            currentSectionIndex = 0
            isFinished = false
        }
        if isPaused {
            engine.resume()
            isPaused = false
            isPlaying = true
            return
        }
        speakCurrentSection()
    }

    func pause() {
        engine.pause()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func next() {
        guard hasNext else { return }
        engine.stop()
        isPaused = false
        currentSectionIndex += 1
        speakCurrentSection()
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            engine.stop()
            isPaused = false
            speakCurrentSection()
        }
    }

    func stop() {
        engine.stop()
        isPlaying = false
        isPaused = false
    }

    // MARK: Internals

    private func buildSections() {
        let sorted = study.resources.sorted { $0.createdAt < $1.createdAt }
        var result: [PodcastSection] = []

        result.append(PodcastSection(
            title: "Introduccion",
            text: "Bienvenido al repaso en audio del tema \(study.title). A continuacion escucharas un resumen por secciones, segun tus materiales."
        ))

        for r in sorted {
            let plain = AeroMarkdown.plainText(from: r.content)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !plain.isEmpty else { continue }
            result.append(PodcastSection(title: r.title, text: plain))
        }

        result.append(PodcastSection(
            title: "Cierre",
            text: "Has llegado al final del repaso de \(study.title). Sigue asi!"
        ))

        sections = result

        let fullScript = result.map(\.text).joined(separator: " ")
        estimatedMinutes = StudyPodcastScript.estimatedMinutes(forScript: fullScript)
    }

    private func speakCurrentSection() {
        guard let section = currentSection else { return }
        progress = 0
        isPlaying = true
        isPaused = false
        isFinished = false
        engine.speak(section.text, rate: playbackRate)
    }

    private func advanceToNextSection() {
        if hasNext {
            currentSectionIndex += 1
            speakCurrentSection()
        } else {
            progress = 1
            isPlaying = false
            isPaused = false
            isFinished = true
        }
    }
}

// MARK: - Speech engine (non-MainActor, owns AVSpeechSynthesizer + delegate)

private final class PodcastSpeechEngine: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var totalCharacters: Int = 0
    private let preferredVoice: AVSpeechSynthesisVoice?

    var onProgress: ((Double) -> Void)?
    var onFinishedSection: (() -> Void)?
    var onPaused: (() -> Void)?
    var onContinued: (() -> Void)?

    override init() {
        preferredVoice = Self.bestSpanishVoice()
        super.init()
        synthesizer.delegate = self
    }

    /// Picks the highest-quality Spanish voice available on-device.
    /// Priority: premium > enhanced > default; prefers es-MX, then any es-*.
    private static func bestSpanishVoice() -> AVSpeechSynthesisVoice? {
        let all = AVSpeechSynthesisVoice.speechVoices()
        let spanish = all.filter { $0.language.hasPrefix("es") }
        guard !spanish.isEmpty else { return AVSpeechSynthesisVoice(language: "es-ES") }

        func qualityRank(_ v: AVSpeechSynthesisVoice) -> Int {
            switch v.quality {
            case .premium: return 3
            case .enhanced: return 2
            default: return 1
            }
        }

        let sorted = spanish.sorted { lhs, rhs in
            let lq = qualityRank(lhs), rq = qualityRank(rhs)
            if lq != rq { return lq > rq }
            if lhs.language == "es-MX" && rhs.language != "es-MX" { return true }
            return false
        }
        return sorted.first
    }

    func speak(_ text: String, rate: Float) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredVoice ?? AVSpeechSynthesisVoice(language: "es-ES")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * rate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.25
        totalCharacters = text.count
        synthesizer.speak(utterance)
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        synthesizer.continueSpeaking()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: AVSpeechSynthesizerDelegate

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        guard totalCharacters > 0 else { return }
        let spoken = characterRange.location + characterRange.length
        onProgress?(Double(spoken) / Double(totalCharacters))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinishedSection?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        onPaused?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        onContinued?()
    }
}
