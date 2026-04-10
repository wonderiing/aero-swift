import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    
    init() {
        if KeychainTokenStore.hasAccessToken {
            isAuthenticated = true
        }
    }
}

struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                StudyListView()
            } else {
                AuthView()
            }
        }
        .environmentObject(appState)
    }
}

#Preview("Raíz — sin sesión") {
    ContentView()
}

#Preview("Lista (como autenticado)") {
    let app = AppState()
    app.isAuthenticated = true
    return StudyListView()
        .environmentObject(app)
}
