import Foundation

/// Base URL del backend. En simulador iOS/iPad y en Mac (Catalyst) suele ser la máquina local.
/// Variable de entorno opcional: `AERO_API_BASE` (ej. `http://127.0.0.1:3000`).
enum AppConfig {
    static var apiBaseURLString: String {
        if let env = ProcessInfo.processInfo.environment["AERO_API_BASE"], !env.isEmpty {
            return env
        }
        return "http://localhost:3000"
    }
}
