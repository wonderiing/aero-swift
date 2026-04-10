import SwiftUI
import SwiftData

@main
struct aeroApp: App {
    var body: some Scene {
        WindowGroup {
            StudyListView()
                .onAppear {
                    IntelligentStudyAssistant.prewarm()
                }
        }
        .modelContainer(for: [SDStudy.self, SDResource.self, SDFlashcard.self, SDAttempt.self])
    }
}

#Preview("App — raíz") {
    StudyListView()
        .modelContainer(for: [SDStudy.self, SDResource.self, SDFlashcard.self, SDAttempt.self], inMemory: true)
}
