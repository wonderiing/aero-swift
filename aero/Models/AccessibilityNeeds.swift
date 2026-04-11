import Foundation

/// Necesidades leídas desde `UserDefaults` / `@AppStorage("accessibilityNeeds")` (CSV).
struct AccessibilityNeeds: Sendable, Hashable {
    let rawValue: String

    init(_ csv: String) {
        self.rawValue = csv
    }

    private var tokens: Set<String> {
        Set(
            rawValue
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    var hasADHD: Bool { tokens.contains("adhd") }
    var hasAutism: Bool { tokens.contains("autism") }
    var hasDyslexia: Bool { tokens.contains("dyslexia") }
    var hasLowVision: Bool { tokens.contains("low_vision") }
}
