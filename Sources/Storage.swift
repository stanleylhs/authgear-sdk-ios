import Foundation
import Security

public protocol TokenStorage {
    func setRefreshToken(namespace: String, token: String) throws
    func getRefreshToken(namespace: String) throws -> String?
    func delRefreshToken(namespace: String) throws
}

protocol ContainerStorage {
    func setAnonymousKeyId(namespace: String, kid: String) throws
    func getAnonymousKeyId(namespace: String) throws -> String?
    func delAnonymousKeyId(namespace: String) throws

    func setBiometricKeyId(namespace: String, kid: String) throws
    func getBiometricKeyId(namespace: String) throws -> String?
    func delBiometricKeyId(namespace: String) throws
}

public class TransientTokenStorage: TokenStorage {
    private let driver = MemoryStorageDriver()
    private let keyMaker = KeyMaker()

    public init() {}

    public func setRefreshToken(namespace: String, token: String) throws {
        try self.driver.set(key: self.keyMaker.keyRefreshToken(namespace: namespace), value: token)
    }

    public func getRefreshToken(namespace: String) throws -> String? {
        try self.driver.get(key: self.keyMaker.keyRefreshToken(namespace: namespace))
    }

    public func delRefreshToken(namespace: String) throws {
        try self.driver.del(key: self.keyMaker.keyRefreshToken(namespace: namespace))
    }
}

public class PersistentTokenStorage: TokenStorage {
    private let driver = KeychainStorageDriver()
    private let keyMaker = KeyMaker()

    public init() {}

    public func setRefreshToken(namespace: String, token: String) throws {
        try self.driver.set(key: self.keyMaker.keyRefreshToken(namespace: namespace), value: token)
    }

    public func getRefreshToken(namespace: String) throws -> String? {
        try self.driver.get(key: self.keyMaker.keyRefreshToken(namespace: namespace))
    }

    public func delRefreshToken(namespace: String) throws {
        try self.driver.del(key: self.keyMaker.keyRefreshToken(namespace: namespace))
    }
}

class PersistentContainerStorage: ContainerStorage {
    private let driver = KeychainStorageDriver()
    private let keyMaker = KeyMaker()

    func setAnonymousKeyId(namespace: String, kid: String) throws {
        try self.driver.set(key: self.keyMaker.keyAnonymousKeyId(namespace: namespace), value: kid)
    }

    func setBiometricKeyId(namespace: String, kid: String) throws {
        try self.driver.set(key: self.keyMaker.keyBiometricKeyId(namespace: namespace), value: kid)
    }

    func getAnonymousKeyId(namespace: String) throws -> String? {
        try self.driver.get(key: self.keyMaker.keyAnonymousKeyId(namespace: namespace))
    }

    func getBiometricKeyId(namespace: String) throws -> String? {
        try self.driver.get(key: self.keyMaker.keyBiometricKeyId(namespace: namespace))
    }

    func delAnonymousKeyId(namespace: String) throws {
        try self.driver.del(key: self.keyMaker.keyAnonymousKeyId(namespace: namespace))
    }

    func delBiometricKeyId(namespace: String) throws {
        try self.driver.del(key: self.keyMaker.keyBiometricKeyId(namespace: namespace))
    }
}

class KeyMaker {
    func scopedKey(_ key: String) -> String {
        "authgear_\(key)"
    }

    func keyRefreshToken(namespace: String) -> String {
        scopedKey("\(namespace)_refreshToken")
    }

    func keyAnonymousKeyId(namespace: String) -> String {
        scopedKey("\(namespace)_anonymousKeyID")
    }

    func keyBiometricKeyId(namespace: String) -> String {
        scopedKey("\(namespace)_biometricKeyID")
    }
}

class MemoryStorageDriver {
    private var backingStorage = [String: String]()

    func get(key: String) throws -> String? {
        backingStorage[key]
    }

    func set(key: String, value: String) throws {
        backingStorage[key] = value
    }

    func del(key: String) throws {
        backingStorage.removeValue(forKey: key)
    }
}

class KeychainStorageDriver {
    func get(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: kCFBooleanTrue as Any
        ]

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        switch status {
        case errSecSuccess:
            let value = String(data: result as! Data, encoding: .utf8)!
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw AuthgearError.osStatus(status)
        }
    }

    func set(key: String, value: String) throws {
        let status: OSStatus
        if try get(key: key) != nil {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]

            let update: [String: Any] = [kSecValueData as String: value.data(using: .utf8)!]
            status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        } else {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: value.data(using: .utf8)!
            ]

            status = SecItemAdd(query as CFDictionary, nil)
        }

        if status == errSecSuccess {
            return
        } else {
            throw AuthgearError.osStatus(status)
        }
    }

    func del(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw AuthgearError.osStatus(status)
        }
    }
}
