import SwiftUI
import SwiftData

@main
struct aeroApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .onAppear {
                    IntelligentStudyAssistant.prewarm()
                }
        }
        .modelContainer(for: [SDStudy.self, SDStudyBoard.self, SDResource.self, SDFlashcard.self, SDAttempt.self, SDAnkiCard.self, UserProfile.self])
    }
}

#Preview("App — raíz") {
    AppRootView()
        .modelContainer(for: [SDStudy.self, SDStudyBoard.self, SDResource.self, SDFlashcard.self, SDAttempt.self, SDAnkiCard.self, UserProfile.self], inMemory: true)
}
