import AVFoundation
import Foundation
import SportCore

@MainActor
final class VaultVideoResourceLoader: NSObject, @preconcurrency AVAssetResourceLoaderDelegate {
  private let reader: VaultVideoReader
  private let total: Int
  private let type: String
  private var requests: [ObjectIdentifier: Task<Void, Never>] = [:]
  private var valid = true
  init(reader: VaultVideoReader, total: Int, type: String) {
    self.reader = reader
    self.total = total
    self.type = type
  }
  func resourceLoader(
    _ resourceLoader: AVAssetResourceLoader,
    shouldWaitForLoadingOfRequestedResource request: AVAssetResourceLoadingRequest
  ) -> Bool {
    guard valid else {
      request.finishLoading(with: VaultFailure.locked)
      return true
    }
    if let information = request.contentInformationRequest {
      information.contentType = type
      information.contentLength = Int64(total)
      information.isByteRangeAccessSupported = true
    }
    guard let data = request.dataRequest else {
      request.finishLoading()
      return true
    }
    let identity = ObjectIdentifier(request)
    guard requests.count < 4 else {
      request.finishLoading(with: VaultFailure.damaged)
      return true
    }
    requests[identity] = Task { [weak self] in
      guard let self else { return }
      defer { requests[identity] = nil }
      do {
        let range = try VaultVideoRange.requested(
          offset: data.requestedOffset,
          length: data.requestedLength, total: total, toEnd: data.requestsAllDataToEndOfResource)
        var position = max(range.lower, Int(clamping: data.currentOffset))
        while position < range.upper {
          try Task.checkCancellation()
          guard valid, !request.isCancelled else { throw VaultFailure.locked }
          let index = position / VaultVideoLimits.chunkBytes
          let bytes = try await reader.read(index: index)
          try Task.checkCancellation()
          guard valid, !request.isCancelled else { throw VaultFailure.locked }
          let offset = position % VaultVideoLimits.chunkBytes
          let count = min(bytes.count - offset, range.upper - position)
          guard count > 0 else { throw VaultFailure.damaged }
          data.respond(with: bytes.subdata(in: offset..<(offset + count)))
          position += count
        }
        if valid, !request.isCancelled { request.finishLoading() }
      } catch {
        if !request.isCancelled { request.finishLoading(with: VaultFailure.damaged) }
      }
    }
    return true
  }
  func resourceLoader(
    _ resourceLoader: AVAssetResourceLoader,
    didCancel request: AVAssetResourceLoadingRequest
  ) {
    requests.removeValue(forKey: ObjectIdentifier(request))?.cancel()
  }
  func invalidate() {
    valid = false
    for task in requests.values { task.cancel() }
    requests.removeAll()
    Task { await reader.close() }
  }
}
