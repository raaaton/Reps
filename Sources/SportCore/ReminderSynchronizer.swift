import Foundation

public enum ReminderAuthorization: Sendable, Equatable {
  case notDetermined, denied, allowed
  public var mayRequest: Bool { self == .notDetermined }
}
public enum ReminderDestination: Sendable {
  case today, progression, bodyWeight
  public var tabIndex: Int {
    switch self {
    case .today: 0
    case .progression, .bodyWeight: 2
    }
  }
}
public enum ReminderPolicy {
  public static let testIdentifier = "sport.test.notification"
  public static func presents(_ id: String) -> Bool { managed(id) || id == testIdentifier }
  public static func managed(_ id: String) -> Bool { id.hasPrefix("sport.local.") }
  public static func destination(identifier: String, kind: String) -> ReminderDestination? {
    if identifier == "sport.local.photos.monthly", kind == "photos" { return .progression }
    if identifier.hasPrefix("sport.local.bodyweight."), kind == "bodyWeight" { return .bodyWeight }
    if identifier.hasPrefix("sport.local.workout."), kind == "workout" { return .today }
    return nil
  }
}
public struct PendingReminder: Sendable {
  public let id: String
  public let occurrence: ReminderOccurrence?
  public init(id: String, occurrence: ReminderOccurrence?) {
    self.id = id
    self.occurrence = occurrence
  }
}
public protocol ReminderTransport: Sendable {
  func authorization() async -> ReminderAuthorization
  func pending() async -> [PendingReminder]
  func remove(ids: [String]) async
  func add(_ request: ReminderOccurrence) async throws
}
public struct ReminderSyncResult: Sendable {
  public let authorization: ReminderAuthorization
  public let count: Int
  public let error: String?
}
public actor ReminderSynchronizer {
  private let transport: any ReminderTransport
  private let source: @Sendable () async throws -> ReminderContext
  private var running = false
  private var queued = false
  private var waiters: [CheckedContinuation<ReminderSyncResult, Never>] = []
  public init(
    transport: any ReminderTransport, source: @escaping @Sendable () async throws -> ReminderContext
  ) {
    self.transport = transport
    self.source = source
  }
  public func refresh() async -> ReminderSyncResult {
    queued = true
    if running { return await withCheckedContinuation { waiters.append($0) } }
    running = true
    var result = ReminderSyncResult(authorization: .notDetermined, count: 0, error: nil)
    repeat {
      queued = false
      let permission = await transport.authorization()
      do {
        let context = try await source()
        let desired =
          permission == .allowed ? try ReminderPlanner.plan(context: context, now: Date()) : []
        let pending = await transport.pending()
        guard !queued, try await source() == context else {
          queued = true
          continue
        }
        let wanted = Set(desired.map(\.id))
        await transport.remove(
          ids: pending.filter { ReminderPolicy.managed($0.id) && !wanted.contains($0.id) }.map(\.id)
        )
        for request in desired {
          guard !queued, try await source() == context else {
            queued = true
            break
          }
          if !pending.contains(where: { $0.id == request.id && sameRequest($0.occurrence, request) }
          ) {
            try await transport.add(request)
          }
        }
        if try await source() != context { queued = true }
        let actual = await transport.pending()
        result = ReminderSyncResult(
          authorization: permission, count: actual.filter { ReminderPolicy.managed($0.id) }.count,
          error: nil)
      } catch {
        result = ReminderSyncResult(
          authorization: permission, count: 0,
          error:
            "Reminders could not be synced. Try again. \(error.localizedDescription)")
      }
    } while queued
    running = false
    let completed = waiters
    waiters.removeAll()
    for waiter in completed { waiter.resume(returning: result) }
    return result
  }
  private func sameRequest(_ saved: ReminderOccurrence?, _ wanted: ReminderOccurrence) -> Bool {
    guard let saved else { return false }
    return saved.kind == wanted.kind && saved.title == wanted.title && saved.body == wanted.body
      && saved.repeats == wanted.repeats && saved.components == wanted.components
  }
}
