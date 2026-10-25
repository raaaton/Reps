/// Per-import, memory-only diagnostics. Preserve the original failure when a
/// system transfer provider replaces it with a generic wrapper error.
public actor VaultVideoImportDiagnostics {
  public private(set) var report: String?

  public init() {}

  public func record(_ report: String) {
    guard self.report == nil else { return }
    self.report = report
  }
}
