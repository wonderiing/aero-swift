import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var username = ""
    @Published var isRegistering = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    
    private let authService = AuthService.shared
    
    func authenticate() async {
        isLoading = true
        errorMessage = nil
        
        do {
            if isRegistering {
                let dto = RegisterDto(username: username, email: email, password: password)
                try await authService.register(dto: dto)
            } else {
                let dto = LoginDto(email: email, password: password)
                try await authService.login(dto: dto)
            }
            isAuthenticated = true
        } catch {
            // Muestra el error completo (incluye body de la API para diagnóstico)
            errorMessage = error.localizedDescription
            print("[AuthViewModel] ❌ Error: \(error)")
        }
        
        isLoading = false
    }
    
    func logout() {
        Task {
            try? await authService.logout()
            isAuthenticated = false
            email = ""
            password = ""
            username = ""
        }
    }
    
    func checkSession() {
        if KeychainTokenStore.hasAccessToken {
            isAuthenticated = true
        }
    }
}
