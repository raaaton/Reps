import CryptoKit
import Foundation
import LocalAuthentication
import Security
import SportCore

@MainActor
enum VaultKeychain {
  private static let service = "com.raaaton.sport.photo-vault.v1"
  private static var identity: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrSynchronizable as String: false,
    ]
  }
  static func load(id: String, context: LAContext) throws -> SymmetricKey {
    var query = identity
    query[kSecAttrAccount as String] = id
    query[kSecReturnData as String] = true
    query[kSecUseAuthenticationContext as String] = context
    context.interactionNotAllowed = true
    defer { context.interactionNotAllowed = false }
    var value: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &value)
    guard status == errSecSuccess, let data = value as? Data, data.count == 32 else {
      throw VaultFailure.damaged
    }
    return SymmetricKey(data: data)
  }
  static func create(id: String, context: LAContext) throws -> SymmetricKey {
    // A missing database must never silently replace a surviving vault key.
    var existing = identity
    existing[kSecReturnAttributes as String] = true
    existing[kSecMatchLimit as String] = kSecMatchLimitAll
    existing[kSecUseAuthenticationContext as String] = context
    context.interactionNotAllowed = true
    defer { context.interactionNotAllowed = false }
    var result: CFTypeRef?
    guard SecItemCopyMatching(existing as CFDictionary, &result) == errSecItemNotFound else {
      throw VaultFailure.damaged
    }
    var error: Unmanaged<CFError>?
    guard
      let acl = SecAccessControlCreateWithFlags(
        nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &error)
    else {
      _ = error?.takeRetainedValue()
      throw VaultFailure.damaged
    }
    let key = SymmetricKey(size: .bits256)
    var item = identity
    item[kSecAttrAccount as String] = id
    item[kSecAttrAccessControl as String] = acl
    item[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
    guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw VaultFailure.damaged }
    return key
  }
  static func discardNewKey(id: String) {
    var query = identity
    query[kSecAttrAccount as String] = id
    SecItemDelete(query as CFDictionary)
  }
  // Only after explicit destructive confirmation. Does not touch the probe or any other key.
  static func reset() throws {
    let status = SecItemDelete(identity as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw VaultFailure.damaged
    }
  }
}
