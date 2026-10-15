import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct BackupProbeTransfer: Identifiable {
  enum Kind {
    case importFile
    case exportFile(Data)
  }
  let id: UUID
  let kind: Kind
}

// Each native presentation has its own immutable request and ciphertext snapshot.
// Removing this host cannot turn its eventual callback into a new presentation's result.
struct BackupProbeTransferView: View {
  let request: BackupProbeTransfer
  let completed: (Result<URL, Error>) -> Void
  @State private var importing = false
  @State private var exporting = false
  var body: some View {
    Color.clear.frame(width: 0, height: 0)
      .onAppear {
        switch request.kind {
        case .importFile: importing = true
        case .exportFile: exporting = true
        }
      }
      .fileImporter(
        isPresented: $importing, allowedContentTypes: [BackupProbeFileDocument.contentType, .data]
      ) { completed($0) }
      .fileExporter(
        isPresented: $exporting, document: BackupProbeFileDocument(data: ciphertext),
        contentType: BackupProbeFileDocument.contentType, defaultFilename: "Sport-encryption-test"
      ) { completed($0) }
  }
  private var ciphertext: Data {
    if case .exportFile(let data) = request.kind { return data }
    return Data()
  }
}
