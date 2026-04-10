import Foundation

// MARK: - Errores

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(String)
    case unauthorized
    case serverError(Int, String?)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:             return "URL inválida"
        case .noData:                 return "Sin datos en la respuesta"
        case .decodingError(let m):   return "Error de decodificación: \(m)"
        case .unauthorized:           return "No autorizado (401)"
        case .serverError(let c, let b): return "Error del servidor \(c): \(b ?? "sin body")"
        case .networkError(let e):    return "Error de red: \(e.localizedDescription)"
        }
    }
}

// MARK: - Cliente

class APIClient {
    static let shared = APIClient()
    private var baseURL: String { AppConfig.apiBaseURLString }

    private init() {
        Self.migrateLegacyTokensIfNeeded()
    }

    private static func migrateLegacyTokensIfNeeded() {
        guard KeychainTokenStore.accessToken() == nil,
              let access  = UserDefaults.standard.string(forKey: "access_token"),
              let refresh = UserDefaults.standard.string(forKey: "refresh_token") else { return }
        KeychainTokenStore.save(access: access, refresh: refresh)
        UserDefaults.standard.removeObject(forKey: "access_token")
        UserDefaults.standard.removeObject(forKey: "refresh_token")
    }

    private var accessToken:  String? { KeychainTokenStore.accessToken()  }
    private var refreshToken: String? { KeychainTokenStore.refreshToken() }

    func setTokens(access: String, refresh: String) {
        KeychainTokenStore.save(access: access, refresh: refresh)
    }

    func clearTokens() {
        KeychainTokenStore.clear()
    }

    // MARK: request genérico (con body tipado)

    func request<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        requiresAuth: Bool = true,
        isRetryAfterRefresh: Bool = false
    ) async throws -> T {
        let bodyData = try encodeBody(body)
        let urlRequest = try buildRequest(endpoint: endpoint, method: method,
                                          bodyData: bodyData, requiresAuth: requiresAuth)
        let (data, response) = try await execute(urlRequest)
        let http = response as! HTTPURLResponse

        APILogger.log(request: urlRequest, response: http, data: data)

        if http.statusCode == 401 && requiresAuth && !isRetryAfterRefresh {
            if try await refreshAccessToken() {
                return try await self.request(endpoint: endpoint, method: method,
                                              body: body, requiresAuth: requiresAuth,
                                              isRetryAfterRefresh: true)
            } else {
                throw APIError.unauthorized
            }
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8)
            throw APIError.serverError(http.statusCode, bodyText)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<binario>"
            throw APIError.decodingError("\(error) | body: \(raw)")
        }
    }

    // MARK: requestEmpty (sin body de retorno — DELETE, logout, register, etc.)

    func requestEmpty(
        endpoint: String,
        method: String = "DELETE",
        body: Encodable? = nil,
        requiresAuth: Bool = true,
        isRetryAfterRefresh: Bool = false
    ) async throws {
        let bodyData = try encodeBody(body)
        let urlRequest = try buildRequest(endpoint: endpoint, method: method,
                                          bodyData: bodyData, requiresAuth: requiresAuth)
        let (data, response) = try await execute(urlRequest)
        let http = response as! HTTPURLResponse

        APILogger.log(request: urlRequest, response: http, data: data)

        if http.statusCode == 401 && requiresAuth && !isRetryAfterRefresh {
            if try await refreshAccessToken() {
                return try await self.requestEmpty(endpoint: endpoint, method: method,
                                                  body: body, requiresAuth: requiresAuth,
                                                  isRetryAfterRefresh: true)
            } else {
                throw APIError.unauthorized
            }
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8)
            throw APIError.serverError(http.statusCode, bodyText)
        }
    }

    // MARK: Privado — serialización, construcción y ejecución

    /// Serializa un `Encodable` existencial a `Data` sin necesitar un genérico.
    private func encodeBody(_ body: Encodable?) throws -> Data? {
        guard let body else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Usamos AnyEncodable para romper el requisito de conformancia genérica
        return try encoder.encode(AnyEncodable(body))
    }

    private func buildRequest(
        endpoint: String,
        method: String,
        bodyData: Data?,
        requiresAuth: Bool
    ) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            guard let token = accessToken else { throw APIError.unauthorized }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        req.httpBody = bodyData
        return req
    }

    private func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: Refresh interno

    private func refreshAccessToken() async throws -> Bool {
        guard let refresh = refreshToken else { return false }
        guard let url = URL(string: "\(baseURL)/auth/refresh") else { return false }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(refresh)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        let http = response as! HTTPURLResponse
        APILogger.log(request: req, response: http, data: data, tag: "REFRESH")

        guard http.statusCode == 200 else {
            clearTokens()
            return false
        }

        do {
            let auth = try JSONDecoder().decode(AuthResponse.self, from: data)
            setTokens(access: auth.access_token, refresh: auth.refresh_token)
            return true
        } catch {
            clearTokens()
            return false
        }
    }
}

// MARK: - Logger de consola

enum APILogger {
    static func log(
        request: URLRequest,
        response: HTTPURLResponse,
        data: Data,
        tag: String = "API"
    ) {
        #if DEBUG
        let method = request.httpMethod ?? "?"
        let url    = request.url?.absoluteString ?? "?"
        let status = response.statusCode
        let emoji  = (200...299).contains(status) ? "✅" : "❌"

        var lines: [String] = [
            "[\(tag)] \(emoji) \(method) \(url) → \(status)"
        ]

        // Request body
        if let body = request.httpBody,
           let bodyStr = String(data: body, encoding: .utf8) {
            lines.append("  ↑ body: \(bodyStr.prefix(500))")
        }

        // Response body
        if data.isEmpty {
            lines.append("  ↓ body: <vacío>")
        } else if let bodyStr = String(data: data, encoding: .utf8) {
            lines.append("  ↓ body: \(bodyStr.prefix(1_000))")
        } else {
            lines.append("  ↓ body: <\(data.count) bytes binarios>")
        }

        // Headers de respuesta relevantes
        let interesting = ["Content-Type", "X-Request-Id"]
        for key in interesting {
            if let val = response.value(forHTTPHeaderField: key) {
                lines.append("  ↓ \(key): \(val)")
            }
        }

        print(lines.joined(separator: "\n"))
        #endif
    }
}
