import Foundation

struct AuthResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String

    // Aliases para compatibilidad con el resto del código
    var access_token: String  { accessToken  }
    var refresh_token: String { refreshToken }
}

struct RegisterDto: Codable, Sendable {
    let username: String
    let email: String
    let password: String
}

struct LoginDto: Codable, Sendable {
    let email: String
    let password: String
}

struct LogoutResponse: Codable, Sendable {
    let message: String
}
