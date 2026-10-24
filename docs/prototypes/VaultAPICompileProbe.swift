import CryptoKit
import Foundation
import LocalAuthentication
import PhotosUI
import Security
import SwiftUI
import UniformTypeIdentifiers

// Compile-only feasibility probe. Never invoked; no key or photo is created/read.
@MainActor
enum VaultAPICompileProbe {
  static func authenticate(_ context: LAContext) async throws {
    _ = try await context.evaluatePolicy(
      .deviceOwnerAuthenticationWithBiometrics,
      localizedReason: "Déverrouiller les photos privées de Reps.")
  }

  static func accessControl() throws -> SecAccessControl {
    var error: Unmanaged<CFError>?
    guard let value = SecAccessControlCreateWithFlags(
      nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &error)
    else { throw CocoaError(.fileReadUnknown) }
    return value
  }

  static func keyQuery(_ context: LAContext) -> OSStatus {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.raaaton.sport.vault-probe",
      kSecAttrAccount as String: "compile-only",
      kSecReturnData as String: true,
      kSecUseAuthenticationContext as String: context,
    ]
    var result: CFTypeRef?
    return SecItemCopyMatching(query as CFDictionary, &result)
  }

  static func roundTrip(_ data: Data) throws -> Bool {
    let key = SymmetricKey(size: .bits256)
    let sealed = try AES.GCM.seal(data, using: key, authenticating: Data("vault-probe".utf8))
    return try AES.GCM.open(sealed, using: key, authenticating: Data("vault-probe".utf8)) == data
  }

  static func loadSelection(_ item: PhotosPickerItem) async throws -> Data? {
    try await item.loadTransferable(type: Data.self)
  }
}
