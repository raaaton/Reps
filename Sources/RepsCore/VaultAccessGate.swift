import Foundation

public struct VaultAccessGate: Sendable {
  public enum Phase: Equatable, Sendable { case locked, authenticating, unlocked }
  public private(set) var phase: Phase = .locked
  public private(set) var covered = false
  private var token: UUID?
  public init() {}

  public mutating func begin() -> UUID? {
    guard phase == .locked else { return nil }
    let token = UUID()
    self.token = token
    phase = .authenticating
    return token
  }

  public func accepts(_ token: UUID) -> Bool {
    phase == .authenticating && self.token == token
  }
  public mutating func complete(_ token: UUID) -> Bool {
    guard accepts(token) else { return false }
    phase = .unlocked
    self.token = nil
    return true
  }
  public mutating func fail(_ token: UUID) {
    if accepts(token) { lock() }
  }
  public mutating func lock() {
    token = nil
    phase = .locked
  }
  public mutating func cover() { covered = true }
  public mutating func foreground() { covered = false }
}
