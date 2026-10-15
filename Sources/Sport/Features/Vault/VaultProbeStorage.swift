import CryptoKit
import Foundation
import LocalAuthentication
import Security

// Preparatory device validation only. This namespace cannot access future photo-vault keys.
@MainActor
enum VaultProbeStorage {
  struct Result { let reusedKey: Bool }
  enum Failure: LocalizedError {
    case keychain(OSStatus)
    case incomplete, ciphertext, validation
    var errorDescription: String? {
      switch self {
      case .keychain(let code): "Keychain access to test data denied (code \(code))."
      case .incomplete:
        "Test data and their key no longer match. No key has been replaced. You can delete only these test data from the menu."
      case .ciphertext:
        "Encrypted test data are unreadable. No key has been replaced."
      case .validation: "Encryption verification failed."
      }
    }
  }
  private static let service = "com.raaaton.sport.vault-probe.v1"
  private static let account = "synthetic-data-only"
  private static let sample = Data("Sport: synthetic vault validation v1".utf8)
  private static let associatedData = Data("Sport/vault-probe/v1/sample".utf8)
  private static var identity: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: account, kSecAttrSynchronizable as String: false,
    ]
  }
  private static func file() throws -> URL {
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    return support.appendingPathComponent("VaultProbe-v1", isDirectory: true)
      .appendingPathComponent("synthetic.sealed")
  }

  static func validate(context: LAContext) throws -> Result {
    let url = try file()
    let exists = FileManager.default.fileExists(atPath: url.path)
    var query = identity
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecUseAuthenticationContext as String] = context
    let previousInteractionPolicy = context.interactionNotAllowed
    context.interactionNotAllowed = true
    defer { context.interactionNotAllowed = previousInteractionPolicy }
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    let key: SymmetricKey
    let reused: Bool
    if status == errSecSuccess {
      guard exists, let bytes = result as? Data, bytes.count == 32 else { throw Failure.incomplete }
      key = SymmetricKey(data: bytes)
      reused = true
    } else if status == errSecItemNotFound && !exists {
      key = SymmetricKey(size: .bits256)
      reused = false
      var error: Unmanaged<CFError>?
      guard
        let access = SecAccessControlCreateWithFlags(
          nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &error)
      else {
        _ = error?.takeRetainedValue()
        throw Failure.validation
      }
      var insert = identity
      insert[kSecAttrAccessControl as String] = access
      insert[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
      let inserted = SecItemAdd(insert as CFDictionary, nil)
      guard inserted == errSecSuccess else { throw Failure.keychain(inserted) }
      do {
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
          at: folder, withIntermediateDirectories: true,
          attributes: [.protectionKey: FileProtectionType.complete])
        let sealed = try AES.GCM.seal(sample, using: key, authenticating: associatedData)
        guard let combined = sealed.combined else { throw Failure.validation }
        try combined.write(to: url, options: [.atomic, .completeFileProtection])
      } catch {
        // Roll back only the newly created probe key, never an existing item or real vault key.
        SecItemDelete(identity as CFDictionary)
        throw error
      }
    } else if status == errSecItemNotFound {
      throw Failure.incomplete
    } else {
      throw Failure.keychain(status)
    }
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    guard let size = attributes[.size] as? NSNumber, (1...1024).contains(size.intValue) else {
      throw Failure.ciphertext
    }
    let encrypted = try Data(contentsOf: url)
    guard encrypted.count <= 1024 else { throw Failure.ciphertext }
    do {
      let box = try AES.GCM.SealedBox(combined: encrypted)
      guard try AES.GCM.open(box, using: key, authenticating: associatedData) == sample else {
        throw Failure.validation
      }
    } catch { throw Failure.ciphertext }
    var changed = encrypted
    guard !changed.isEmpty else { throw Failure.ciphertext }
    changed[changed.count - 1] ^= 1
    do {
      let box = try AES.GCM.SealedBox(combined: changed)
      _ = try AES.GCM.open(box, using: key, authenticating: associatedData)
      throw Failure.validation
    } catch CryptoKitError.authenticationFailure {
      // Actual CryptoKit verification on the device, not a mocked encryption result.
    }
    return Result(reusedKey: reused)
  }

  static func resetSyntheticData() throws {
    let status = SecItemDelete(identity as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw Failure.keychain(status)
    }
    let url = try file()
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
  }
}
