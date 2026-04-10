import SwiftUI
import SwiftData

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("textSize") private var textSize: String = "normal" // normal | large | extraLarge
    @AppStorage("accessibilityNeeds") private var accessibilityNeeds: String = ""
    @AppStorage("reduceMotion") private var reduceMotion: String = "auto" // auto | on | off
    @AppStorage("focusMode") private var focusMode: Bool = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

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
                StudyListHostView()
            } else {
                OnboardingFlowView()
            }
        }
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

private struct StudyListHostView: View {
    @State private var showSettings = false

    var body: some View {
        StudyListView()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Configuración")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
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

