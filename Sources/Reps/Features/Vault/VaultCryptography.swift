import CryptoKit
import Foundation
import ImageIO
import RepsCore
import UniformTypeIdentifiers

enum VaultCryptography {
  static func aad(keyID: String, id: String, role: String) -> Data {
    Data("Sport/vault/v1/\(keyID)/\(id)/\(role)".utf8)
  }
  static func seal(_ data: Data, key: SymmetricKey, keyID: String, id: String, role: String) throws
    -> Data
  {
    guard
      let result = try AES.GCM.seal(
        data, using: key, authenticating: aad(keyID: keyID, id: id, role: role)
      ).combined
    else { throw VaultFailure.damaged }
    return result
  }
  static func open(_ data: Data, key: SymmetricKey, keyID: String, id: String, role: String) throws
    -> Data
  {
    do {
      return try AES.GCM.open(
        AES.GCM.SealedBox(combined: data), using: key,
        authenticating: aad(keyID: keyID, id: id, role: role))
    } catch { throw VaultFailure.damaged }
  }
  static func verify(key: SymmetricKey, keyID: String, encrypted: Data) throws {
    guard
      try open(encrypted, key: key, keyID: keyID, id: "vault", role: "verification")
        == Data("Sport vault v1".utf8)
    else { throw VaultFailure.damaged }
    // Native domain-separation self-check; only constant synthetic bytes, never a photo.
    let check = try seal(Data("test".utf8), key: key, keyID: keyID, id: "test", role: "original")
    do {
      _ = try AES.GCM.open(
        AES.GCM.SealedBox(combined: check), using: key,
        authenticating: aad(keyID: keyID, id: "test", role: "thumbnail"))
      throw VaultFailure.damaged
    } catch CryptoKitError.authenticationFailure {}
  }
  static func imageSource(_ data: Data) throws -> CGImageSource {
    guard !data.isEmpty, data.count <= 24 * 1024 * 1024 else { throw VaultFailure.tooLarge }
    guard
      let source = CGImageSourceCreateWithData(
        data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
      let type = CGImageSourceGetType(source) as String?,
      ["public.jpeg", "public.png", "public.heic", "public.heif"].contains(type),
      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
      let width = props[kCGImagePropertyPixelWidth as String] as? Int,
      let height = props[kCGImagePropertyPixelHeight as String] as? Int,
      width > 0, height > 0, width <= 64_000_000 / height
    else { throw VaultFailure.invalidPhoto }
    return source
  }
  static func preview(_ data: Data, pixels: Int) throws -> Data {
    let source = try imageSource(data)
    guard
      let image = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: pixels,
          kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    else { throw VaultFailure.invalidPhoto }
    let result = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        result, UTType.jpeg.identifier as CFString, 1, nil)
    else { throw VaultFailure.invalidPhoto }
    CGImageDestinationAddImage(
      destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw VaultFailure.invalidPhoto }
    return result as Data
  }
  static func prepare(
    _ data: Data, day: String, pose: VaultPhotoPose, key: SymmetricKey, keyID: String
  ) throws
    -> VaultEncryptedPhoto
  {
    let source = try imageSource(data)
    guard let type = CGImageSourceGetType(source) as String? else {
      throw VaultFailure.invalidPhoto
    }
    let id = UUID().uuidString
    let meta = try JSONEncoder().encode(VaultPhotoMetadata(dayKey: day, type: type, pose: pose))
    let thumbnail = try preview(data, pixels: 500)
    return try VaultEncryptedPhoto(
      id: id,
      metadata: seal(meta, key: key, keyID: keyID, id: id, role: "metadata"),
      original: seal(data, key: key, keyID: keyID, id: id, role: "original"),
      thumbnail: seal(thumbnail, key: key, keyID: keyID, id: id, role: "thumbnail"))
  }
}
