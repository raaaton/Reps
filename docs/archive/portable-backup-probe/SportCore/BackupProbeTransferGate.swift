import Foundation

public struct BackupProbeTransferGate: Sendable {
  private var visible = false
  private var active = false
  private var token: UUID?
  public init() {}
  public mutating func open(active: Bool) {
    visible = true
    self.active = active
    token = nil
  }
  public mutating func close() {
    visible = false
    token = nil
  }
  public mutating func setActive(_ value: Bool) {
    active = value
    if !value { token = nil }
  }
  public mutating func begin() -> UUID? {
    guard visible, active else { return nil }
    let value = UUID()
    token = value
    return value
  }
  public func accepts(_ value: UUID) -> Bool { visible && active && token == value }
  public mutating func finish(_ value: UUID) -> Bool {
    guard accepts(value) else { return false }
    token = nil
    return true
  }
}
