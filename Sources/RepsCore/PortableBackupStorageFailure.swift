import Foundation

// Fixed operation labels and numeric SQLite status only. Never include SQL, bound values,
// filesystem paths, media identifiers, native error descriptions or key material.
public struct PortableBackupStorageFailure: Error, LocalizedError, Sendable {
  public let stage: String
  public let code: Int32?
  public let extendedCode: Int32?
  public init(stage: String, code: Int32? = nil, extendedCode: Int32? = nil) {
    self.stage = stage
    self.code = code
    self.extendedCode = extendedCode
  }
  public var errorDescription: String? {
    let detail = code.map { " SQLite \($0)/\(extendedCode ?? $0)." } ?? ""
    let action =
      code == 13
      ? " Free some iPhone storage and try again."
      : " Try again without deleting Reps."
    return "Unable to prepare the backup (\(stage))." + detail + action
  }
}
