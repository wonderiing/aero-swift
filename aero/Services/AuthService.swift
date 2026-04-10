import Foundation

class AuthService {
    static let shared = AuthService()
    private let client = APIClient.shared

    /// Registra al usuario. Como la API devuelve 201 sin body,
    /// hace login automático con las mismas credenciales para obtener los tokens.
    func register(dto: RegisterDto) async throws {
        try await client.requestEmpty(
            endpoint: "/auth/register",
            method: "POST",
            body: dto,
            requiresAuth: false
        )
        // Login automático para conseguir access_token + refresh_token
        let loginDto = LoginDto(email: dto.email, password: dto.password)
        try await login(dto: loginDto)
    }

    func login(dto: LoginDto) async throws {
        let response: AuthResponse = try await client.request(
            endpoint: "/auth/login",
            method: "POST",
            body: dto,
            requiresAuth: false
        )
        client.setTokens(access: response.access_token, refresh: response.refresh_token)
    }

    func logout() async throws {
        try await client.requestEmpty(endpoint: "/auth/logout", method: "POST")
        client.clearTokens()
    }
}
