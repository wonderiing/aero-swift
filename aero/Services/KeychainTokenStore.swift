import Foundation
import Security

enum KeychainTokenStore {
    private static let service = "Leon.aero.auth"
    private static let accessAccount = "access_token"
    private static let refreshAccount = "refresh_token"

    static func save(access: String, refresh: String) {
        save(account: accessAccount, value: access)
        save(account: refreshAccount, value: refresh)
    }

    static func accessToken() -> String? {
        read(account: accessAccount)
    }

    static func refreshToken() -> String? {
        read(account: refreshAccount)
    }

    static func clear() {
        delete(account: accessAccount)
        delete(account: refreshAccount)
    }

    static var hasAccessToken: Bool { accessToken() != nil }

    private static func save(account: String, value: String) {
        delete(account: account)
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
