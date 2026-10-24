import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct TrainingFileDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
  var data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    guard let value = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    data = value
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
