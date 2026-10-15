import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct BackupProbeFileDocument: FileDocument {
  static let contentType = UTType(exportedAs: "com.raaaton.sport.backup-probe", conformingTo: .data)
  static var readableContentTypes: [UTType] { [contentType] }
  let data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    // Export only; imports use a bounded FileHandle in the probe engine.
    throw CocoaError(.fileReadUnsupportedScheme)
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
