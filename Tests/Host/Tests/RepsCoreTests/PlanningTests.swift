import CSQLite
import Foundation
import XCTest

@testable import RepsCore

final class PlanningTests: XCTestCase, @unchecked Sendable {
  private func temporaryPath() -> String {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
  }

  func testSeedAndReopenDoNotDuplicateOrOverwriteChanges() async throws {
    let path = temporaryPath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let initial = try await repository.snapshot()
    XCTAssertEqual(initial.exercises.count, 5)
    XCTAssertEqual(initial.schedules.count, 3)
    XCTAssertEqual(initial.restSeconds, 180)
    XCTAssertNil(initial.exercises.last?.durationSeconds)
    XCTAssertEqual(initial.schedules.map(\.weekday), [2, 6, 7])
    XCTAssertTrue(initial.schedules.allSatisfy { $0.reminderMinutes == nil })
    var legs = try XCTUnwrap(initial.schedules.first)
    legs.name = "Jambes maison"
    legs.weekday = 3
    legs.reminderMinutes = 7 * 60 + 23
    try await repository.saveSchedule(legs)
    let reopened = try RepsRepository(path: path)
    let snapshot = try await reopened.snapshot()
    XCTAssertEqual(snapshot.schedules.count, 3)
    XCTAssertEqual(snapshot.schedules.first?.name, "Jambes maison")
    XCTAssertEqual(snapshot.schedules.first?.weekday, 3)
    XCTAssertEqual(snapshot.schedules.first?.reminderMinutes, 443)
    XCTAssertEqual(snapshot.exercises.count, 5)
  }

  func testScheduleOrderAndDisabledEmptySchedulePersist() async throws {
    let path = temporaryPath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let initial = try await repository.snapshot()
    var push = initial.schedules[1]
    push.exerciseIDs.reverse()
    try await repository.saveSchedule(push)
    let reordered = try await repository.snapshot()
    XCTAssertEqual(reordered.schedules[1].exerciseIDs, push.exerciseIDs)
    push.isEnabled = false
    push.exerciseIDs = []
    try await repository.saveSchedule(push)
    let reopened = try RepsRepository(path: path)
    let snapshot = try await reopened.snapshot()
    XCTAssertFalse(snapshot.schedules[1].isEnabled)
    XCTAssertEqual(snapshot.schedules[1].exerciseIDs, [])
  }

  func testInvalidScheduleWritesLeaveAllRowsUnchanged() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let initial = try await repository.snapshot()
    var proposed = initial.schedules[0]
    let cases: [(String, (inout TrainingSchedule) -> Void)] = [
      ("occupied", { $0.weekday = 6 }),
      ("empty", { $0.exerciseIDs = [] }),
      ("unknown", { $0.exerciseIDs = ["unknown"] }),
      ("duplicate", { $0.exerciseIDs += $0.exerciseIDs }),
      ("invalid time", { $0.reminderMinutes = 1440 }),
      ("invalid weekday", { $0.weekday = 0 }),
      ("blank name", { $0.name = " \n " }),
    ]
    for (name, edit) in cases {
      proposed = initial.schedules[0]
      edit(&proposed)
      do {
        try await repository.saveSchedule(proposed)
        XCTFail("Accepted \(name)")
      } catch {
        let current = try await repository.snapshot()
        XCTAssertEqual(current, initial, name)
      }
    }
  }

  func testExerciseEditingCreationAndTargetValidation() async throws {
    let path = temporaryPath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let initial = try await repository.snapshot()
    var exercise = initial.exercises[0]
    exercise.name = "Bulgarians test"
    exercise.setCount = 5
    exercise.minimumReps = 10
    exercise.maximumReps = 15
    try await repository.saveExercise(exercise)
    var timed = TrainingExercise(
      id: UUID().uuidString, name: "Gainage", tracking: .duration, setCount: 3,
      minimumReps: nil, maximumReps: nil, durationSeconds: 45, isEnabled: true
    )
    try await repository.saveExercise(timed)
    timed.durationSeconds = 0
    do {
      try await repository.saveExercise(timed)
      XCTFail("Accepted zero duration")
    } catch {}
    exercise.minimumReps = 20
    do {
      try await repository.saveExercise(exercise)
      XCTFail("Accepted reversed repetition range")
    } catch {}
    exercise.minimumReps = 10
    exercise.setCount = 0
    do {
      try await repository.saveExercise(exercise)
      XCTFail("Accepted zero sets")
    } catch {}
    let reopened = try RepsRepository(path: path)
    let snapshot = try await reopened.snapshot()
    XCTAssertEqual(snapshot.exercises.count, 6)
    XCTAssertEqual(snapshot.exercises.first?.minimumReps, 10)
    XCTAssertEqual(snapshot.exercises.first?.setCount, 5)
    XCTAssertEqual(snapshot.exercises.last?.durationSeconds, 45)
  }

  func testCannotDisableLastExerciseOfActiveSchedule() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let initial = try await repository.snapshot()
    var exercise = initial.exercises[0]
    exercise.isEnabled = false
    do {
      try await repository.saveExercise(exercise)
      XCTFail("Disabled the only exercise of active Legs")
    } catch {}
    let unchanged = try await repository.snapshot()
    XCTAssertEqual(unchanged, initial)
    var schedule = initial.schedules[0]
    schedule.isEnabled = false
    try await repository.saveSchedule(schedule)
    try await repository.saveExercise(exercise)
    let current = try await repository.snapshot()
    XCTAssertFalse(current.exercises[0].isEnabled)
    schedule.isEnabled = true
    do {
      try await repository.saveSchedule(schedule)
      XCTFail("Activated a schedule containing only disabled exercise")
    } catch {}
  }

  func testRestPersistsAndInvalidValuesAreRejected() async throws {
    let path = temporaryPath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    try await repository.saveRest(seconds: 137)
    do {
      try await repository.saveRest(seconds: 0)
      XCTFail("Accepted no rest")
    } catch {}
    let reopened = try RepsRepository(path: path)
    let snapshot = try await reopened.snapshot()
    XCTAssertEqual(snapshot.restSeconds, 137)
  }

  func testUnknownNewerSchemaFailsWithoutReset() throws {
    let path = temporaryPath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    var handle: OpaquePointer?
    XCTAssertEqual(sqlite3_open(path, &handle), SQLITE_OK)
    XCTAssertEqual(sqlite3_exec(handle, "PRAGMA user_version=99", nil, nil, nil), SQLITE_OK)
    sqlite3_close(handle)
    XCTAssertThrowsError(try RepsRepository(path: path))
    XCTAssertEqual(sqlite3_open(path, &handle), SQLITE_OK)
    defer { sqlite3_close(handle) }
    var statement: OpaquePointer?
    XCTAssertEqual(
      sqlite3_prepare_v2(handle, "PRAGMA user_version", -1, &statement, nil), SQLITE_OK)
    defer { sqlite3_finalize(statement) }
    XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
    XCTAssertEqual(sqlite3_column_int(statement, 0), 99)
  }

  func testFailureDuringScheduleReplacementRollsBackAllWrites() async throws {
    let path = temporaryPath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let initial = try await repository.snapshot()
    let injection = try SQLiteDatabase(path: path)
    try injection.execute(
      """
      CREATE TRIGGER reject_second BEFORE INSERT ON schedule_exercises
      WHEN NEW.schedule_id='push' AND NEW.position=1
      BEGIN SELECT RAISE(ABORT,'injected failure'); END
      """)
    var push = initial.schedules[1]
    push.name = "Must roll back"
    push.exerciseIDs.reverse()
    do {
      try await repository.saveSchedule(push)
      XCTFail("Accepted an injected database failure")
    } catch {
      let afterFailure = try await repository.snapshot()
      XCTAssertEqual(afterFailure, initial)
    }
    try injection.execute("DROP TRIGGER reject_second")
    try await repository.saveSchedule(push)
    let afterRecovery = try await repository.snapshot()
    XCTAssertEqual(afterRecovery.schedules[1], push)
  }

  func testConcurrentEditsCannotOccupyTheSameDay() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let initial = try await repository.snapshot()
    var legs = initial.schedules[0]
    var push = initial.schedules[1]
    legs.weekday = 3
    push.weekday = 3
    let firstSchedule = legs
    let secondSchedule = push
    let first = Task {
      do {
        try await repository.saveSchedule(firstSchedule)
        return true
      } catch { return false }
    }
    let second = Task {
      do {
        try await repository.saveSchedule(secondSchedule)
        return true
      } catch { return false }
    }
    let results = await [first.value, second.value]
    XCTAssertEqual(results.filter { $0 }.count, 1)
    let current = try await repository.snapshot()
    XCTAssertEqual(current.schedules.filter { $0.weekday == 3 }.count, 1)
    XCTAssertEqual(current.schedules.count, 3)
  }

  func testISOWeekdayUsesLocalCalendar() async throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 2 * 3600)!
    let sunday = Date(timeIntervalSince1970: 1_791_763_140)  // 2026-10-11 23:59 UTC
    var utc = calendar
    utc.timeZone = TimeZone(secondsFromGMT: 0)!
    XCTAssertEqual(TrainingSnapshot.isoWeekday(on: sunday, calendar: utc), 7)
    XCTAssertEqual(TrainingSnapshot.isoWeekday(on: sunday, calendar: calendar), 1)
    let midnight = Date(timeIntervalSince1970: 1_791_676_800)  // 2026-10-11 00:00 UTC
    XCTAssertEqual(TrainingSnapshot.isoWeekday(on: midnight, calendar: calendar), 7)
    let monday = midnight.addingTimeInterval(24 * 3600)
    XCTAssertEqual(TrainingSnapshot.isoWeekday(on: monday, calendar: calendar), 1)
    let repository = try RepsRepository(path: ":memory:")
    let initial = try await repository.snapshot()
    XCTAssertEqual(initial.schedule(on: sunday, calendar: utc)?.id, "pull-abs")
    XCTAssertNil(initial.schedule(on: sunday, calendar: calendar))
    var pull = initial.schedules[2]
    pull.isEnabled = false
    try await repository.saveSchedule(pull)
    let disabled = try await repository.snapshot()
    XCTAssertNil(disabled.schedule(on: sunday, calendar: utc))
  }
}
