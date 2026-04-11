import SwiftUI
import SwiftData

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("textSize") private var textSize: String = "normal" // normal | large | extraLarge
    @AppStorage("accessibilityNeeds") private var accessibilityNeeds: String = ""
    @AppStorage("reduceMotion") private var reduceMotion: String = "auto" // auto | on | off
    @AppStorage("focusMode") private var focusMode: Bool = false
    /// system | light | dark
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemePreference.lowercased() {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var needs: Set<String> {
        Set(accessibilityNeeds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    private var effectiveDynamicType: DynamicTypeSize? {
        // Manual override wins; accessibility needs can bump it up.
        switch textSize.lowercased() {
        case "large":
            return .large
        case "extraLarge", "extralarge", "muy_grande":
            return .xLarge
        default:
            if needs.contains("low_vision") { return .accessibility3 }
            if needs.contains("dyslexia") { return .xLarge }
            return nil
        }
    }

    private var effectiveReduceMotion: Bool {
        switch reduceMotion.lowercased() {
        case "on": return true
        case "off": return false
        default: return systemReduceMotion
        }
    }

    private var wantsHighContrast: Bool {
        needs.contains("low_vision")
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                StudyListView()
            } else {
                OnboardingFlowView()
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .tint(Color.aeroNavy)
        .modifier(DynamicTypeOverride(dynamicType: effectiveDynamicType))
        .environment(\.imageScale, wantsHighContrast ? .large : .medium)
        .environment(\.legibilityWeight, wantsHighContrast ? .bold : .regular)
        .contrast(wantsHighContrast ? 1.15 : 1.0)
        .modifier(ReduceMotionOverride(enabled: effectiveReduceMotion))
    }
}

private struct DynamicTypeOverride: ViewModifier {
    let dynamicType: DynamicTypeSize?

    func body(content: Content) -> some View {
        if let dynamicType {
            content.dynamicTypeSize(dynamicType ... .accessibility5)
        } else {
            content
        }
    }
}

private struct ReduceMotionOverride: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        content.transaction { txn in
            if enabled {
                txn.disablesAnimations = true
            }
        }
    }
}
