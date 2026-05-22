import Foundation
import Security

final class StarlinkCookieStore {
    private let service = "com.saitawngpha.StarlinkControl.starlink-cookie"
    private let account = "remote-api-cookie"

    func load() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw StarlinkCookieStoreError.unableToLoad
        }

        return value
    }

    func save(_ cookie: String) throws {
        let data = Data(cookie.utf8)
        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw StarlinkCookieStoreError.unableToSave
            }
            return
        }

        guard status == errSecSuccess else {
            throw StarlinkCookieStoreError.unableToSave
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            throw StarlinkCookieStoreError.unableToDelete
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum StarlinkCookieStoreError: LocalizedError {
    case unableToLoad
    case unableToSave
    case unableToDelete

    var errorDescription: String? {
        switch self {
        case .unableToLoad:
            "Could not load Starlink cookie from Keychain."
        case .unableToSave:
            "Could not save Starlink cookie to Keychain."
        case .unableToDelete:
            "Could not remove Starlink cookie from Keychain."
        }
    }
}
