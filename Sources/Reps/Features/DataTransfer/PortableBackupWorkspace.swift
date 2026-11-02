import Foundation

final class PortableBackupWorkspace: Sendable {
  let folder: URL
  init() throws {
    folder = try Self.root().appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: folder, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.complete])
  }
  func url(_ name: String) -> URL { folder.appendingPathComponent(name) }
  deinit { try? FileManager.default.removeItem(at: folder) }
  private static func root() throws -> URL {
    var root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "RepsEncryptedBackups-v1", isDirectory: true)
    try FileManager.default.createDirectory(
      at: root, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.complete])
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try root.setResourceValues(values)
    return root
  }
  static func removeAbandoned() throws {
    for folder in try FileManager.default.contentsOfDirectory(
      at: root(), includingPropertiesForKeys: nil)
    {
      if UUID(uuidString: folder.lastPathComponent) != nil {
        try FileManager.default.removeItem(at: folder)
      }
    }
  }
}
