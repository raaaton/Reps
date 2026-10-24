import CoreTransferable
import Foundation
import RepsCore
import UniformTypeIdentifiers

struct VaultTransferredImage: Transferable, Sendable {
  let data: Data
  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .image, shouldAttemptToOpenInPlace: false) { file in
      // Apple's copy is scoped to this closure. Never copy to app storage or alter an original.
      let values = try file.file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
      guard values.isRegularFile == true, let size = values.fileSize,
        (1...(24 * 1024 * 1024)).contains(size)
      else { throw VaultFailure.tooLarge }
      let data = try Data(contentsOf: file.file)
      guard data.count <= 24 * 1024 * 1024 else { throw VaultFailure.tooLarge }
      return VaultTransferredImage(data: data)
    }
  }
}
